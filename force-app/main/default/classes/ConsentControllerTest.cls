@IsTest(SeeAllData=false)
private class ConsentControllerTest {

    /* ---------- Helpers ---------- */

    private static List<Account> makeClientAndThirdParty() {
        Account client = new Account(LastName = 'Client Tester');
        Account third  = new Account(Name = 'Third Party Tester');
        insert new List<Account>{ client, third };
        return new List<Account>{ client, third };
    }

    private static Consent_Template__c makeActiveTemplate() {
        Consent_Template__c tpl = new Consent_Template__c(
            Version__c = 'v1',
            Consent_Body__c = '<p>Body</p>',
            Is_Active__c = true
        );
        insert tpl;
        return tpl;
    }

    /* ---------- Tests ---------- */

    @IsTest
    static void getActiveTemplate_noActive_throws() {
       
        Test.startTest();
        Boolean thrown = false;
        try {
            ConsentController.getActiveTemplate();
        } catch (AuraHandledException e) {
            thrown = true; 
        }
        Test.stopTest();
        System.assert(thrown, 'Expected AuraHandledException when no active template exists.');
    }

    @IsTest
    static void saveConsentWithSnapshot_happyPath() {
        List<Account> accs = makeClientAndThirdParty();
        Account client = accs[0];
        Account third  = accs[1];

       
        makeActiveTemplate();

        Test.startTest();
        Id evId = ConsentController.saveConsentWithSnapshot(
            client.Id,
            'v1',
            '<p>Snapshot</p>',
            true,  // acceptedDisclosures
            true,  // acceptedTerms
            true,  // acceptedFCRA
            third.Id
        );
        Test.stopTest();

        Consent_Event__c ev = [
            SELECT Account__c, Consent_Version__c, Third_Party_Name__c,
                   Electronic_Disclosures__c, Terms_Accepted__c, FCRA_Written_Instructions__c,
                   Consent_Body_Snapshot__c, Agreed_Timestamp__c
            FROM Consent_Event__c
            WHERE Id = :evId
        ];
        System.assertEquals(client.Id, ev.Account__c);
        System.assertEquals('v1', ev.Consent_Version__c);
        System.assertEquals('Third Party Tester', ev.Third_Party_Name__c);
        System.assertEquals(true, ev.Electronic_Disclosures__c);
        System.assertEquals(true, ev.Terms_Accepted__c);
        System.assertEquals(true, ev.FCRA_Written_Instructions__c);
        System.assertEquals('<p>Snapshot</p>', ev.Consent_Body_Snapshot__c);
        System.assertNotEquals(null, ev.Agreed_Timestamp__c);
    }

    @IsTest
    static void saveConsentWithSnapshot_blankVersion_throws() {
        List<Account> accs = makeClientAndThirdParty();
        Account client = accs[0];
        Account third  = accs[1];

        Test.startTest();
        Boolean thrown = false;
        try {
            ConsentController.saveConsentWithSnapshot(
                client.Id,
                '',                 
                '<p>Snapshot</p>',
                true, true, true,
                third.Id
            );
        } catch (AuraHandledException e) {
            thrown = true; 
        }
        Test.stopTest();
        System.assert(thrown, 'Expected AuraHandledException for blank version.');
    }
}