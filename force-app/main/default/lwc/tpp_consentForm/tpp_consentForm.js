import { LightningElement, api } from 'lwc';
import { FlowNavigationNextEvent, FlowAttributeChangeEvent } from 'lightning/flowSupport';

import getActiveTemplate from '@salesforce/apex/ConsentController.getActiveTemplate';
import saveConsentWithSnapshot from '@salesforce/apex/ConsentController.saveConsentWithSnapshot';
import getParentAccountId18 from '@salesforce/apex/CustomThirdPartyController.getParentAccountId18';


export default class ConsentForm extends LightningElement {
    // Checkboxes
    consentChecked = false;
    termsChecked = false;
    creditConsentChecked = false;
    showConsent = true;

    // Flow I/O
    @api isConsentValid = false;
    @api accountId;       
    @api parentAccountId; 
    @api thirdPartyAccountId;

    // Template state
    templateVersion;
    templateHtml;

    // UX
    isSaving = false;
    errorMsg = '';

    async connectedCallback() {
        try {
            // Resolve accountId if not provided but parentAccountId is
            if (!this.accountId && this.parentAccountId) {
                this.accountId = await getParentAccountId18({ recordId: this.parentAccountId });
            }

            // Load active consent template
            const tpl = await getActiveTemplate();
            if (!tpl || !tpl.Consent_Body__c || !tpl.Version__c) {
                this.errorMsg = 'Active Consent Template is not configured.';
                return;
            }
             this.templateVersion = String(tpl.Version__c);
    const body = tpl.Consent_Body__c;
    this.templateHtml = (body == null) ? '' : String(body);
        } catch (e) {
            // eslint-disable-next-line no-console
            console.error('Init error', e);
            this.errorMsg = 'Failed to initialize consent screen.';
        }
    }

    get buttonDisabled() {
        return this.isSaving || !(this.consentChecked && this.termsChecked && this.creditConsentChecked);
    }
    get consentToggleLabel() {
        return this.showConsent ? 'Hide Consent Details' : 'Read Full Consent';
    }
    toggleConsent() { this.showConsent = !this.showConsent; }

    handleConsentChange(e){ this.consentChecked = e.target.checked; this._syncValid(); }
    handleTermsChange(e){ this.termsChecked = e.target.checked; this._syncValid(); }
    handleCreditConsentChange(e){ this.creditConsentChecked = e.target.checked; this._syncValid(); }

    _syncValid() {
        this.isConsentValid = (this.consentChecked && this.termsChecked && this.creditConsentChecked);
        this.dispatchEvent(new FlowAttributeChangeEvent('isConsentValid', this.isConsentValid));
    }

    async handleAgree() {
        this.errorMsg = '';
        if (!this.consentChecked || !this.termsChecked || !this.creditConsentChecked) return;
        if (!this.accountId) { this.errorMsg = 'Account Id is missing.'; return; }
        if (!this.templateVersion) { this.errorMsg = 'Consent template not available.'; return; }

        this.isSaving = true;
        try {
            await saveConsentWithSnapshot({
                accountId: this.accountId,
                version: this.templateVersion,
                htmlSnapshot: this.templateHtml,
                acceptedDisclosures: this.consentChecked,
                acceptedTerms: this.termsChecked,
                acceptedFCRA: this.creditConsentChecked,
                thirdPartyAccountId: this.thirdPartyAccountId
            });
            this.dispatchEvent(new FlowNavigationNextEvent());
        } catch (e) {
            // eslint-disable-next-line no-console
            console.error('Consent save failed', e);
            this.errorMsg = 'Could not save consent. Please try again.';
        } finally {
            this.isSaving = false;
        }
    }
}
