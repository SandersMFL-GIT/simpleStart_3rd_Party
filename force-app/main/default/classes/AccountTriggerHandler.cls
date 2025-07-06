public inherited sharing class AccountTriggerHandler {
    public static void execute(){
        generateAccountRecordsToShare();
    }
    
    private static void generateAccountRecordsToShare(){
        List<id> accountId = new List<Id>();
        
        for(Account acct : (List<Account>)Trigger.new){
            accountId.add(acct.Id);
        }
        
        if(!accountId.isEmpty()){
            MattersTriggerHandler.createObjectShareListContext('Account', accountId); 
        }
    }
    
    
    //Changes made for Fee Agreement
    public static void updateEngagementStatusTime(List<account> accounts){
        
        for(account acc: accounts){
            List<string> engagementStatus = new List<string>();
            if(acc.Attorney_Follow_up_on_FA__c != null && acc.Attorney_Follow_up_on_FA__c != ''){
                engagementStatus = acc.Attorney_Follow_up_on_FA__c.split(';');            
                if(engagementStatus.contains('SMS Sent')){
                    acc.Sent_Follow_Up_Text_Message_Time__c = system.now();
                }
                if(engagementStatus.contains('Email Sent')){
                    acc.Sent_Follow_Up_Email_Time__c = system.now();
                }
                if(engagementStatus.contains('Left Voicemail')){
                    acc.Called_and_Left_Voicemail_Time__c = system.now();
                }
                if(engagementStatus.contains('Waiting for Payment')){
                    acc.Waiting_for_Payment_Time__c = system.now();
                }
                if(engagementStatus.contains('Follow up in 3 days')){
                    acc.Setting_a_follow_up_in_3_days_Time__c = system.now();
                }
            }
        }
    }
    
    //Changes made for Fee Agreement
    public static void updateEnagagementStatus(List<account> newAccounts, Map<id, account> oldMapAccounts){
        List<account> accList = new List<account>();
        for(account acc: newAccounts){
            if(acc.Attorney_Follow_up_on_FA__c != oldMapAccounts.get(acc.id).Attorney_Follow_up_on_FA__c){
                accList.add(acc);
            }
        }
        updateEngagementStatusTime(accList);
    }
    
    /*public static void createClientTimesolv(List<account> newAccounts, Map<id, account> oldMapAccounts){
        List<Id> accIds = new List<id>();
        for(Account acc : newAccounts){
            if(acc.Hire__c==true && oldMapAccounts.get(acc.id).Hire__c==false){
               accIds.add(acc.Id);
            }
        }
        
        if(accIds.size()>0){
            timesolvIntegrationClientCall.createClient(accIds);
        }
    }*/
    
   /* public static void createReportisoftpull(List<Account> newAccounts, Map<Id, Account> oldMapAccounts) {
    // Separate lists to track Client and Third-Party account IDs
    List<Id> accIds = new List<Id>();
    List<Id> accThirdPartyIds = new List<Id>();

    // Iterate over the accounts and segregate based on conditions
    for (Account acc : newAccounts) {
        Account oldAccount = oldMapAccounts.get(acc.Id);

        // Check if Credit Check is submitted and the field value has changed
        if (acc.Credit_Check_Submitted__c == true &&
            oldAccount.Credit_Check_Submitted__c != acc.Credit_Check_Submitted__c) {

            // Segregate based on the Credit Applicant type
            if (acc.Credit_Applicant__c == 'Client') {
                accIds.add(acc.Id);
            } else if (acc.Credit_Applicant__c == 'Third Party') {
                accThirdPartyIds.add(acc.Id);
            }
        }
    }

    // Call the appropriate methods if there are valid IDs
    if (!accIds.isEmpty()) {
        System.debug('Triggering createReport for Client accounts: ' + accIds);
        isoftpulAPIIntegration.createReport(accIds);
    }

    if (!accThirdPartyIds.isEmpty()) {
        System.debug('Triggering createReportForThirdParty for Third-Party accounts: ' + accThirdPartyIds);
        isoftpulAPIIntegration.createReportForThirdParty(accThirdPartyIds);
    }
}*/

    
}