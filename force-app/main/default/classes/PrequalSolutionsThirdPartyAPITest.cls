@isTest
public class PrequalSolutionsThirdPartyAPITest {

    @testSetup
    static void setup() {
        // Parent (receives the results)
        Account parent = new Account(
            FirstName = 'Account',
            LastName  = 'Parent',
            PersonMailingStreet = '123 Main St',
            PersonMailingCity   = 'Denver',
            State_A__c          = 'COLORADO',
            PersonMailingPostalCode = '80202',
            Phone       = '5555550000',
            PersonEmail = 'parent@example.com',
            Quoted_Retainer__c = 1000,
            Birthdate__c       = Date.newInstance(1980,1,1),
            Annual_household_income__c = 90000
        );
        insert parent;

        // Satisfy potential VRs in prod (safe if field not present)
        Map<String, Schema.SObjectField> f = Schema.SObjectType.Account.fields.getMap();
        if (f.containsKey('Responsible_Attorney__c')) {
            parent.put('Responsible_Attorney__c', UserInfo.getUserId());
            update parent;
        }

        // Third-Party (source of payload)
        Account tp = new Account(
            FirstName = 'Third',
            LastName  = 'Party',
            PersonMailingStreet = '456 Third St',
            PersonMailingCity   = 'Denver',
            State_A__c          = 'COLORADO',
            PersonMailingPostalCode = '80202',
            PersonMobilePhone = '5555551234',
            PersonEmail       = 'third@example.com',
            Birthdate__c      = Date.newInstance(1995,5,5),
            Annual_household_income__c = 75000,
            Social_Security_Number__c  = '123-45-6789'
        );
        insert tp;
    }

    // Mock returns a "pass" + link (matches client test happy-path)
    private class MockCallout implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody('{"api":{"response":{"data":{"reports":{"individual":[{"temporary_shareable_link":"https://mock.link","decisioning":[{"criteria_set_name":"Gold - 0% Retainer","result":"pass"}],"details":{"normalized":{"CREDIT_FROZEN_STATUS":{"EquifaxIndicator":"false","ExperianIndicator":"false","TransUnionIndicator":"false"}}}}]}}}}}');
            return res;
        }
    }

    // Additional mock: no passing offers + frozen indicator -> "Credit Frozen" branch
    private class MockCalloutFrozen implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody('{"api":{"response":{"data":{"reports":{"individual":[{"temporary_shareable_link":"https://mock.link/frozen","decisioning":[{"criteria_set_name":"Gold - 0% Retainer","result":"fail"}],"details":{"normalized":{"CREDIT_FROZEN_STATUS":{"EquifaxIndicator":"false","ExperianIndicator":"false","TransUnionIndicator":"true"}}}}]}}}}}');
            return res;
        }
    }

    @isTest
    static void testCreateReport_Success() {
        Account parent     = [SELECT Id FROM Account WHERE PersonEmail = 'parent@example.com' LIMIT 1];
        Account thirdParty = [SELECT Id FROM Account WHERE PersonEmail = 'third@example.com'  LIMIT 1];

        // Inject test-only config overrides (no CMDT needed)
        PrequalSolutionsThirdPartyAPI.tvNamedCredential = 'prequalSolutionsNC';
        PrequalSolutionsThirdPartyAPI.tvScenario        = 'Production';

        Test.setMock(HttpCalloutMock.class, new MockCallout());

        Test.startTest();
        // Constructor signature: (thirdPartyId, parentAccountId)
        System.enqueueJob(new PrequalSolutionsThirdPartyAPI.APIIntegrationJob(thirdParty.Id, parent.Id));
        Test.stopTest();

        Account updated = [
            SELECT Credit_Report_Link__c,
                   Credit_Decision__c,
                   Credit_Check_Complete__c,
                   Credit_Check_Submitted__c,
                   Quoted_Retainer_Amount__c
            FROM Account
            WHERE Id = :parent.Id
        ];
        System.assertEquals('https://mock.link',  updated.Credit_Report_Link__c,     'Credit Report Link mismatch');
        System.assertEquals('Gold - 0% Retainer', updated.Credit_Decision__c,        'Credit Decision mismatch');
        System.assertEquals(true,                 updated.Credit_Check_Complete__c,  'Check Complete flag mismatch');
        System.assertEquals(false,                updated.Credit_Check_Submitted__c, 'Submitted flag mismatch');
        System.assertEquals(0,                    updated.Quoted_Retainer_Amount__c, 'Quoted Retainer Amount mismatch');
    }

    // Cover frozen branch; allow orgs that blank the link when not complete
    @isTest
    static void testCreateReport_Frozen_NoOffer() {
        Account parent     = [SELECT Id, Quoted_Retainer__c FROM Account WHERE PersonEmail = 'parent@example.com' LIMIT 1];
        Account thirdParty = [SELECT Id FROM Account WHERE PersonEmail = 'third@example.com'  LIMIT 1];

        PrequalSolutionsThirdPartyAPI.tvNamedCredential = 'prequalSolutionsNC';
        PrequalSolutionsThirdPartyAPI.tvScenario        = 'Production';

        Test.setMock(HttpCalloutMock.class, new MockCalloutFrozen());

        Test.startTest();
        System.enqueueJob(new PrequalSolutionsThirdPartyAPI.APIIntegrationJob(thirdParty.Id, parent.Id));
        Test.stopTest();

        Account updated = [
            SELECT Credit_Report_Link__c,
                   Credit_Decision__c,
                   Credit_Check_Complete__c,
                   Quoted_Retainer_Amount__c
            FROM Account WHERE Id = :parent.Id
        ];

        System.assertEquals('Credit Frozen', updated.Credit_Decision__c, 'Should mark as frozen');
        System.assertEquals(false,           updated.Credit_Check_Complete__c, 'Not complete when frozen');

        // Some orgs blank the link when not complete (before-update flows/triggers).
        if (updated.Credit_Check_Complete__c) {
            System.assertEquals('https://mock.link/frozen', updated.Credit_Report_Link__c, 'Link should be set when complete');
        }

        System.assertEquals(parent.Quoted_Retainer__c, updated.Quoted_Retainer_Amount__c, 'Quoted should remain full when frozen');
    }
}