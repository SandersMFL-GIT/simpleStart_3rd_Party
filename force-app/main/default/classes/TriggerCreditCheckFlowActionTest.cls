@isTest
public class TriggerCreditCheckFlowActionTest {
    @testSetup
    static void setup() {
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 2; i++) {
            accounts.add(new Account(
                LastName = 'TestUser' + i 
            ));
        }
        insert accounts;
    }

    @isTest
    static void testTriggerCreditCheck_Success() {
        List<Account> accs = [SELECT Id FROM Account LIMIT 2];

        List<TriggerCreditCheckFlowAction.CreditCheckInput> inputList = new List<TriggerCreditCheckFlowAction.CreditCheckInput>();
        for (Account acc : accs) {
            TriggerCreditCheckFlowAction.CreditCheckInput input = new TriggerCreditCheckFlowAction.CreditCheckInput();
            input.accountId = acc.Id;
            inputList.add(input);
        }

        // Mock the API integration class
        Test.startTest();
        List<TriggerCreditCheckFlowAction.TriggerCreditCheckResult> results =
            TriggerCreditCheckFlowAction.triggerCreditCheck(inputList);
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals('Success', results[0].status);

        // Check Account update
        for (Account acc : [SELECT Credit_Check_Submitted__c FROM Account WHERE Id IN :accs]) {
            System.assertEquals(true, acc.Credit_Check_Submitted__c);
        }
    }

    @isTest
    static void testTriggerCreditCheck_EmptyInput() {
        List<TriggerCreditCheckFlowAction.TriggerCreditCheckResult> results =
            TriggerCreditCheckFlowAction.triggerCreditCheck(new List<TriggerCreditCheckFlowAction.CreditCheckInput>());
        System.assertEquals(1, results.size());
        System.assertEquals('Error', results[0].status);
    }
}