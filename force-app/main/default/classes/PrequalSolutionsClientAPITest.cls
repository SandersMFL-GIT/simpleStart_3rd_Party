@isTest
public class PrequalSolutionsClientAPITest {
    @testSetup
    static void setup() {
        Account acc = new Account(
            LastName = 'API Test',
            FirstName = 'Test',
            PersonMailingStreet = '123 Test St',
            PersonMailingCity = 'TestCity',
            State_A__c = 'TEXAS',
            PersonMailingPostalCode = '75001',
            Phone = '1234567890',
            PersonEmail = 'test@example.com',
            Quoted_Retainer__c = 1000,
            Birthdate__c = Date.newInstance(2000, 1, 1),
            Annual_household_income__c = 100000,
            Social_Security_Number__c = '123-45-6789'
        );
       
        insert acc;
    }

    private class MockCallout implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody(
                '{"api":{"response":{"data":{"reports":{"individual":[{"temporary_shareable_link":"https://mock.link","decisioning":[{"criteria_set_name":"Gold - 0% Retainer","result":"pass"}],"details":{"normalized":{"CREDIT_FROZEN_STATUS":{"EquifaxIndicator":"false","ExperianIndicator":"false","TransUnionIndicator":"false"}}}}]}}}}}'
            );
            return res;
        }
    }

    @isTest
    static void testCreateReport_Success() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        List<Id> accountIds = new List<Id>{acc.Id};

        Test.setMock(HttpCalloutMock.class, new MockCallout());

        Test.startTest();
        PrequalSolutionsClientAPI.createReport(accountIds);
        Test.stopTest();

        Account updated = [
            SELECT Credit_Report_Link__c, Credit_Decision__c, Credit_Check_Complete__c, Credit_Check_Submitted__c, Quoted_Retainer_Amount__c
            FROM Account WHERE Id = :acc.Id
        ];
        System.assertEquals('https://mock.link', updated.Credit_Report_Link__c, 'Credit Report Link mismatch');
        System.assertEquals('Gold - 0% Retainer', updated.Credit_Decision__c, 'Credit Decision mismatch');
        System.assertEquals(true, updated.Credit_Check_Complete__c, 'Check Complete flag mismatch');
        System.assertEquals(false, updated.Credit_Check_Submitted__c, 'Submitted flag mismatch');
        System.assertEquals(0, updated.Quoted_Retainer_Amount__c, 'Quoted Retainer Amount mismatch');
    }
}