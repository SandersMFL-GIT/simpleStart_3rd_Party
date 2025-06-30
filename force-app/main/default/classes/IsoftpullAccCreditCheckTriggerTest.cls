/**
 * Test class for IsoftpullAccCreditCheckTrigger.
 */
@isTest(SeeAllData=false)
private class IsoftpullAccCreditCheckTriggerTest {

    /**
     * Verifies that when Credit_Check_Submitted__c flips from false to true,
     * the trigger fires and the field is updated.
     */
    @isTest
    static void testHandlerInvokedOnCheckboxFlip() {
        // Create test Account with checkbox false
        Account acct = new Account(
            Name = 'Test Account',
            Credit_Check_Submitted__c = false
        );
        insert acct;

        // Flip checkbox from false→true
        acct.Credit_Check_Submitted__c = true;
        Test.startTest();
            update acct;
        Test.stopTest();

        // Confirm the update went through
        Account updated = [
            SELECT Credit_Check_Submitted__c
            FROM Account
            WHERE Id = :acct.Id
        ];
        System.assert(
            updated.Credit_Check_Submitted__c,
            'Credit_Check_Submitted__c should be true after update'
        );
    }

    /**
     * Verifies that when no flip occurs (checkbox stays false),
     * the trigger does not alter that checkbox.
     */
    @isTest
    static void testNoInvocationWhenNotFlipped() {
        // Create test Account with checkbox false
        Account acct = new Account(
            Name = 'No Flip Account',
            Credit_Check_Submitted__c = false
        );
        insert acct;

        // Update a different field only
        acct.Name = 'No Flip Account Updated';
        Test.startTest();
            update acct;
        Test.stopTest();

        // Confirm name updated but checkbox remains false
        Account updated = [
            SELECT Name, Credit_Check_Submitted__c
            FROM Account
            WHERE Id = :acct.Id
        ];
        System.assertEquals(
            'No Flip Account Updated',
            updated.Name,
            'Account name should update even when checkbox stays false'
        );
        System.assert(
            !updated.Credit_Check_Submitted__c,
            'Credit_Check_Submitted__c should remain false'
        );
    }
}