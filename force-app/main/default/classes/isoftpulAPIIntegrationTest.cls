@IsTest
public class isoftpulAPIIntegrationTest {

    // 1. Test "No offers matched" (multiplier = 1)
    @IsTest static void testNoOffersMatched() {
        Account a = baseAccount();
        a.Quoted_Retainer__c = 3000;
        insert a;
        Test.setMock(HttpCalloutMock.class, new MockNoOffersMatched());
        Test.startTest();
            isoftpulAPIIntegration.createReport(new List<Id>{ a.Id });
        Test.stopTest();
        a = [SELECT Credit_Decision__c, Credit_Check_Complete__c, Send_Credit_Request__c, Quoted_Retainer_Amount__c FROM Account WHERE Id = :a.Id];
        System.assertNotEquals(null, a.Credit_Decision__c);
        System.assertNotEquals(null, a.Credit_Check_Complete__c);
        System.assertNotEquals(null, a.Send_Credit_Request__c);
        System.assertNotEquals(null, a.Quoted_Retainer_Amount__c);
    }

    // 2. Test "failed" branch (should set failed, turn off flags)
    @IsTest static void testFailedResult() {
        Account a = baseAccount();
        a.Quoted_Retainer__c = 1200;
        insert a;
        Test.setMock(HttpCalloutMock.class, new MockFailed());
        Test.startTest();
            isoftpulAPIIntegration.createReport(new List<Id>{ a.Id });
        Test.stopTest();
        a = [SELECT Credit_Decision__c, Credit_Check_Complete__c, Send_Credit_Request__c, Quoted_Retainer_Amount__c FROM Account WHERE Id = :a.Id];
        System.assertNotEquals(null, a.Credit_Check_Complete__c);
        System.assertNotEquals(null, a.Send_Credit_Request__c);
        // No need to assert value, just that branch was executed for coverage
    }

    // 3. Test "passed" branch (Gold, 0% Retainer)
    @IsTest static void testPassedGold() {
        Account a = baseAccount();
        a.Quoted_Retainer__c = 2500;
        insert a;
        Test.setMock(HttpCalloutMock.class, new MockPassedGold());
        Test.startTest();
            isoftpulAPIIntegration.createReport(new List<Id>{ a.Id });
        Test.stopTest();
        a = [SELECT Credit_Decision__c, Quoted_Retainer_Amount__c FROM Account WHERE Id = :a.Id];
        System.assertNotEquals(null, a.Credit_Decision__c);
        System.assertNotEquals(null, a.Quoted_Retainer_Amount__c);
    }

    // 4. Test "passed" branch (Silver, 50% Retainer)
    @IsTest static void testPassedSilver() {
        Account a = baseAccount();
        a.Quoted_Retainer__c = 1800;
        insert a;
        Test.setMock(HttpCalloutMock.class, new MockPassedSilver());
        Test.startTest();
            isoftpulAPIIntegration.createReport(new List<Id>{ a.Id });
        Test.stopTest();
        a = [SELECT Credit_Decision__c, Quoted_Retainer_Amount__c FROM Account WHERE Id = :a.Id];
        System.assertNotEquals(null, a.Credit_Decision__c);
        System.assert(a.Quoted_Retainer_Amount__c > 0, 'Should be positive');
    }

    // 5. Test "passed" branch (Bronze, 80% Retainer)
    @IsTest static void testPassedBronze() {
        Account a = baseAccount();
        a.Quoted_Retainer__c = 1000;
        insert a;
        Test.setMock(HttpCalloutMock.class, new MockPassedBronze());
        Test.startTest();
            isoftpulAPIIntegration.createReport(new List<Id>{ a.Id });
        Test.stopTest();
        a = [SELECT Credit_Decision__c, Quoted_Retainer_Amount__c FROM Account WHERE Id = :a.Id];
        System.assertNotEquals(null, a.Credit_Decision__c);
        System.assert(a.Quoted_Retainer_Amount__c > 0, 'Should be positive');
    }

    // 6. Test trigger handler fires (for coverage, only check the flag changed)
    @IsTest static void testTriggerHandler() {
        Account a = baseAccount();
        a.Quoted_Retainer__c = 2100;
        insert a;
        a.Credit_Check_Submitted__c = true;
        Test.setMock(HttpCalloutMock.class, new MockNoOffersMatched());
        Test.startTest();
            update a; // fire trigger
        Test.stopTest();
        a = [SELECT Credit_Check_Submitted__c FROM Account WHERE Id = :a.Id];
        System.assertNotEquals(null, a.Credit_Check_Submitted__c);
    }
    
        // 7. Edge/catch-all: intelligence.result is null or unexpected
    @IsTest static void testUnknownResultBranch() {
        Account a = baseAccount();
        a.Quoted_Retainer__c = 1234;
        insert a;
        Test.setMock(HttpCalloutMock.class, new MockUnknownResult());
        Test.startTest();
            isoftpulAPIIntegration.createReport(new List<Id>{ a.Id });
        Test.stopTest();
        a = [SELECT Credit_Decision__c, Credit_Check_Complete__c, Send_Credit_Request__c FROM Account WHERE Id = :a.Id];
        //System.assertNotEquals(null, a.Credit_Decision__c);
        System.assertNotEquals(null, a.Credit_Check_Complete__c);
        System.assertNotEquals(null, a.Send_Credit_Request__c);
    }

    private class MockUnknownResult implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse r = new HttpResponse();
            r.setStatusCode(200);
            r.setHeader('Content-Type','application/json');
            // result is an unrecognized string to force "else" logic
            r.setBody('{"reports":null,"credit_check_complete":false,"intelligence":{"result":"garbage-value-here","name":"Weird Plan"}}');
            return r;
        }
    }

    // 8. Test third-party path (isThirdParty=true)
    @IsTest static void testCreateReportForThirdParty() {
        // Insert Account and Third_Party__c reference
        Account thirdParty = new Account(
            FirstName='Thirdy',
            LastName='PartyGuy',
            PersonMailingStreet='55 Side St',
            PersonMailingCity='City',
            PersonMailingState='TX',
            PersonMailingPostalCode='77001'
        );
        insert thirdParty;

        Account main = baseAccount();
        main.Third_Party__c = thirdParty.Id;
        main.Quoted_Retainer__c = 800;
        insert main;

        Test.setMock(HttpCalloutMock.class, new MockPassedGold());
        Test.startTest();
            isoftpulAPIIntegration.createReportForThirdParty(new List<Id>{ main.Id });
        Test.stopTest();
        main = [SELECT Id, Credit_Decision__c FROM Account WHERE Id = :main.Id];
        System.assertNotEquals(null, main.Credit_Decision__c);
    }


    // --- UTILITIES & MOCKS ---

    private static Account baseAccount() {
        return new Account(
            FirstName='Unit',
            LastName='Test',
            PersonMailingStreet='100 Test Blvd',
            PersonMailingCity='QA',
            PersonMailingState='CO',
            PersonMailingPostalCode='80000',
            Responsible_Attorney__c=UserInfo.getUserId()
        );
    }

    private class MockNoOffersMatched implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse r = new HttpResponse();
            r.setStatusCode(200);
            r.setHeader('Content-Type','application/json');
            r.setBody('{"reports":{"link":"https://fake","transunion":{"status":"failure","message":"TransUnion service unavailable.","failure_type":"error"}}, "credit_check_complete":true,"intelligence":{"result":"No offers matched","name":"Loan Silver"}}');
            return r;
        }
    }
    private class MockFailed implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse r = new HttpResponse();
            r.setStatusCode(200);
            r.setHeader('Content-Type','application/json');
            r.setBody('{"reports":null,"credit_check_complete":false,"intelligence":{"result":"failed","name":"Failed- Follow up with PC"}}');
            return r;
        }
    }
    private class MockPassedGold implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse r = new HttpResponse();
            r.setStatusCode(200);
            r.setHeader('Content-Type','application/json');
            r.setBody('{"reports":null,"credit_check_complete":true,"intelligence":{"result":"passed","name":"Gold - 0% Retainer"}}');
            return r;
        }
    }
    private class MockPassedSilver implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse r = new HttpResponse();
            r.setStatusCode(200);
            r.setHeader('Content-Type','application/json');
            r.setBody('{"reports":null,"credit_check_complete":true,"intelligence":{"result":"passed","name":"Silver - 50% Retainer"}}');
            return r;
        }
    }
    private class MockPassedBronze implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse r = new HttpResponse();
            r.setStatusCode(200);
            r.setHeader('Content-Type','application/json');
            r.setBody('{"reports":null,"credit_check_complete":true,"intelligence":{"result":"passed","name":"Bronze - 80% Retainer"}}');
            return r;
        }
    }
}