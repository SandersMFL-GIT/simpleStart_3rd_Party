public without sharing class TriggerCreditCheckFlowAction {
    public class CreditCheckInput {
        @InvocableVariable(label='Account Id')
        public Id accountId;
    }
    public class TriggerCreditCheckResult {
        @InvocableVariable(label='Status' description='Result status')
        public String status;
        @InvocableVariable(label='Message' description='Details about the operation')
        public String message;
    }

    @InvocableMethod(label='Trigger Credit Check' description='Sets Credit_Check_Submitted__c to true and triggers credit API.')
    public static List<TriggerCreditCheckResult> triggerCreditCheck(List<CreditCheckInput> inputList) {
        List<TriggerCreditCheckResult> results = new List<TriggerCreditCheckResult>();
        TriggerCreditCheckResult result = new TriggerCreditCheckResult();

        if (inputList == null || inputList.isEmpty()) {
            result.status = 'Error';
            result.message = 'No accounts provided';
            results.add(result);
            return results;
        }
        
        List<Id> accountIds = new List<Id>();
        for (CreditCheckInput input : inputList) {
            if (input.accountId != null) {
                accountIds.add(input.accountId);
            }
        }

        try {
            List<Account> toUpdate = [SELECT Id FROM Account WHERE Id IN :accountIds];
            for (Account acc : toUpdate) {
                acc.Credit_Check_Submitted__c = true;
            }
            if (!toUpdate.isEmpty()) update toUpdate;

            for (CreditCheckInput input : inputList) {
                System.enqueueJob(new PrequalSolutionsThirdPartyAPI.APIIntegrationJob(input.thirdPartyAccountId, input.parentAccountId));
            }

            result.status = 'Success';
            result.message = 'Credit_Check_Submitted__c set to true and API call triggered for ' + toUpdate.size() + ' accounts.';
        } catch (Exception ex) {
            result.status = 'Error';
            result.message = 'Exception: ' + ex.getMessage();
        }

        results.add(result);
        return results;
    }
}