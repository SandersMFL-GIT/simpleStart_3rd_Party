public class isoftpulAPIIntegration {

    public class APIIntegrationJob implements Queueable, Database.AllowsCallouts {
        private List<Id> accountIds;
        private Boolean isThirdParty;

        public APIIntegrationJob(List<Id> accountIds, Boolean isThirdParty) {
            this.accountIds = accountIds;
            this.isThirdParty = isThirdParty;
            System.debug(LoggingLevel.INFO, '==> APIIntegrationJob constructed with IDs: ' + accountIds + ' | isThirdParty: ' + isThirdParty);
        }

        public void execute(QueueableContext context) {
            System.debug(LoggingLevel.INFO, '==> Starting APIIntegrationJob.execute()...');
            System.debug(LoggingLevel.INFO, 'Context: ' + context);

            // Query required fields based on record type
            List<Account> accounts;
            if (!isThirdParty) {
                accounts = [
                    SELECT Id, Name, Phone, Quoted_Retainer__c,
                           Responsible_Attorney__c, Responsible_Attorney_Email_A__c,
                           FirstName, LastName, PersonMailingStreet, PersonMailingCity,
                           State_A__c, PersonMailingPostalCode
                      FROM Account
                     WHERE Id IN :accountIds
                ];
            } else {
                accounts = [
                    SELECT Id, Name, Phone, Quoted_Retainer__c,
                           Responsible_Attorney__c, Responsible_Attorney_Email_A__c,
                           Third_Party__r.FirstName, Third_Party__r.LastName,
                           Third_Party__r.PersonMailingStreet, Third_Party__r.PersonMailingCity,
                           Third_Party__r.State_A__c, Third_Party__r.PersonMailingPostalCode
                      FROM Account
                     WHERE Id IN :accountIds
                ];
            }

            System.debug(LoggingLevel.INFO, '==> Fetched ' + accounts.size() + ' accounts for processing.');
            System.debug(LoggingLevel.DEBUG, 'Account records: ' + JSON.serializePretty(accounts));

            // List to hold updated records
            List<Account> acUpdate = new List<Account>();

            // Loop through each account and process the callout
            for (Account a : accounts) {
                System.debug(LoggingLevel.INFO, '--- Processing Account Id: ' + a.Id + ' ---');
                HttpRequest req = new HttpRequest();
                req.setEndpoint('callout:IsoftpullNC/reports');
                req.setMethod('POST');
                req.setHeader('Content-Type', 'application/x-www-form-urlencoded');

                // Determine field values
                String firstName = '', lastName = '', address = '', city = '', state = '', zip = '';
                if (!isThirdParty) {
                    firstName = a.FirstName != null ? a.FirstName : '';
                    lastName  = a.LastName  != null ? a.LastName  : '';
                    address   = a.PersonMailingStreet != null ? a.PersonMailingStreet : '';
                    city      = a.PersonMailingCity   != null ? a.PersonMailingCity   : '';
                    state     = a.State_A__c          != null ? a.State_A__c          : '';
                    zip       = a.PersonMailingPostalCode != null ? a.PersonMailingPostalCode : '';
                } else {
                    firstName = (a.Third_Party__r != null && a.Third_Party__r.FirstName != null)
                        ? a.Third_Party__r.FirstName : '';
                    lastName  = (a.Third_Party__r != null && a.Third_Party__r.LastName  != null)
                        ? a.Third_Party__r.LastName  : '';
                    address   = (a.Third_Party__r != null && a.Third_Party__r.PersonMailingStreet != null)
                        ? a.Third_Party__r.PersonMailingStreet : '';
                    city      = (a.Third_Party__r != null && a.Third_Party__r.PersonMailingCity   != null)
                        ? a.Third_Party__r.PersonMailingCity   : '';
                    state     = (a.Third_Party__r != null && a.Third_Party__r.State_A__c          != null)
                        ? a.Third_Party__r.State_A__c          : '';
                    zip       = (a.Third_Party__r != null && a.Third_Party__r.PersonMailingPostalCode != null)
                        ? a.Third_Party__r.PersonMailingPostalCode : '';
                }
                System.debug(LoggingLevel.DEBUG, 'Extracted fields - firstName: ' + firstName + ', lastName: ' + lastName + ', address: ' + address + ', city: ' + city + ', state: ' + state + ', zip: ' + zip);

                // Construct the POST body
                String body = 'first_name=' + EncodingUtil.urlEncode(firstName, 'UTF-8') +
                              '&last_name='  + EncodingUtil.urlEncode(lastName, 'UTF-8') +
                              '&address='    + EncodingUtil.urlEncode(address, 'UTF-8') +
                              '&city='       + EncodingUtil.urlEncode(city, 'UTF-8') +
                              '&state='      + EncodingUtil.urlEncode(state, 'UTF-8') +
                              '&zip='        + EncodingUtil.urlEncode(zip, 'UTF-8');
                req.setBody(body);

                System.debug(LoggingLevel.INFO, 'Sending request for Account Id: ' + a.Id);
                System.debug(LoggingLevel.DEBUG, 'Endpoint: ' + req.getEndpoint());
                System.debug(LoggingLevel.DEBUG, 'Request Body: ' + req.getBody());

                Http http = new Http();
                try {
                    HttpResponse res = http.send(req);
                    System.debug(LoggingLevel.INFO, 'Received response with status: ' + res.getStatusCode());
                    System.debug(LoggingLevel.DEBUG, 'Response Body: ' + res.getBody());

                    if (res.getStatusCode() == 200) {
                        // Deserialize the response
                        ResponseDataWrapper responseWrapper =
                            (ResponseDataWrapper) JSON.deserialize(res.getBody(), ResponseDataWrapper.class);
                        System.debug(LoggingLevel.DEBUG, 'Deserialized response wrapper: ' + JSON.serializePretty(responseWrapper));

                        Account accountUpd = new Account(Id = a.Id);

                        // Normalize the intelligence result for comparison
                        String resultRaw        = (responseWrapper.intelligence != null) ? responseWrapper.intelligence.result : null;
                        String resultNormalized = (resultRaw != null) ? resultRaw.toLowerCase() : '';
                        System.debug(LoggingLevel.DEBUG, 'Parsed resultRaw: ' + resultRaw + ', normalized: ' + resultNormalized);

                        String Intelligence;
                        Decimal multiplier = null;

                        // Logic for setting retainer, credit check, etc.
                        if (resultNormalized == 'failed') {
                            Intelligence                            = 'Failed';
                            accountUpd.Credit_Check_Complete__c     = false;
                            accountUpd.Send_Credit_Request__c       = false;
                        } else if (resultNormalized == 'no offers matched') {
                            Boolean freezeFound = false;
                            if (responseWrapper.reports != null) {
                                freezeFound = (
                                    (responseWrapper.reports.transunion != null && responseWrapper.reports.transunion.failure_type == 'freeze') ||
                                    (responseWrapper.reports.equifax   != null && responseWrapper.reports.equifax.failure_type   == 'freeze') ||
                                    (responseWrapper.reports.experian  != null && responseWrapper.reports.experian.failure_type  == 'freeze')
                                );
                            }
                            if (freezeFound) {
                                Intelligence                        = 'Failed';
                                accountUpd.Credit_Check_Complete__c = false;
                                accountUpd.Send_Credit_Request__c   = false;
                            } else {
                                Intelligence                        = 'Full Retainer';
                                multiplier                          = 1;
                                accountUpd.Credit_Check_Complete__c = true;
                                accountUpd.Send_Credit_Request__c   = true;
                            }
                        } else if (resultNormalized == 'gold') {
                            Intelligence = 'Gold - 0% Retainer'; multiplier   = 0;
                        } else if (resultNormalized == 'silver') {
                            Intelligence = 'Silver - 50% Retainer'; multiplier = 0.5;
                        } else if (resultNormalized == 'bronze') {
                            Intelligence = 'Bronze - 80% Retainer'; multiplier = 0.8;
                        } else if (resultNormalized == 'full retainer') {
                            Intelligence = 'Full Retainer'; multiplier = 1;
                        } else {
                            Intelligence                            = 'Unknown';
                            accountUpd.Credit_Check_Complete__c     = false;
                            accountUpd.Send_Credit_Request__c       = false;
                        }
                        System.debug(LoggingLevel.DEBUG, 'Mapped Intelligence: ' + Intelligence + ', multiplier: ' + multiplier);

                        if (Intelligence != 'Failed') {
                            accountUpd.Credit_Check_Complete__c = true;
                        }
                        accountUpd.Credit_Decision__c = Intelligence;

                        // Process any report failures
                        if (responseWrapper.reports != null) {
                            String failureStatuses = '';
                            String failureMessages = '';
                            String failureTypes    = '';

                            if (responseWrapper.reports.equifax != null && responseWrapper.reports.equifax.status == 'failure') {
                                failureStatuses += 'Equifax: ' + responseWrapper.reports.equifax.status + '\n';
                                failureMessages += 'Equifax: ' + responseWrapper.reports.equifax.message + '\n';
                                failureTypes    += 'Equifax: ' + responseWrapper.reports.equifax.failure_type + '\n';
                            }
                            if (responseWrapper.reports.transunion != null && responseWrapper.reports.transunion.status == 'failure') {
                                failureStatuses += 'TransUnion: ' + responseWrapper.reports.transunion.status + '\n';
                                failureMessages += 'TransUnion: ' + responseWrapper.reports.transunion.message + '\n';
                                failureTypes    += 'TransUnion: ' + responseWrapper.reports.transunion.failure_type + '\n';
                            }
                            if (responseWrapper.reports.experian != null && responseWrapper.reports.experian.status == 'failure') {
                                failureStatuses += 'Experian: ' + responseWrapper.reports.experian.status + '\n';
                                failureMessages += 'Experian: ' + responseWrapper.reports.experian.message + '\n';
                                failureTypes    += 'Experian: ' + responseWrapper.reports.experian.failure_type + '\n';
                            }

                            accountUpd.Credit_Status__c       = failureStatuses;
                            accountUpd.Credit_Message__c      = failureMessages;
                            accountUpd.Credit_Failure_Type__c = failureTypes;
                            System.debug(LoggingLevel.DEBUG, 'Aggregated failureStatuses: ' + failureStatuses);

                            // Send email notification if attorney email is present
                            if (a.Responsible_Attorney_Email_A__c != null) {
                                System.debug(LoggingLevel.INFO, 'Sending email notification to: ' + a.Responsible_Attorney_Email_A__c);
                                sendEmailNotification(a, Intelligence);

                                // Additionally send a freeze-specific email if any failure type indicates a freeze
                                if (failureTypes != null && failureTypes.contains('freeze')) {
                                    System.debug(LoggingLevel.INFO, 'Sending freeze alert email notification to: ' + a.Responsible_Attorney_Email_A__c);
                                    sendFreezeEmailNotification(a);
                                }
                            }
                        }    

                        accountUpd.Credit_Report_Link__c     = (responseWrapper.reports != null) ? responseWrapper.reports.link : null;
                        System.debug(LoggingLevel.DEBUG, 'Report link set to: ' + accountUpd.Credit_Report_Link__c);

                        // Reset submitted flag and compute retainer amount
                        accountUpd.Credit_Check_Submitted__c = false;
                        System.debug(LoggingLevel.DEBUG, 'Credit_Check_Submitted__c reset to false.');
                        if (multiplier != null && a.Quoted_Retainer__c != null) {
                            accountUpd.Quoted_Retainer_Amount__c = multiplier * a.Quoted_Retainer__c;
                            System.debug(LoggingLevel.DEBUG, 'Calculated Quoted_Retainer_Amount__c: ' + accountUpd.Quoted_Retainer_Amount__c);
                        }

                        acUpdate.add(accountUpd);
                        System.debug(LoggingLevel.DEBUG, 'Account added to update list: ' + accountUpd);
                    } else {
                        System.debug(LoggingLevel.WARN, 'Callout failed for account ' + a.Id + ' with status code: ' + res.getStatusCode());
                        System.debug(LoggingLevel.DEBUG, 'Response body: ' + res.getBody());
                    }
                } catch (Exception e) {
                    System.debug(LoggingLevel.ERROR, 'Error during callout for account ' + a.Id + ': ' + e.getMessage());
                }
            } // end for accounts

            // Bulk update accounts that have been processed
            System.debug(LoggingLevel.INFO, '==> About to update ' + acUpdate.size() + ' Account records');
            if (!acUpdate.isEmpty()) {
                try {
                    update acUpdate;
                    System.debug(LoggingLevel.INFO, '==> Successfully updated accounts: ' + acUpdate);
                } catch (Exception ex) {
                    System.debug(LoggingLevel.ERROR, 'Error updating accounts: ' + ex.getMessage());
                }
            }

            System.debug(LoggingLevel.INFO, '==> APIIntegrationJob.execute() complete.');
        }

        /**
         * Helper method to send email notifications.
         */
        private void sendEmailNotification(Account a, String intelligence) {
            System.debug(LoggingLevel.INFO, '==> Entered sendEmailNotification() for Account Id: ' + a.Id);
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new String[] { a.Responsible_Attorney_Email_A__c });
            String subject = isThirdParty ? 'An email from Salesforce' : 'Client Approved PC Now';
            mail.setSenderDisplayName('Salesforce Support');
            mail.setSubject(subject);

            String emailBody = '<p>Hello,</p>' +
                               '<p>A new credit check for ' + a.Name + ' is available for review.</p>' +
                               '<p>Rating Received: <b>' + intelligence + '</b></p>' +
                               '<p>Mobile#: <b>' + a.Phone + '</b></p>' +
                               '<p>Account URL:</p>' +
                               '<p><a href="https://modernfamilylaw.lightning.force.com/lightning/r/Account/' +
                               a.Id + '/view">View Account in Salesforce</a></p>';

            mail.setHtmlBody(emailBody);
            System.debug(LoggingLevel.DEBUG, 'Email body: ' + emailBody);
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
            System.debug(LoggingLevel.INFO, '==> Email sent to ' + a.Responsible_Attorney_Email_A__c);
        }

        /**
         * Helper method to send freeze alert email notifications.
         */
        private void sendFreezeEmailNotification(Account a) {
            System.debug(LoggingLevel.INFO, '==> Entered sendFreezeEmailNotification() for Account Id: ' + a.Id);
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new String[] { a.Responsible_Attorney_Email_A__c });
            String subject = 'Urgent: Action Required on Credit Report';
            mail.setSenderDisplayName('Salesforce Support');
            mail.setSubject(subject);

            String emailBody = '<p>Hello,</p>' +
                               '<p>Please be advised that there is a freeze alert on the credit report for ' + a.Name + '.</p>' +
                               '<p>Immediate action may be required to address this issue.</p>' +
                               '<p>Account URL:</p>' +
                               '<p><a href="https://modernfamilylaw.lightning.force.com/lightning/r/Account/' +
                               a.Id + '/view">View Account in Salesforce</a></p>';

            mail.setHtmlBody(emailBody);
            System.debug(LoggingLevel.DEBUG, 'Freeze alert email body: ' + emailBody);
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
            System.debug(LoggingLevel.INFO, '==> Freeze alert email sent to ' + a.Responsible_Attorney_Email_A__c);
        }
    }

    // Public methods to enqueue the Queueable jobs
    public static void createReport(List<Id> accountIds) {
        System.debug(LoggingLevel.INFO, '==> createReport() called with IDs: ' + accountIds);
        System.enqueueJob(new APIIntegrationJob(accountIds, false));
    }

    public static void createReportForThirdParty(List<Id> accountIds) {
        System.debug(LoggingLevel.INFO, '==> createReportForThirdParty() called with IDs: ' + accountIds);
        System.enqueueJob(new APIIntegrationJob(accountIds, true));
    }

    // Response wrapper classes for JSON deserialization
    public class ResponseDataWrapper {
        public Applicant applicant { get; set; }
        public Intelligence intelligence { get; set; }
        public Reports reports { get; set; }
    }
    public class Applicant {
        public String first_name { get; set; }
        public String middle_name { get; set; }
        public String last_name  { get; set; }
        public String address    { get; set; }
        public String city       { get; set; }
        public String state      { get; set; }
        public String zip        { get; set; }
        public String date_of_birth { get; set; }
        public String ssn        { get; set; }
        public String email      { get; set; }
        public String phone      { get; set; }
    }
    public class Intelligence {
        public String result { get; set; }
        public String name   { get; set; }
    }
    public class Reports {
        public String link       { get; set; }
        public ReportStatus equifax    { get; set; }
        public ReportStatus transunion { get; set; }
        public ReportStatus experian   { get; set; }
    }
    public class ReportStatus {
        public String status       { get; set; }
        public String message      { get; set; }
        public String failure_type { get; set; }
    }
}