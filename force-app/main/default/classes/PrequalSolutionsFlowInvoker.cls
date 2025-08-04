public class PrequalSolutionsFlowInvoker {

    public class Input {
        @InvocableVariable(label='Account Id')
        public Id accountId;

        @InvocableVariable(label='Is Third Party')
        public Boolean isThirdParty;
    }

    @InvocableMethod(label='Run Prequal Solutions Credit Check' description='Runs the Prequal Solutions API integration for the given Account')
    public static void runPrequalSolutionsCheck(List<Input> inputList) {
        // Null check for inputList itself
        if (inputList == null || inputList.isEmpty()) {
            System.debug('PrequalSolutionsFlowInvoker: No input records provided.');
            return;
        }

        for (Input inp : inputList) {
            // Null check for each Input object
            if (inp == null) {
                System.debug('PrequalSolutionsFlowInvoker: Null input record encountered, skipping.');
                continue;
            }

            // Null check for Account Id
            if (inp.accountId == null) {
                System.debug('PrequalSolutionsFlowInvoker: Null AccountId for input record, skipping.');
                continue;
            }

            try {
                // Use the new API integration logic here
                if (inp.isThirdParty == true) {
                    PrequalSolutionsAPIIntegration.createReportForThirdParty(new List<Id>{inp.accountId});
                    System.debug('PrequalSolutionsFlowInvoker: Enqueued credit check for Third Party for AccountId: ' + inp.accountId);
                } else {
                    PrequalSolutionsAPIIntegration.createReport(new List<Id>{inp.accountId});
                    System.debug('PrequalSolutionsFlowInvoker: Enqueued credit check for PC for AccountId: ' + inp.accountId);
                }
            } catch (Exception ex) {
                // Log error or handle as needed
                System.debug('Error running Prequal Solutions check for AccountId ' + inp.accountId + ': ' + ex.getMessage());
            }
        }
    }
}