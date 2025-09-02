public without sharing class PrequalSolutionsClientAPI {
    /**
     * Usage:
     *   PrequalSolutionsClientAPI.createReport(accountIds); 
     */
    
    private static String resolveScenario() {
        Prequal_Settings__c cs = Prequal_Settings__c.getOrgDefaults();
        return (cs != null) ? cs.Scenario__c : null;
    }

    public class APIIntegrationJob implements Queueable, Database.AllowsCallouts {
        private List<Id> accountIds;

        public APIIntegrationJob(List<Id> accountIds) {
            this.accountIds = accountIds;
        }

        public void execute(QueueableContext context) {
            
            String scenario = resolveScenario();
            System.debug(LoggingLevel.INFO, 'Prequal scenario in use: ' + scenario);
            
            List<Account> accounts = [
                SELECT Id, FirstName, MiddleName, LastName, PersonMailingStreet, PersonMailingCity, State_A__c,
                       PersonMailingPostalCode, Birthdate__c, Phone, PersonEmail, Quoted_Retainer__c,
                       Responsible_Attorney__c, Responsible_Attorney_Email_A__c, Credit_Check_Submitted__c,
                       Annual_household_income__c, Social_Security_Number__c
                FROM Account WHERE Id IN :accountIds
            ];

            List<Account> accountsToUpdate = new List<Account>();
            for (Account acc : accounts) {
                try {
                    // Build JSON Payload
                    Map<String, Object> applicant = new Map<String, Object>{
                        'firstname' => acc.FirstName,
                        'middlename' => acc.MiddleName,
                        'lastname' => acc.LastName,
                        'address_1' => acc.PersonMailingStreet,
                        'address_2' => '',
                        'city' => acc.PersonMailingCity,
                        'state' => acc.State_A__c,
                        'zip' => acc.PersonMailingPostalCode,
                        'dob' => acc.Birthdate__c != null ? acc.Birthdate__c.format() : '',
                        'ssn' => acc.Social_Security_Number__c,
                        'phone' => acc.Phone,
                        'email' => acc.PersonEmail,
                        'income' => acc.Annual_household_income__c != null ? String.valueOf(acc.Annual_household_income__c) : null
                    };

                    Map<String, Object> requestPayload = new Map<String, Object>{
                        'applicant' => applicant,
                        'scenario' => scenario
                    };

                    HttpRequest req = new HttpRequest();
                    req.setEndpoint('callout:prequalSolutionsNC/test-api/applicant');
                    req.setMethod('POST');
                    req.setHeader('Content-Type', 'application/json');
                    req.setBody(JSON.serialize(requestPayload));

                    Http http = new Http();
                    HttpResponse res = http.send(req);

                    // --- Response Handling ---
                    if (res.getStatusCode() == 200) {
                        ApiResponseWrapper resp =
                            (ApiResponseWrapper) JSON.deserialize(res.getBody(), ApiResponseWrapper.class);

                        if (
                            resp != null && resp.api != null && resp.api.response != null &&
                            resp.api.response.data != null && resp.api.response.data.reports != null &&
                            resp.api.response.data.reports.individual != null && !resp.api.response.data.reports.individual.isEmpty()
                        ) {
                            IndividualReport report = resp.api.response.data.reports.individual[0];
                            Account accUpdate = new Account(Id = acc.Id);

                            // 1.temporary_shareable_link as the report link
                            accUpdate.Credit_Report_Link__c = report.temporary_shareable_link;

                            // 2. Decisioning 
                            List<Decisioning> passingOffers = new List<Decisioning>();
                            for (Decisioning d : report.decisioning) {
                                if (d != null && d.result != null && d.result.toLowerCase() == 'pass') {
                                    passingOffers.add(d);
                                }
                            }

                            List<String> offerPriority = new List<String>{
                                'Gold - 0% Retainer', 'Silver - 50% Retainer', 'Bronze - 80% Retainer'
                            };
                            String chosenOffer = null;
                            for (String offerName : offerPriority) {
                                for (Decisioning d : passingOffers) {
                                    if (d.criteria_set_name != null &&
                                        d.criteria_set_name.trim().toLowerCase() == offerName.toLowerCase()) {
                                        chosenOffer = offerName;
                                        break;
                                    }
                                }
                                if (chosenOffer != null) break;
                            }

                            // 3. Frozen check
                            Boolean creditFrozen = false;
                            if (report.details != null && report.details.normalized != null
                                && report.details.normalized.CREDIT_FROZEN_STATUS != null) {
                                CreditFrozenStatus frozen = report.details.normalized.CREDIT_FROZEN_STATUS;
                                if ((frozen.EquifaxIndicator != null && frozen.EquifaxIndicator == 'true') ||
                                    (frozen.ExperianIndicator != null && frozen.ExperianIndicator == 'true') ||
                                    (frozen.TransUnionIndicator != null && frozen.TransUnionIndicator == 'true')) {
                                    creditFrozen = true;
                                }
                            }

                            // 4. Set results based on logic
                            if (chosenOffer != null) {
                                accUpdate.Credit_Decision__c = chosenOffer;
                                accUpdate.Credit_Check_Complete__c = true;
                                accUpdate.Credit_Failure_Type__c = null;
                                Decimal multiplier = 1;
                                if (chosenOffer == 'Gold - 0% Retainer')         multiplier = 0;
                                else if (chosenOffer == 'Silver - 50% Retainer') multiplier = 0.5;
                                else if (chosenOffer == 'Bronze - 80% Retainer') multiplier = 0.8;
                                if (acc.Quoted_Retainer__c != null) {
                                    accUpdate.Quoted_Retainer_Amount__c = acc.Quoted_Retainer__c * multiplier;
                                }
                            } else if (creditFrozen) {
                                accUpdate.Credit_Decision__c = 'Credit Frozen';
                                accUpdate.Credit_Failure_Type__c = 'freeze';
                                accUpdate.Credit_Check_Complete__c = false;
                                accUpdate.Quoted_Retainer_Amount__c = acc.Quoted_Retainer__c;
                            } else {
                                // All failed or unknown status
                                accUpdate.Credit_Decision__c = 'Full Retainer';
                                accUpdate.Credit_Failure_Type__c = null;
                                accUpdate.Credit_Check_Complete__c = true;
                                accUpdate.Quoted_Retainer_Amount__c = acc.Quoted_Retainer__c;
                            }

                            // 5. Always reset the submitted flag after processing
                            accUpdate.Credit_Check_Submitted__c = false;

                            accountsToUpdate.add(accUpdate);
                        }
                    } else {
                        System.debug(LoggingLevel.ERROR, 'Callout failed: ' + res.getBody());
                    }
                } catch (Exception ex) {
                    System.debug(LoggingLevel.ERROR, 'An exception occurred: ' + ex.getMessage());
                }
            }

            if (!accountsToUpdate.isEmpty()) {
                update accountsToUpdate;
            }
        }
    }

    public static void createReport(List<Id> accountIds) {
        System.enqueueJob(new APIIntegrationJob(accountIds));
    }

    // ===== API WRAPPER CLASSES =====
    public class ApiResponseWrapper {
        public ApiSection api;
    }
    public class ApiSection {
        public String reference_id;
        public ApiRequest request;
        public ApiResponse response;
    }
    public class ApiRequest {
        public String product;
        public String server;
        public String endpoint;
        public String api_datetime; 
        public String user;
        public String ip;
    }
    public class ApiResponse {
        public Integer code;
        public ResponseData data;
    }
    public class ResponseData {
        public Applicant applicant;
        public Reports reports;
    }
    public class Applicant {
        public String id;
        public String created_at;
        public String firstname;
        public String middlename;
        public String lastname;
        public String phone;
        public String email;
        public String tracking_id;
        public String address_1;
        public String address_2;
        public String city;
        public String state;
        public String zip;
        public String dob;
        public String ssn;
        public String income;
        public String custom;
    }
    public class Reports {
        public List<Object> merged;
        public List<IndividualReport> individual;
    }
    public class IndividualReport {
        public String id;
        public String created_at;
        public String bureau;
        public String processing;
        public String result_status_type;
        public String temporary_shareable_link;
        public List<Decisioning> decisioning;
        public Details details;
    }
    public class Decisioning {
        public String criteria_id;
        public String criteria_set_name;
        public String result;
        public List<Offer> offers;
    }
    public class Offer {
        public Integer id;
        public String name;
        public String tracking_id;
        public String url;
    }
    public class Details {
        public Normalized normalized;
    }
    public class Normalized {
        public CreditFrozenStatus CREDIT_FROZEN_STATUS;
    }
    public class CreditFrozenStatus {
        public String EquifaxIndicator;
        public String ExperianIndicator;
        public String TransUnionIndicator;
    }
}