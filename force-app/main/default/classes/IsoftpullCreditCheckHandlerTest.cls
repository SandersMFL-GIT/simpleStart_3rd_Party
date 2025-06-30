/**
 * Tests for IsoftpullCreditCheckHandler.
 */
@isTest(SeeAllData=false)
private class IsoftpullCreditCheckHandlerTest {

    /* ---- helper: map pick-list label → API value ---- */
    private static String apiValue(String label) {
        for (Schema.PicklistEntry pe :
             Account.Credit_Applicant__c.getDescribe().getPicklistValues()) {
            if (pe.getLabel() == label) return pe.getValue();
        }
        System.assert(false, 'Label «' + label + '» not found in pick-list');
        return null; // appease compiler
    }

    /* ---- null / empty list : nothing enqueued ---- */
    @isTest
    static void runWithNullOrEmpty() {
        Test.startTest();
            IsoftpullCreditCheckHandler.run(null);
            System.assertEquals(0, Limits.getQueueableJobs());
            IsoftpullCreditCheckHandler.run(new List<Id>());
            System.assertEquals(0, Limits.getQueueableJobs());
        Test.stopTest();
    }

    /* ---- only Client accounts → 1 job ---- */
    @isTest
    static void runWithClientOnly() {
        Account a = new Account(
            Name                = 'Client',
            Credit_Applicant__c = apiValue('Client')
        );
        insert a;

        Test.startTest();
            IsoftpullCreditCheckHandler.run(new List<Id>{a.Id});
            System.assertEquals(
                1, Limits.getQueueableJobs(),
                'Exactly one Queueable job expected for Client'
            );
        Test.stopTest();
    }

    /* ---- only Third-Party accounts → 1 job ---- */
    @isTest
    static void runWithThirdPartyOnly() {
        Account a = new Account(
            Name                = '3P',
            Credit_Applicant__c = apiValue('Third Party')
        );
        insert a;

        Test.startTest();
            IsoftpullCreditCheckHandler.run(new List<Id>{a.Id});
            System.assertEquals(
                1, Limits.getQueueableJobs(),
                'Exactly one Queueable job expected for Third-Party'
            );
        Test.stopTest();
    }

    /* ---- mixed list → 2 jobs (Client + Third-Party) ---- */
    @isTest
    static void runWithMixedApplicants() {
        Account client = new Account(
            Name='Client',      Credit_Applicant__c = apiValue('Client')
        );
        Account third  = new Account(
            Name='ThirdParty',  Credit_Applicant__c = apiValue('Third Party')
        );
        insert new List<Account>{ client, third };

        Test.startTest();
            IsoftpullCreditCheckHandler.run(
                new List<Id>{ client.Id, third.Id }
            );
            System.assertEquals(
                2, Limits.getQueueableJobs(),
                'Two Queueable jobs expected for mixed applicants'
            );
        Test.stopTest();
    }
}