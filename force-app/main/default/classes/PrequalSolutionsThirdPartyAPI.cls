/**
 * @description API integration class for processing third-party credit checks through PrequalSolutions
 * @author Simple Start Development Team
 * @version 1.0
 */
public without sharing class PrequalSolutionsThirdPartyAPI {

    /*** TEST-ONLY OVERRIDES (no prod impact) ***/
    @TestVisible private static String tvNamedCredential; // e.g., 'prequalSolutionsNC'
    @TestVisible private static String tvScenario;        // e.g., 'Production'

    /**
     * @description Resolves configuration from CMDT (uses @TestVisible overrides during tests if provided)
     * @return Prequal_Integration_Config__mdt config instance
     */
    @TestVisible
    private static Prequal_Integration_Config__mdt getConfig() {
        // If running tests and overrides are provided, synthesize a config object
        if (Test.isRunningTest() && (!String.isBlank(tvNamedCredential) || !String.isBlank(tvScenario))) {
            Prequal_Integration_Config__mdt testCfg = new Prequal_Integration_Config__mdt();
            testCfg.Named_Credential__c = tvNamedCredential;
            testCfg.Scenario__c         = tvScenario;

            // If both are present, return immediately
            if (!String.isBlank(testCfg.Named_Credential__c) && !String.isBlank(testCfg.Scenario__c)) {
                return testCfg;
            }

            // Otherwise merge missing values from real CMDT, then validate
            Prequal_Integration_Config__mdt realCfg = Prequal_Integration_Config__mdt.getInstance('Default');
            if (realCfg == null) {
                throw new AuraHandledException('Prequal Integration Config (Default) not found in CMDT.');
            }
            if (String.isBlank(testCfg.Scenario__c))        testCfg.Scenario__c         = realCfg.Scenario__c;
            if (String.isBlank(testCfg.Named_Credential__c)) testCfg.Named_Credential__c = realCfg.Named_Credential__c;

            if (String.isBlank(testCfg.Scenario__c)) {
                throw new AuraHandledException('Scenario__c is not configured in Prequal Integration Config CMDT.');
            }
            if (String.isBlank(testCfg.Named_Credential__c)) {
                throw new AuraHandledException('Named_Credential__c is not configured in Prequal Integration Config CMDT.');
            }
            return testCfg;
        }

        // Original behavior (prod and when no overrides provided)
        Prequal_Integration_Config__mdt cfg = Prequal_Integration_Config__mdt.getInstance('Default');
        if (cfg == null) {
            throw new AuraHandledException('Prequal Integration Config (Default) not found in CMDT.');
        }
        if (String.isBlank(cfg.Scenario__c)) {
            throw new AuraHandledException('Scenario__c is not configured in Prequal Integration Config CMDT.');
        }
        if (String.isBlank(cfg.Named_Credential__c)) {
            throw new AuraHandledException('Named_Credential__c is not configured in Prequal Integration Config CMDT.');
        }
        return cfg;
    }

    /**
     * @description Queueable job for processing API integration asynchronously
     */
    public without sharing class APIIntegrationJob implements Queueable, Database.AllowsCallouts {
        private Id thirdPartyId;
        private Id parentAccountId;

        public APIIntegrationJob(Id thirdPartyId, Id parentAccountId) {
            this.thirdPartyId = thirdPartyId;
            this.parentAccountId = parentAccountId;
        }

        public void execute(QueueableContext context) {
            try {
                System.debug(LoggingLevel.INFO, '==> Running job for Third Party: ' + thirdPartyId + ', Parent Account: ' + parentAccountId);

                Prequal_Integration_Config__mdt cfg = getConfig();
                String scenario = cfg.Scenario__c;

                System.debug(LoggingLevel.INFO, 'Prequal scenario in use: ' + scenario);
                System.debug(LoggingLevel.INFO, 'Using Named Credential: ' + cfg.Named_Credential__c);

                Account thirdParty = getThirdPartyAccount();
                Account parent = getParentAccount();

                Map<String, Object> requestPayload = buildRequestPayload(thirdParty, scenario);
                HttpResponse response = makeApiCallout(requestPayload, cfg.Named_Credential__c);

                if (response.getStatusCode() == 200) {
                    processSuccessfulResponse(response, thirdParty, parent);
                } else {
                    handleFailedResponse(response);
                }
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Error in APIIntegrationJob: ' + e.getMessage());
                System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
            }
        }

        private Account getThirdPartyAccount() {
            return [
                SELECT Id, FirstName, LastName, PersonMailingStreet, PersonMailingCity, State_A__c,
                       PersonMailingPostalCode, Birthdate__c, PersonMobilePhone, PersonEmail,
                       Annual_household_income__c, Social_Security_Number__c
                FROM Account 
                WHERE Id = :thirdPartyId
                LIMIT 1
            ];
        }

        private Account getParentAccount() {
            return [
                SELECT Id, Quoted_Retainer__c 
                FROM Account 
                WHERE Id = :parentAccountId 
                LIMIT 1
            ];
        }

        private Map<String, Object> buildRequestPayload(Account thirdParty, String scenario) {
            Map<String, Object> applicant = new Map<String, Object>{
                'firstname' => thirdParty.FirstName,
                'middlename' => '',
                'lastname' => thirdParty.LastName,
                'address_1' => thirdParty.PersonMailingStreet,
                'address_2' => '',
                'city' => thirdParty.PersonMailingCity,
                'state' => thirdParty.State_A__c,
                'zip' => thirdParty.PersonMailingPostalCode,
                'dob' => formatBirthdate(thirdParty.Birthdate__c),
                'ssn' => thirdParty.Social_Security_Number__c,
                'phone' => thirdParty.PersonMobilePhone,
                'email' => thirdParty.PersonEmail,
                'income' => thirdParty.Annual_household_income__c != null ? String.valueOf(thirdParty.Annual_household_income__c) : null
            };

            return new Map<String, Object>{
                'applicant' => applicant,
                'scenario' => scenario
            };
        }

        private String formatBirthdate(Date birthdate) {
            if (birthdate == null) {
                return '';
            }
            return DateTime.newInstance(birthdate.year(), birthdate.month(), birthdate.day()).format('MM/dd/yyyy');
        }

        private HttpResponse makeApiCallout(Map<String, Object> requestPayload, String namedCredential) {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:' + namedCredential);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setBody(JSON.serialize(requestPayload));

            Http http = new Http();
            return http.send(req);
        }

        private void processSuccessfulResponse(HttpResponse response, Account thirdParty, Account parent) {
            ApiResponseWrapper resp = (ApiResponseWrapper) JSON.deserialize(response.getBody(), ApiResponseWrapper.class);

            if (isValidResponse(resp)) {
                IndividualReport report = resp.api.response.data.reports.individual[0];
                updateAccountWithCreditDecision(report, thirdParty, parent);
            }
        }

        private Boolean isValidResponse(ApiResponseWrapper resp) {
            return resp != null && 
                   resp.api != null && 
                   resp.api.response != null && 
                   resp.api.response.data != null && 
                   resp.api.response.data.reports != null && 
                   !resp.api.response.data.reports.individual.isEmpty();
        }

        private void updateAccountWithCreditDecision(IndividualReport report, Account thirdParty, Account parent) {
            Account accUpdate = new Account(Id = parent.Id);
            accUpdate.Third_Party__c = thirdParty.Id;
            accUpdate.Annual_household_income__c = thirdParty.Annual_household_income__c;
            accUpdate.Credit_Report_Link__c = report.temporary_shareable_link;

            CreditDecisionData decisionData = new CreditDecisionData();
            decisionData.chosenOffer = determineChosenOffer(report);
            decisionData.creditFrozen = isCreditFrozen(report);
            decisionData.quotedRetainer = parent.Quoted_Retainer__c;

            setCreditDecisionFields(accUpdate, decisionData);

            update accUpdate;
        }

        private String determineChosenOffer(IndividualReport report) {
            List<Decisioning> passingOffers = getPassingOffers(report);
            List<String> offerPriority = new List<String>{
                'Gold - 0% Retainer', 'Silver - 50% Retainer', 'Bronze - 80% Retainer'
            };

            for (String offerName : offerPriority) {
                for (Decisioning d : passingOffers) {
                    if (d.criteria_set_name != null && d.criteria_set_name.trim().toLowerCase() == offerName.toLowerCase()) {
                        return offerName;
                    }
                }
            }
            return null;
        }

        private List<Decisioning> getPassingOffers(IndividualReport report) {
            List<Decisioning> passingOffers = new List<Decisioning>();
            for (Decisioning d : report.decisioning) {
                if (d.result != null && d.result.toLowerCase() == 'pass') {
                    passingOffers.add(d);
                }
            }
            return passingOffers;
        }

        private Boolean isCreditFrozen(IndividualReport report) {
            if (report.details != null && 
                report.details.normalized != null &&
                report.details.normalized.CREDIT_FROZEN_STATUS != null) {

                CreditFrozenStatus frozen = report.details.normalized.CREDIT_FROZEN_STATUS;
                return (frozen.EquifaxIndicator == 'true') ||
                       (frozen.ExperianIndicator == 'true') ||
                       (frozen.TransUnionIndicator == 'true');
            }
            return false;
        }

        private void setCreditDecisionFields(Account accUpdate, CreditDecisionData decisionData) {
            Decimal multiplier = getRetainerMultiplier(decisionData.chosenOffer);

            if (decisionData.chosenOffer != null) {
                accUpdate.Credit_Decision__c = decisionData.chosenOffer;
                accUpdate.Credit_Check_Complete__c = true;
                accUpdate.Credit_Failure_Type__c = null;
                accUpdate.Quoted_Retainer_Amount__c = decisionData.quotedRetainer != null ? decisionData.quotedRetainer * multiplier : null;
            } else if (decisionData.creditFrozen) {
                accUpdate.Credit_Decision__c = 'Credit Frozen';
                accUpdate.Credit_Check_Complete__c = false;
                accUpdate.Credit_Failure_Type__c = 'freeze';
                accUpdate.Quoted_Retainer_Amount__c = decisionData.quotedRetainer;
            } else {
                accUpdate.Credit_Decision__c = 'Full Retainer';
                accUpdate.Credit_Check_Complete__c = true;
                accUpdate.Credit_Failure_Type__c = null;
                accUpdate.Quoted_Retainer_Amount__c = decisionData.quotedRetainer;
            }
        }

        private Decimal getRetainerMultiplier(String chosenOffer) {
            if (chosenOffer == 'Gold - 0% Retainer') {
                return 0;
            } else if (chosenOffer == 'Silver - 50% Retainer') {
                return 0.5;
            } else if (chosenOffer == 'Bronze - 80% Retainer') {
                return 0.8;
            }
            return 1;
        }

        private void handleFailedResponse(HttpResponse response) {
            System.debug(LoggingLevel.ERROR, 'Callout failed with status: ' + response.getStatusCode());
            System.debug(LoggingLevel.ERROR, 'Response body: ' + response.getBody());
        }
    }

    // Wrapper class to reduce parameter count
    private class CreditDecisionData {
        public String chosenOffer;
        public Boolean creditFrozen;
        public Decimal quotedRetainer;
    }

    // Include all response wrapper classes here (unchanged)
    public class ApiResponseWrapper { public ApiSection api; }
    public class ApiSection { public String reference_id; public ApiRequest request; public ApiResponse response; }
    public class ApiRequest { public String product; public String server; public String endpoint; public String api_datetime; public String user; public String ip; }
    public class ApiResponse { public Integer code; public ResponseData data; }
    public class ResponseData { public Applicant applicant; public Reports reports; }
    public class Applicant { public String id; public String created_at; public String firstname; public String middlename; public String lastname; public String phone; public String email; public String tracking_id; public String address_1; public String address_2; public String city; public String state; public String zip; public String dob; public String ssn; public String income; public String custom; }
    public class Reports { public List<Object> merged; public List<IndividualReport> individual; }
    public class IndividualReport { public String id; public String created_at; public String bureau; public String processing; public String result_status_type; public String temporary_shareable_link; public List<Decisioning> decisioning; public Details details; }
    public class Decisioning { public String criteria_id; public String criteria_set_name; public String result; public List<Offer> offers; }
    public class Offer { public Integer id; public String name; public String tracking_id; public String url; }
    public class Details { public Normalized normalized; }
    public class Normalized { public CreditFrozenStatus CREDIT_FROZEN_STATUS; }
    public class CreditFrozenStatus { public String EquifaxIndicator; public String ExperianIndicator; public String TransUnionIndicator; }
}