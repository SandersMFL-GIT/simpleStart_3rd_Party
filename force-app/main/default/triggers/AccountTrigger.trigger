trigger AccountTrigger on Account (after insert, before insert, before update, after update) {
    if(Trigger.isInsert){
        if(Trigger.isAfter){
            AccountTriggerHandler.execute();
        }        
    }
    
    //Changes made for Fee Agreement
    if(trigger.isBefore){
        if(Trigger.isInsert){
            AccountTriggerHandler.updateEngagementStatusTime(trigger.new);
        }
        if(trigger.isUpdate){
            AccountTriggerHandler.updateEnagagementStatus(trigger.new,trigger.oldMap);
        }
    }
    
    // ─── AFTER UPDATE: only the Isoftpull branch with per-record debug ─────────
if (Trigger.isAfter && Trigger.isUpdate) {
    System.debug(LoggingLevel.INFO, '>>> ISOFTPULL AFTER UPDATE fired for ' + Trigger.new.size() + ' records');
    List<Account> newList     = Trigger.new;
    Map<Id, Account> oldMap   = Trigger.oldMap;
    
    // Per-record diagnostics
    for (Account acc : newList) {
        Account oldAcc = oldMap.get(acc.Id);
        System.debug(LoggingLevel.DEBUG, '---- Record Id=' + acc.Id + ' ----');
        System.debug(LoggingLevel.DEBUG, 'Credit_Check_Submitted__c: old='
            + oldAcc.Credit_Check_Submitted__c + ', new=' + acc.Credit_Check_Submitted__c);
        System.debug(LoggingLevel.DEBUG, 'FirstName: old='
            + oldAcc.FirstName + ', new=' + acc.FirstName);
        System.debug(LoggingLevel.DEBUG, 'LastName: old='
            + oldAcc.LastName + ', new=' + acc.LastName);
        System.debug(LoggingLevel.DEBUG, 'PersonMailingStreet: old='
            + oldAcc.PersonMailingStreet + ', new=' + acc.PersonMailingStreet);
        System.debug(LoggingLevel.DEBUG, 'PersonMailingCity: old='
            + oldAcc.PersonMailingCity + ', new=' + acc.PersonMailingCity);
        System.debug(LoggingLevel.DEBUG, 'State_A__c: old='
            + oldAcc.State_A__c + ', new=' + acc.State_A__c);
        System.debug(LoggingLevel.DEBUG, 'PersonMailingPostalCode: old='
            + oldAcc.PersonMailingPostalCode + ', new=' + acc.PersonMailingPostalCode);
    }
    
    
    AccountTriggerHandler.createReportisoftpull(newList, oldMap);
}

}