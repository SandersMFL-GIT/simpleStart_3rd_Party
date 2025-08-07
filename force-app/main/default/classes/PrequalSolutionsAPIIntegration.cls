public without sharing class PrequalSolutionsAPIIntegration {
    /**
     * Usage:
     *   PrequalSolutionsAPIIntegration.createReport(accountIds); 
     *   PrequalSolutionsAPIIntegration.createReportForThirdParty(accountIds); 
     */

    // =======================
    // === MAIN LOGIC CLASS ==
    // =======================
    public class APIIntegrationJob implements Queueable, Database.AllowsCallouts {
        private List<Id> accountIds;
        private Boolean isThirdParty;

        public APIIntegrationJob(List<Id> accountIds, Boolean isThirdParty) {
            this.accountIds = accountIds;
            this.isThirdParty = isThirdParty;
        }

        public void execute(QueueableContext context) {
            System.debug(LoggingLevel.INFO, '==> Starting PrequalSolutionsAPIIntegration with isThirdParty=' + isThirdParty);

            // Query relevant fields
            List<Account> accounts;
            if (!isThirdParty) {
                accounts = [
                    SELECT Id, FirstName, MiddleName, LastName, PersonMailingStreet, PersonMailingCity, State_A__c, PersonMailingPostalCode, 
                           Birthdate__c, Phone, PersonEmail, Quoted_Retainer__c, Responsible_Attorney__c, Responsible_Attorney_Email_A__c,
                           Credit_Check_Submitted__c, Annual_household_income__c, Social_Security_Number__c 
                    FROM Account WHERE Id IN :accountIds
                ];
            } else {
                accounts = [
                    SELECT Id, Quoted_Retainer__c, Responsible_Attorney_Email_A__c, Responsible_Attorney__c, Credit_Check_Submitted__c,
                        Third_Party__r.FirstName, Third_Party__r.LastName, Third_Party__r.PersonMailingStreet,
                        Third_Party__r.PersonMailingCity, Third_Party__r.State_A__c, Third_Party__r.PersonMailingPostalCode, 
                        Third_Party__r.Birthdate__c, Third_Party__r.Phone, Third_Party__r.PersonEmail, Third_Party__r.Annual_household_income__c, Third_Party__r.Social_Security_Number__c
                    FROM Account WHERE Id IN :accountIds
                ];
            }

            System.debug(LoggingLevel.INFO, 'Queried Accounts: ' + accounts);

            List<Account> accountsToUpdate = new List<Account>();
            for (Account acc : accounts) {
                try {
                    System.debug(LoggingLevel.INFO, 'Processing Account: ' + acc.Id);

                    // --- 1. Build JSON Payload ---
                    Map<String, Object> applicant = new Map<String, Object>();
                    if (!isThirdParty) {
                        // Use fields from Account itself
                        applicant.put('firstname', acc.FirstName);
                        applicant.put('middlename', acc.MiddleName);
                        applicant.put('lastname', acc.LastName);
                        applicant.put('address_1', acc.PersonMailingStreet);
                        applicant.put('address_2', '');
                        applicant.put('city', acc.PersonMailingCity);
                        applicant.put('state', acc.State_A__c);
                        applicant.put('zip', acc.PersonMailingPostalCode);
                        applicant.put('dob', acc.Birthdate__c != null ? acc.Birthdate__c.format() : '');
                        applicant.put('ssn', acc.Social_Security_Number__c  );
                        applicant.put('phone', acc.Phone);
                        applicant.put('email', acc.PersonEmail);
                    } else {
                        // Use fields from related Third Party record
                        applicant.put('firstname', acc.Third_Party__r != null ? acc.Third_Party__r.FirstName : '');
                        applicant.put('middlename', '');
                        applicant.put('lastname', acc.Third_Party__r != null ? acc.Third_Party__r.LastName : '');
                        applicant.put('address_1', acc.Third_Party__r != null ? acc.Third_Party__r.PersonMailingStreet : '');
                        applicant.put('address_2', '');
                        applicant.put('city', acc.Third_Party__r != null ? acc.Third_Party__r.PersonMailingCity : '');
                        applicant.put('state', acc.Third_Party__r != null ? acc.Third_Party__r.State_A__c : '');
                        applicant.put('zip', acc.Third_Party__r != null ? acc.Third_Party__r.PersonMailingPostalCode : '');
                        applicant.put('dob', acc.Third_Party__r != null && acc.Third_Party__r.Birthdate__c != null ? acc.Third_Party__r.Birthdate__c.format() : '');
                        applicant.put('ssn', acc.Third_Party__r != null ? acc.Third_Party__r.Social_Security_Number__c  : '');
                        applicant.put('phone', acc.Third_Party__r != null ? acc.Third_Party__r.Phone : '');
                        applicant.put('email', acc.Third_Party__r != null ? acc.Third_Party__r.PersonEmail : '');
                    }
                    applicant.put('income', acc.Annual_household_income__c != null ? String.valueOf(acc.Annual_household_income__c) : null);

                    System.debug(LoggingLevel.DEBUG, 'Applicant Payload: ' + applicant);

                    Map<String, Object> requestPayload = new Map<String, Object>{
                        'applicant' => applicant,
                        'scenario'  => 'bnGbqo'
                    };

                    String debugJson = JSON.serializePretty(requestPayload);
                    System.debug(LoggingLevel.DEBUG, 'JSON Request Body: ' + debugJson);

                    HttpRequest req = new HttpRequest();
                    req.setEndpoint('callout:prequalSolutionsNC/test-api/applicant');
                    req.setMethod('POST');
                    req.setHeader('Content-Type', 'application/json');
                    req.setBody(JSON.serialize(requestPayload));

                    System.debug(LoggingLevel.INFO, 'HTTP Request: ' + req);

                    Http http = new Http();
                    HttpResponse res = http.send(req);

                    System.debug(LoggingLevel.INFO, 'API Callout status: ' + res.getStatusCode());
                    System.debug(LoggingLevel.DEBUG, 'API Response Body: ' + res.getBody());

                    if (res.getStatusCode() == 200) {
                        ApiResponseWrapper resp =
                            (ApiResponseWrapper) JSON.deserialize(res.getBody(), ApiResponseWrapper.class);

                        // ==== FULL DEBUG DUMP ====
                        System.debug(LoggingLevel.DEBUG, 'Full ApiResponseWrapper:\n' + JSON.serializePretty(resp));
                        if (resp.api != null) {
                            System.debug(LoggingLevel.DEBUG, 'ApiSection:\n' + JSON.serializePretty(resp.api));
                            if (resp.api.response != null) {
                                System.debug(LoggingLevel.DEBUG, 'ApiResponse:\n' + JSON.serializePretty(resp.api.response));
                                if (resp.api.response.data != null) {
                                    System.debug(LoggingLevel.DEBUG, 'ResponseData:\n' + JSON.serializePretty(resp.api.response.data));
                                    System.debug(LoggingLevel.DEBUG, 'Applicant:\n' + JSON.serializePretty(resp.api.response.data.applicant));

                                    Reports rpt = resp.api.response.data.reports;
                                    System.debug(LoggingLevel.DEBUG, 'Reports.merged:\n' + JSON.serializePretty(rpt.merged));
                                    System.debug(LoggingLevel.DEBUG, 'Reports.individual:\n' + JSON.serializePretty(rpt.individual));

                                    for (IndividualReport ir : rpt.individual) {
                                        System.debug(LoggingLevel.DEBUG, 'IndividualReport entry:\n' + JSON.serializePretty(ir));

                                        for (Decisioning d : ir.decisioning) {
                                            System.debug(LoggingLevel.DEBUG, ' Decisioning:\n' + JSON.serializePretty(d));
                                            if (d.offers != null) {
                                                for (Offer o : d.offers) {
                                                    System.debug(LoggingLevel.DEBUG, '  Offer:\n' + JSON.serializePretty(o));
                                                }
                                            }
                                        }

                                        if (ir.details != null && ir.details.normalized != null) {
                                            System.debug(LoggingLevel.DEBUG, ' Details.normalized:\n' + JSON.serializePretty(ir.details.normalized));
                                        }
                                    }
                                }
                            }
                        }

                        if (
                            resp != null && resp.api != null && resp.api.response != null &&
                            resp.api.response.data != null && resp.api.response.data.reports != null &&
                            resp.api.response.data.reports.individual != null && !resp.api.response.data.reports.individual.isEmpty()
                        ) {
                            IndividualReport report = resp.api.response.data.reports.individual[0];
                            System.debug(LoggingLevel.INFO, 'Individual Report: ' + report);
                            Account accUpdate = new Account(Id = acc.Id);

                            // 1.temporary_shareable_link as the report link
                            accUpdate.Credit_Report_Link__c = report.temporary_shareable_link;
                            System.debug(LoggingLevel.INFO, 'Report Link: ' + report.temporary_shareable_link);

                            // 2. Decisioning 
                            List<Decisioning> passingOffers = new List<Decisioning>();
                            for (Decisioning d : report.decisioning) {
                                if (d != null && d.result != null && d.result.toLowerCase() == 'pass') {
                                    passingOffers.add(d);
                                }
                            }
                            System.debug(LoggingLevel.DEBUG, 'Passing Offers: ' + passingOffers);

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
                            System.debug(LoggingLevel.INFO, 'Chosen Offer: ' + chosenOffer);

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
                            System.debug(LoggingLevel.INFO, 'Frozen detected: ' + creditFrozen);

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
                                System.debug(LoggingLevel.INFO, 'Decision: ' + chosenOffer + ', Multiplier: ' + multiplier);
                            } else if (creditFrozen) {
                                accUpdate.Credit_Decision__c = 'Failed- Follow up with PC';
                                accUpdate.Credit_Failure_Type__c = 'freeze';
                                accUpdate.Credit_Check_Complete__c = false;
                                accUpdate.Quoted_Retainer_Amount__c = acc.Quoted_Retainer__c;
                                System.debug(LoggingLevel.INFO, 'Frozen: Setting Credit Decision to Failed- Follow up with PC');
                            } else {
                                // All failed or unknown status
                                accUpdate.Credit_Decision__c = 'Full Retainer';
                                accUpdate.Credit_Failure_Type__c = null;
                                accUpdate.Credit_Check_Complete__c = true;
                                accUpdate.Quoted_Retainer_Amount__c = acc.Quoted_Retainer__c;
                                System.debug(LoggingLevel.INFO, 'All failed/unknown: Setting Credit Decision to Full Retainer');
                            }

                            // 5. Always reset the submitted flag after processing
                            accUpdate.Credit_Check_Submitted__c = false;
                            System.debug(LoggingLevel.INFO, 'Credit_Check_Submitted__c set to false for Account: ' + acc.Id);

                            accountsToUpdate.add(accUpdate);
                            System.debug(LoggingLevel.DEBUG, 'Prepared Account Update: ' + accUpdate);
                        } else {
                            System.debug(LoggingLevel.ERROR, 'Malformed response or missing report for Account: ' + acc.Id);
                        }
                    } else {
                        System.debug(LoggingLevel.ERROR, 'Callout failed: ' + res.getBody());
                    }
                } catch (Exception ex) {
                    System.debug(LoggingLevel.ERROR, 'Error for Account ' + acc.Id + ': ' + ex.getMessage());
                }
            }

            if (!accountsToUpdate.isEmpty()) {
                try {
                    System.debug(LoggingLevel.INFO, 'Updating Accounts: ' + accountsToUpdate);
                    update accountsToUpdate;
                    System.debug(LoggingLevel.INFO, 'Accounts updated: ' + accountsToUpdate.size());
                } catch (Exception ex) {
                    System.debug(LoggingLevel.ERROR, 'Update failed: ' + ex.getMessage());
                }
            } else {
                System.debug(LoggingLevel.INFO, 'No accounts to update in this execution.');
            }
        }
    }

    // ===== Public Methods for Enqueueing =====
    public static void createReport(List<Id> accountIds) {
        System.debug(LoggingLevel.INFO, 'Enqueueing createReport with Account IDs: ' + accountIds);
        System.enqueueJob(new APIIntegrationJob(accountIds, false));
    }
    public static void createReportForThirdParty(List<Id> accountIds) {
        System.debug(LoggingLevel.INFO, 'Enqueueing createReportForThirdParty with Account IDs: ' + accountIds);
        System.enqueueJob(new APIIntegrationJob(accountIds, true));
    }

    // ==============
    // API Wrappers
    // ==============
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