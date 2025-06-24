trigger AccountCreditCheckTrigger on Account (after update) {
    // 1) Use a Set to collect unique Account IDs
    Set<Id> toProcess = new Set<Id>();
    
    for (Account a : Trigger.new) {
        Account oldA = Trigger.oldMap.get(a.Id);
        // only when the checkbox flips false→true
        if (a.Credit_Check_Submitted__c && !oldA.Credit_Check_Submitted__c) {
            toProcess.add(a.Id);
        }
    }
    
    // 2) Call handler with a List constructed from that Set
    if (!toProcess.isEmpty()) {
        IsoftpullCreditCheckHandler.run(new List<Id>(toProcess));
    }
}