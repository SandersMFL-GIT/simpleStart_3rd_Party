/**
 * Handles enqueueing the Isoftpull APIIntegrationJob
 * when Credit_Check_Submitted__c flips true.
 */
public inherited sharing class IsoftpullCreditCheckHandler {
    /**
     * Enqueue queueable jobs for all passed Account Ids.
     */
    public static void run(List<Id> accountIds) {
        if (accountIds == null || accountIds.isEmpty()) {
            return;
        }
        // Fetch applicant type to route client vs third-party
        Map<Id, Account> accts = new Map<Id, Account>(
            [SELECT Id, Credit_Applicant__c 
               FROM Account 
              WHERE Id IN :accountIds]
        );
        
        List<Id> clientIds     = new List<Id>();
        List<Id> thirdPartyIds = new List<Id>();
        for (Account a : accts.values()) {
            if (a.Credit_Applicant__c == 'Client') {
                clientIds.add(a.Id);
            } else if (a.Credit_Applicant__c == 'Third Party') {
                thirdPartyIds.add(a.Id);
            }
        }

        if (!clientIds.isEmpty()) {
            System.debug(LoggingLevel.INFO, '► Isoftpull (Client) for ' + clientIds);
            isoftpulAPIIntegration.createReport(clientIds);
        }
        if (!thirdPartyIds.isEmpty()) {
            System.debug(LoggingLevel.INFO, '► Isoftpull (3P) for ' + thirdPartyIds);
            isoftpulAPIIntegration.createReportForThirdParty(thirdPartyIds);
        }
    }
}