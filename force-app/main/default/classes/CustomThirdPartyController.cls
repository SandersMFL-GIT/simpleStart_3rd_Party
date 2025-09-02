/**
 * @description Custom controller for creating third-party accounts
 * @author Sanders
 * @version 1.0
 */
public with sharing class CustomThirdPartyController {
    
    /**
     * @description Creates a third-party account and returns its ID
     * @param accountData Map containing account field data
     * @return String The ID of the newly created Account record
     */
    @AuraEnabled
    public static String createThirdPartyAccountSimple(Map<String, Object> accountData) {
        System.debug('Creating third-party account with data: ' + JSON.serialize(accountData));
        
        try {
            // Check CRUD permissions before proceeding
            if (!Schema.sObjectType.Account.isCreateable()) {
                throw new AuraHandledException('Insufficient permissions to create Account records');
            }
            
            // Create new third-party account
            Account newAccount = new Account();
            
            // Set basic fields
            newAccount.FirstName = getString(accountData, 'FirstName');
            newAccount.LastName = getString(accountData, 'LastName');
            newAccount.MiddleName = getString(accountData, 'MiddleName');
            newAccount.Social_Security_Number__c = getString(accountData, 'Social_Security_Number__c');
            newAccount.PersonMobilePhone = getString(accountData, 'PersonMobilePhone');
            newAccount.PersonEmail = getString(accountData, 'PersonEmail');
            newAccount.PersonMailingStreet = getString(accountData, 'PersonMailingStreet');
            newAccount.PersonMailingCity = getString(accountData, 'PersonMailingCity');
            newAccount.State_A__c = getString(accountData, 'State_A__c');
            newAccount.PersonMailingPostalCode = getString(accountData, 'PersonMailingPostalCode');
            newAccount.Type = 'Third Party';
            
            // Handle special fields
            setDateField(newAccount, accountData, 'Birthdate__c');
            setDecimalField(newAccount, accountData, 'Annual_household_income__c');
            setRecordType(newAccount, accountData);
            
            // Insert the account
            insert newAccount;
            System.debug('Third-party account created with ID: ' + newAccount.Id);
            
            return newAccount.Id;
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error creating third-party account: ' + e.getMessage());
            throw new AuraHandledException('Error creating account: ' + e.getMessage());
        }
    }
    
    // Helper methods to reduce complexity
    private static String getString(Map<String, Object> data, String key) {
        return data.containsKey(key) && data.get(key) != null ? String.valueOf(data.get(key)) : null;
    }
    
    private static void setDateField(Account acc, Map<String, Object> data, String key) {
        String dateStr = getString(data, key);
        if (String.isNotBlank(dateStr)) {
            try {
                if (key == 'Birthdate__c') {
                    acc.Birthdate__c = Date.valueOf(dateStr);
                }
            } catch (Exception e) {
                System.debug('Invalid date format for ' + key + ': ' + dateStr);
            }
        }
    }
    
    private static void setDecimalField(Account acc, Map<String, Object> data, String key) {
        String decimalStr = getString(data, key);
        if (String.isNotBlank(decimalStr)) {
            try {
                if (key == 'Annual_household_income__c') {
                    acc.Annual_household_income__c = Decimal.valueOf(decimalStr);
                }
            } catch (Exception e) {
                System.debug('Invalid decimal format for ' + key + ': ' + decimalStr);
            }
        }
    }
    
    private static void setRecordType(Account acc, Map<String, Object> data) {
        String recordTypeId = getString(data, 'RecordTypeId');
        if (String.isNotBlank(recordTypeId) && !recordTypeId.equals('NO_RECORD_TYPE_PROVIDED')) {
            acc.RecordTypeId = recordTypeId;
        }
    }

    /** 
     * @description Returns the 18-char version of the provided record Id (works with 15 or 18).
     * @param recordId A 15- or 18-character Id (e.g., from URL param)
     * @return String 18-character Id (safe for case-insensitive contexts)
     */
    @AuraEnabled(cacheable=true)
    public static String getParentAccountId18(String recordId) {
        try {
            if (String.isBlank(recordId)) {
                return null;
            }
            // Id.valueOf() converts 15 -> 18 automatically and validates the Id
            Id normalized = Id.valueOf(recordId);
            return (String)normalized;
        } catch (Exception e) {
            // Surface a clean message to the client (LWC/Flow)
            throw new AuraHandledException('Invalid record Id');
        }
    }
}