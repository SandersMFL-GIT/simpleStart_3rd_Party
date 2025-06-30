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
    
    /*if(trigger.isAfter && trigger.isUpdate){
        //AccountTriggerHandler.createClientTimesolv(trigger.new,trigger.oldMap);
        AccountTriggerHandler.createReportisoftpull(trigger.new,trigger.oldMap);
    }*/
}