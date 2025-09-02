@isTest
private class CustomThirdPartyControllerTest {

    @testSetup
    static void setup() {
        // Create a RecordType for testing if needed
        if (Schema.SObjectType.Account.getRecordTypeInfosByName().containsKey('Third_Party')) {
            // already exists
            return;
        }
        
        // Otherwise, you can create logic to insert a test RecordType if necessary for the org
        // Skipping that here, assuming you're using Person Accounts
    }

    @isTest
    static void testCreateThirdPartyAccountSimple() {
        Map<String, Object> accountData = new Map<String, Object>{
            'FirstName' => 'John',
            'LastName' => 'Doe',
            'MiddleName' => 'X',
            'Social_Security_Number__c' => '123456789',
            'PersonMobilePhone' => '1234567890',
            'PersonEmail' => 'john.doe@example.com',
            'PersonMailingStreet' => '123 Test St',
            'PersonMailingCity' => 'Denver',
            'State_A__c' => 'COLORADO',
            'PersonMailingPostalCode' => '80202',
            'Birthdate__c' => '1980-01-01',
            'Annual_household_income__c' => '95000.00',
            'Type' => 'Third Party' // skip RecordType assignment
        };

        Test.startTest();
        String newAccountId = CustomThirdPartyController.createThirdPartyAccountSimple(accountData);
        Test.stopTest();

        System.assertNotEquals(null, newAccountId, 'Account ID should not be null');

        Account created = [SELECT FirstName, LastName, Type FROM Account WHERE Id = :newAccountId];
        System.assertEquals('John', created.FirstName);
        System.assertEquals('Doe', created.LastName);
        System.assertEquals('Third Party', created.Type);
    }

    @isTest
    static void testGetCreditDecision() {
        Account testAcc = new Account(
            FirstName = 'Jane',
            LastName = 'Smith',
            PersonEmail = 'jane@example.com',
            Type = 'Third Party',
            Credit_Decision__c = 'Bronze - 80% Retainer'
        );
        insert testAcc;

        Test.startTest();
        String decision = CustomThirdPartyController.getCreditDecision(testAcc.Id);
        Test.stopTest();

        System.assertEquals('Bronze - 80% Retainer', decision);
    }

    @isTest
    static void testGetCreditDecision_NullId() {
        Test.startTest();
        String decision = CustomThirdPartyController.getCreditDecision(null);
        Test.stopTest();

        System.assertEquals(null, decision);
    }

    @isTest
    static void testGetAccountForGuestUser() {
        Account acc = new Account(
            FirstName = 'Guest',
            LastName = 'User',
            Type = 'Third Party',
            PersonEmail = 'guest@example.com',
            Credit_Decision__c = 'Full Retainer'
        );
        insert acc;

        Test.startTest();
        List<Account> result = CustomThirdPartyController.getAccountForGuestUser(new List<String>{acc.Id});
        Test.stopTest();

        System.assertEquals(1, result.size());
        System.assertEquals(acc.Id, result[0].Id);
    }

   @isTest
static void testGetAccountForGuestUser_NoId() {
    Test.startTest();
    Boolean exceptionThrown = false;
    try {
        CustomThirdPartyController.getAccountForGuestUser(new List<String>());
    } catch (AuraHandledException e) {
        exceptionThrown = true;
    }
    Test.stopTest();
    System.assert(exceptionThrown, 'Expected AuraHandledException to be thrown');
}



    @isTest
    static void testGetParentAccountId18_Valid15Char() {
        String id15 = UserInfo.getUserId().substring(0, 15);
        Test.startTest();
        String id18 = CustomThirdPartyController.getParentAccountId18(id15);
        Test.stopTest();

        System.assertEquals(UserInfo.getUserId(), id18);
    }

   @isTest
static void testGetParentAccountId18_InvalidId() {
    Test.startTest();
    Boolean exceptionThrown = false;
    try {
        CustomThirdPartyController.getParentAccountId18('123BADID');
    } catch (AuraHandledException e) {
        exceptionThrown = true;
    }
    Test.stopTest();
    System.assert(exceptionThrown, 'Expected AuraHandledException to be thrown');
}


}
