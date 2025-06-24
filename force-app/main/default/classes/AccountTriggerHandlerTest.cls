@isTest
public class AccountTriggerHandlerTest {
    
    
    @testSetup
    private static void doTestDataSetup(){
        //RecordType trainingRecId =  [SELECT Id FROM RecordType WHERE Name = 'Training' and SObjectType = 'Account'];
        Account trainingAcc = new Account();
        trainingAcc.FirstName = 'Test Account';
        trainingAcc.LastName = 'lname';
        //trainingAcc.RecordType = trainingRecId;
        trainingAcc.Hire__c = false;
        insert trainingAcc;
    }
    
    @isTest
    private Static void accTriggerTest(){
        account acc = [select id,LastName from account limit 1];
        acc.lastName = 'testing';
        update acc;
    }
    
    //Added by Ashok
    @isTest
    private Static void updateEngagementStatusTimeTest1(){
        account acc = [select id,Attorney_Follow_up_on_FA__c from account limit 1];
        acc.Attorney_Follow_up_on_FA__c = 'SMS Sent';
        update acc;
    }
    
    //Added by Ashok
    @isTest
    private Static void updateEngagementStatusTimeTest2(){
        account acc = [select id,Attorney_Follow_up_on_FA__c from account limit 1];
        acc.Attorney_Follow_up_on_FA__c = 'Email Sent';
        update acc;
    }
    
    
    //Added by Ashok
    @isTest
    private Static void updateEngagementStatusTimeTest3(){
        account acc = [select id,Attorney_Follow_up_on_FA__c from account limit 1];
        acc.Attorney_Follow_up_on_FA__c = 'Left Voicemail';
        update acc;
    }
    
    //Added by Ashok
    @isTest
    private Static void updateEngagementStatusTimeTest4(){
        account acc = [select id,Attorney_Follow_up_on_FA__c from account limit 1];
        acc.Attorney_Follow_up_on_FA__c = 'Waiting for Payment';
        update acc;
    }
    
    //Added by Ashok
    @isTest
    private Static void updateEngagementStatusTimeTest5(){
        account acc = [select id,Attorney_Follow_up_on_FA__c from account limit 1];
        acc.Attorney_Follow_up_on_FA__c = 'Follow up in 3 days';
        update acc;
    }
}