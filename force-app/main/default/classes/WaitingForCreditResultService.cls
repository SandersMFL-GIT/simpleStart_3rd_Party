public without sharing class WaitingForCreditResultService {
    public class DecisionResult {
        @AuraEnabled public String creditDecision;
        @AuraEnabled public String reportLink;
        @AuraEnabled public Decimal quotedRetainer;
        @AuraEnabled public Decimal reducedRetainer;
        @AuraEnabled public String accountName;
    }

    @AuraEnabled(cacheable=true)
    public static DecisionResult getDecisionWithLink(Id accountId) {
        DecisionResult out = new DecisionResult();
        if (accountId == null) { return out; }
        try {
            // This is not FLS safe and may fail for guest users
            Account a = [SELECT Id, Credit_Decision__c, Credit_Report_Link__c, Quoted_Retainer__c, Quoted_Retainer_Amount__c, Name
                         FROM Account WHERE Id = :accountId LIMIT 1];
            out.creditDecision = a.Credit_Decision__c;
            out.reportLink = a.Credit_Report_Link__c;
            out.quotedRetainer = a.Quoted_Retainer__c;
            out.reducedRetainer = a.Quoted_Retainer_Amount__c;
            out.accountName = a.Name;
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'WaitingForCreditResultService.getDecisionWithLink error: ' + ex.getMessage());
            throw new AuraHandledException(ex.getMessage());
        }
        return out;
    }

    @AuraEnabled(cacheable=true)
    public static String getCreditDecision(Id accountId) {
        if (accountId == null) { return null; }
        try {
            if (!Schema.sObjectType.Account.fields.Credit_Decision__c.isAccessible()) {
                return null;
            }
            Account a = [SELECT Credit_Decision__c FROM Account WHERE Id = :accountId LIMIT 1];
            return a.Credit_Decision__c;
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'WaitingForCreditResultService.getCreditDecision error: ' + ex.getMessage());
            throw new AuraHandledException(ex.getMessage());
        }
    }

    /**
     * @description FLS-safe method to get account decision details as a map.
     * Checks field accessibility before querying to prevent security exceptions.
     * @param accountId The ID of the Account to query.
     * @return A map of field names to values for accessible fields.
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getDecisionAsMap(Id accountId) {
        Map<String, Object> out = new Map<String, Object>();
        if (accountId == null) { return out; }

        try {
            Map<String, String> fieldToMapKey = new Map<String, String>{
                'Credit_Decision__c' => 'creditDecision',
                'Credit_Report_Link__c' => 'reportLink',
                'Quoted_Retainer__c' => 'quotedRetainer',
                'Quoted_Retainer_Amount__c' => 'reducedRetainer',
                'Name' => 'accountName'
            };

            List<String> accessibleFields = new List<String>();
            for (String fieldName : fieldToMapKey.keySet()) {
                if (Schema.SObjectType.Account.fields.getMap().get(fieldName).getDescribe().isAccessible()) {
                    accessibleFields.add(fieldName);
                }
            }

            if (accessibleFields.isEmpty()) {
                System.debug(LoggingLevel.WARN, 'WaitingForCreditResultService: No decision fields are accessible for the current user.');
                return out;
            }

            String soqlQuery = 'SELECT ' + String.join(accessibleFields, ', ') + ' FROM Account WHERE Id = :accountId LIMIT 1';
            List<Account> accounts = Database.query(soqlQuery);

            if (!accounts.isEmpty()) {
                Account a = accounts[0];
                for (String fieldName : accessibleFields) {
                    out.put(fieldToMapKey.get(fieldName), a.get(fieldName));
                }
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'WaitingForCreditResultService.getDecisionAsMap error: ' + ex.getMessage() + ' Stack: ' + ex.getStackTraceString());
            throw new AuraHandledException('An error occurred while retrieving account details. Please contact your administrator.');
        }
        return out;
    }
}
