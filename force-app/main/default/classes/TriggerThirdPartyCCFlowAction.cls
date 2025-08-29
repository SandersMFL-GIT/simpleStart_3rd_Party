/**
 * @description Flow action for triggering third-party credit checks through PrequalSolutions API
 * @author Simple Start Development Team
 * @version 1.0
 */
public without sharing class TriggerThirdPartyCCFlowAction {
    
    /**
     * @description Input parameters for credit check invocation
     */
    public class CreditCheckInput {
        @InvocableVariable(label='Third Party Account Id' required=true)
        public Id thirdPartyAccountId;

        @InvocableVariable(label='Parent Account Id' required=true)
        public Id parentAccountId;
    }

    /**
     * @description Result wrapper for credit check operation
     */
    public class TriggerCreditCheckResult {
        @InvocableVariable(label='Status')  
        public String status;
        
        @InvocableVariable(label='Message') 
        public String message;
    }

    /**
     * @description Invocable method to trigger third-party credit check from Flow
     * @param inputs List of credit check inputs from Flow
     * @return List<TriggerCreditCheckResult> Operation results
     */
    @InvocableMethod(label='Trigger Third-Party Credit Check'
                     description='Initiates third-party credit check via PrequalSolutions API integration')
    public static List<TriggerCreditCheckResult> triggerCreditCheck(List<CreditCheckInput> inputs) {
        System.debug(LoggingLevel.INFO, '==> [Flow Action] Starting: TriggerThirdPartyCCFlowAction');
        List<TriggerCreditCheckResult> results = new List<TriggerCreditCheckResult>();

        if (inputs == null || inputs.isEmpty()) {
            System.debug(LoggingLevel.ERROR, '==> [Flow Action] Error: Input list is null or empty.');
            TriggerCreditCheckResult errorResult = createErrorResult('No input provided.');
            results.add(errorResult);
            return results;
        }

        // Process all inputs (bulk support)
        for (CreditCheckInput input : inputs) {
            System.debug(LoggingLevel.INFO, '==> [Flow Action] Processing input for Parent Account: ' + input.parentAccountId + 
                         ', Third Party Account: ' + input.thirdPartyAccountId);
            results.add(processInput(input));
        }

        System.debug(LoggingLevel.INFO, '==> [Flow Action] Finished.');
        return results;
    }

    /**
     * @description Processes a single credit check input
     * @param input Credit check input parameters
     * @return TriggerCreditCheckResult Operation result
     */
    private static TriggerCreditCheckResult processInput(CreditCheckInput input) {
        if (!isValidInput(input)) {
            return createErrorResult('Both Third Party and Parent Account Ids must be provided.');
        }

        try {
            // Use the public API method instead of directly instantiating the job
            System.enqueueJob(
                new PrequalSolutionsThirdPartyAPI.APIIntegrationJob(
                    input.thirdPartyAccountId,
                    input.parentAccountId
                ));    

            System.debug(LoggingLevel.INFO, 'Credit check job enqueued for Third Party: ' +
                    input.thirdPartyAccountId + ', Parent: ' + input.parentAccountId);

            return createSuccessResult('Credit check job successfully enqueued for Account Id: ' +
                                     input.thirdPartyAccountId);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Failed to enqueue credit check job: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
            
            return createErrorResult('Failed to initiate credit check: ' + e.getMessage());
        }
    }

    /**
     * @description Validates input parameters
     * @param input Credit check input to validate
     * @return Boolean true if input is valid
     */
    private static Boolean isValidInput(CreditCheckInput input) {
        return input != null && 
               input.thirdPartyAccountId != null && 
               input.parentAccountId != null;
    }

    /**
     * @description Creates a success result wrapper
     * @param message Success message
     * @return TriggerCreditCheckResult Success result
     */
    private static TriggerCreditCheckResult createSuccessResult(String message) {
        TriggerCreditCheckResult result = new TriggerCreditCheckResult();
        result.status = 'Success';
        result.message = message;
        return result;
    }

    /**
     * @description Creates an error result wrapper
     * @param message Error message
     * @return TriggerCreditCheckResult Error result
     */
    private static TriggerCreditCheckResult createErrorResult(String message) {
        TriggerCreditCheckResult result = new TriggerCreditCheckResult();
        result.status = 'Error';
        result.message = message;
        return result;
    }
}