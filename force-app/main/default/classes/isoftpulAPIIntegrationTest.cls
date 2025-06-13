@IsTest
public class isoftpulAPIIntegrationTest {

    @IsTest
    static void testCreateReport() {
        // Create a test account
        Account testAccount = new Account(
            FirstName = 'John',
            LastName = 'Doe',
            PersonMailingStreet = '123 Test St',
            PersonMailingCity = 'Test City',
            PersonMailingState = 'CA',
            PersonMailingPostalCode = '12345',
            Responsible_Attorney__c = UserInfo.getUserId()
        );
        insert testAccount;
        
        isoftpulAPIIntegration.ResponseDataWrapper req = new isoftpulAPIIntegration.ResponseDataWrapper();
        isoftpulAPIIntegration.Applicant areq = new isoftpulAPIIntegration.applicant();
        areq.first_name = 'test';
        areq.last_name = 'test';
        areq.address = 'test';
        areq.city = 'trst';
        areq.email = 'test@gmail.com';
        areq.middle_name = 'test';
        areq.state = 'test';
        areq.zip = '12345';
        areq.date_of_birth = 'test';
        areq.ssn = 'test';
        req.applicant = areq;
        
        // Mock the HTTP response
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new isoftpulAPIIntegrationMock());
        
        // Call the method to test
        List<Id> accountIds = new List<Id>{testAccount.Id};
        isoftpulAPIIntegration.createReport(accountIds);
        isoftpulAPIIntegration.createReportForThirdParty(accountIds);
        Test.stopTest();
        
        // Assertions for primary report
        Account updatedAccount = [SELECT Credit_Decision__c, Credit_Check_Complete__c, Credit_Report_Link__c 
                                  FROM Account WHERE Id = :testAccount.Id];
        System.assertNotEquals(null, updatedAccount.Credit_Report_Link__c, 'Credit Report Link should be updated.');
        System.assertEquals('Full Retainer', updatedAccount.Credit_Decision__c, 'Credit Decision should match the mocked response.');
        System.assertEquals(true, updatedAccount.Credit_Check_Complete__c, 'Credit Check should be complete.');

        // Assertions for failures (Equifax, TransUnion, Experian)
        String failureStatuses = 'Equifax: failure\nTransUnion: failure\nExperian: failure\n';
        String failureMessages = 'Equifax: Service Unavailable.\nTransUnion: TransUnion service unavailable.\nExperian: Experian service unavailable.\n';
        String failureTypes = 'Equifax: error\nTransUnion: error\nExperian: error\n';

        System.assertEquals('Equifax: failure\nTransUnion: failure\nExperian: failure\n', failureStatuses, 'Failure statuses do not match.');
        System.assertEquals('Equifax: Service Unavailable.\nTransUnion: TransUnion service unavailable.\nExperian: Experian service unavailable.\n', failureMessages, 'Failure messages do not match.');
        System.assertEquals('Equifax: error\nTransUnion: error\nExperian: error\n', failureTypes, 'Failure types do not match.');
    }

    @IsTest
    static void testTriggerHandler() {
        // Create test accounts for trigger logic
        Account clientAccount = new Account(
            FirstName = 'Client',
            LastName = 'Test',
            PersonMailingStreet = '123 Client St',
            PersonMailingCity = 'Client City',
            PersonMailingState = 'CA',
            PersonMailingPostalCode = '12345',
            Responsible_Attorney__c = UserInfo.getUserId(),
            Credit_Check_Submitted__c = false,
            Credit_Applicant__c = 'Client',
            Credit_Decision__c='Full Retainer',
            Send_Credit_Request__c=true
        );

        Account thirdPartyAccount = new Account(
            FirstName = 'Third',
            LastName = 'Party',
            PersonMailingStreet = '456 Third St',
            PersonMailingCity = 'Third City',
            PersonMailingState = 'NY',
            PersonMailingPostalCode = '67890',
            Responsible_Attorney__c = UserInfo.getUserId(),
            Credit_Check_Submitted__c = false,
            Credit_Applicant__c = 'Third Party',
            Credit_Decision__c=' Full Retainer ',
            Send_Credit_Request__c=true
        );

        insert new List<Account>{clientAccount, thirdPartyAccount};

        // Update accounts to trigger the handler logic
        clientAccount.Credit_Check_Submitted__c = true;
        thirdPartyAccount.Credit_Check_Submitted__c = true;

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new isoftpulAPIIntegrationMock());
        update new List<Account>{clientAccount, thirdPartyAccount};
        Test.stopTest();

        // Assertions for Client account
        Account updatedClientAccount = [SELECT Credit_Check_Submitted__c, Credit_Decision__c , Send_Credit_Request__c
                                        FROM Account WHERE Id = :clientAccount.Id];
        System.assertEquals(false, updatedClientAccount.Credit_Check_Submitted__c, 'Credit Check Submitted should be false after processing.');
        System.assertEquals('Full Retainer', updatedClientAccount.Credit_Decision__c, 'Client Credit Decision should match.');
        System.assertEquals(true, updatedClientAccount.Send_Credit_Request__c, 'Send Credit Request should be true.');

        // Assertions for Third-Party account
        Account updatedThirdPartyAccount = [SELECT Credit_Check_Submitted__c, Credit_Decision__c ,Send_Credit_Request__c
                                            FROM Account WHERE Id = :thirdPartyAccount.Id];
        System.assertEquals(false, updatedThirdPartyAccount.Credit_Check_Submitted__c, 'Credit Check Submitted should be false after processing.');
        System.assertEquals('Full Retainer', updatedThirdPartyAccount.Credit_Decision__c, 'Third-Party Credit Decision should match.');
        System.assertEquals(true, updatedThirdPartyAccount.Send_Credit_Request__c, 'Send Credit Request should be true.');
    }
    
    // Mock class for successful HTTP response
    public class isoftpulAPIIntegrationMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            
            // Mock response with intelligence.result = 'No offers matched'
            String responseBody = '{"reports": {"link":"https://app.isoftpull.com/client/applicants/view_only/123/soft_pull", '
                + '"equifax": {"status":"failure", "message":"Service Unavailable.", "failure_type":"error"}, '
                + '"transunion": {"status":"failure", "message":"TransUnion service unavailable.", "failure_type":"error"}, '
                + '"experian": {"status":"failure", "message":"Experian service unavailable.", "failure_type":"error"}}, '
                + '"credit_check_complete": true, '
                + '"intelligence": {"result":"No offers matched", "name":"Loan Silver"}}';
            res.setBody(responseBody);
            res.setStatusCode(200);
            return res;
        }
    }
}