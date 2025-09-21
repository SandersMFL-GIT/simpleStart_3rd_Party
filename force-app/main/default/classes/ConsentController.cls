/**
 * @description Serve active consent template and persist consent events with body snapshot.
 */
public without sharing class ConsentController {

    @AuraEnabled(cacheable=true)
    public static Consent_Template__c getActiveTemplate() {
        List<Consent_Template__c> rows = [
            SELECT Id, Version__c, Consent_Body__c
            FROM Consent_Template__c
            WHERE Is_Active__c = TRUE
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        if (rows.isEmpty()) {
            throw new AuraHandledException('Active consent template is not configured.');
        }
        return rows[0];
    }

    /**
     * @description 
     */
    @AuraEnabled
    public static Id saveConsentWithSnapshot(
        Id accountId,
        String version,
        String htmlSnapshot,
        Boolean acceptedDisclosures,
        Boolean acceptedTerms,
        Boolean acceptedFCRA,
        Id thirdPartyAccountId 
    ) {
        if (accountId == null)             throw new AuraHandledException('Account Id is required.');
        if (thirdPartyAccountId == null)   throw new AuraHandledException('Third-Party Account Id is required.');
        if (String.isBlank(version))       throw new AuraHandledException('Consent version is required.');
        if (String.isBlank(htmlSnapshot))  throw new AuraHandledException('Consent HTML snapshot is required.');
        if (htmlSnapshot.length() > 32000) throw new AuraHandledException('Consent body exceeds 32,000 characters.');

        
        Account tp = [
            SELECT Name 
            FROM Account 
            WHERE Id = :thirdPartyAccountId 
            LIMIT 1
        ];
        String thirdPartyName = tp.Name;

        Consent_Event__c ev = new Consent_Event__c(
            Account__c                   = accountId,             
            Consent_Version__c           = version,
            Electronic_Disclosures__c    = acceptedDisclosures,
            Terms_Accepted__c            = acceptedTerms,
            FCRA_Written_Instructions__c = acceptedFCRA,
            Agreed_Timestamp__c          = System.now(),
            Consent_Body_Snapshot__c     = htmlSnapshot,
            Third_Party_Name__c          = thirdPartyName         
        );
        insert ev;
        return ev.Id;
    }
}