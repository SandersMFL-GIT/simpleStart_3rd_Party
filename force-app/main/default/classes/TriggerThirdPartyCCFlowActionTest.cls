@isTest
private class TriggerThirdPartyCCFlowActionTest {

    // Util to create dummy Account records
    private static List<Account> createTestAccounts() {
        Account parent = new Account(
            FirstName = 'Parent',
            LastName = 'Account',
            PersonEmail = 'parent@example.com'
        );
        Account thirdParty = new Account(
            FirstName = 'Third',
            LastName = 'Party',
            PersonEmail = 'third@example.com'
        );
        insert new List<Account>{ parent, thirdParty };
        return new List<Account>{ parent, thirdParty };
    }

    @isTest
    static void testTriggerCreditCheck_HappyPath() {
        List<Account> accounts = createTestAccounts();
        TriggerThirdPartyCCFlowAction.CreditCheckInput input = new TriggerThirdPartyCCFlowAction.CreditCheckInput();
        input.parentAccountId = accounts[0].Id;
        input.thirdPartyAccountId = accounts[1].Id;

        Test.startTest();
        List<TriggerThirdPartyCCFlowAction.TriggerCreditCheckResult> results =
            TriggerThirdPartyCCFlowAction.triggerCreditCheck(new List<TriggerThirdPartyCCFlowAction.CreditCheckInput>{input});
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals('Success', results[0].status);
        System.assert(results[0].message.contains('successfully enqueued'));
    }

    @isTest
    static void testTriggerCreditCheck_NullInputList() {
        Test.startTest();
        List<TriggerThirdPartyCCFlowAction.TriggerCreditCheckResult> results =
            TriggerThirdPartyCCFlowAction.triggerCreditCheck(null);
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals('Error', results[0].status);
        System.assertEquals('No input provided.', results[0].message);
    }

    @isTest
    static void testTriggerCreditCheck_EmptyInputList() {
        Test.startTest();
        List<TriggerThirdPartyCCFlowAction.TriggerCreditCheckResult> results =
            TriggerThirdPartyCCFlowAction.triggerCreditCheck(new List<TriggerThirdPartyCCFlowAction.CreditCheckInput>());
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals('Error', results[0].status);
        System.assertEquals('No input provided.', results[0].message);
    }

    @isTest
    static void testTriggerCreditCheck_InvalidInput_MissingIds() {
        TriggerThirdPartyCCFlowAction.CreditCheckInput input = new TriggerThirdPartyCCFlowAction.CreditCheckInput();
        // Both IDs null

        Test.startTest();
        List<TriggerThirdPartyCCFlowAction.TriggerCreditCheckResult> results =
            TriggerThirdPartyCCFlowAction.triggerCreditCheck(new List<TriggerThirdPartyCCFlowAction.CreditCheckInput>{input});
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals('Error', results[0].status);
        System.assert(results[0].message.contains('must be provided'));
    }
}