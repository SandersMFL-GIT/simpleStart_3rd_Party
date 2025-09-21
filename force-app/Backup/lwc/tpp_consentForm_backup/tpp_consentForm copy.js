import { LightningElement, track, api } from 'lwc';
import { FlowNavigationNextEvent, FlowAttributeChangeEvent } from 'lightning/flowSupport';

export default class ConsentForm extends LightningElement {
    @track consentChecked = false;
    @track termsChecked = false;
    @track showConsent = true;

    // Output variable for Flow to check validation state
    @api isConsentValid = false;

    

    renderedCallback() {
        // Wait for DOM to render, then inject only if consent box is visible
        if (this.showConsent) {
            this.injectConsentText();
        }
    }

    injectConsentText() {
        const consentText = `
            <div class="slds-text-body_regular consent-text">
                <b>Introduction:</b> You are submitting a request for a loan pre-qualification (hereinafter, a “Request”). We can only give you the benefits of our service by conducting our business through the Internet. In order to do this, we need you to consent to our giving you certain disclosures electronically. This document informs you of your rights when receiving legally required disclosures, notices and information ("Disclosures") from us and the lender(s) to whom your Request is submitted. By completing and submitting a Request through us, you acknowledge receipt of this document and consent to the electronic delivery of such Disclosures. <br><br>

<b>Electronic Communications: </b>Any Disclosures related to your Request will be provided to you electronically through our consumer reporting agency and technology provider, Fraud Protection Network Inc., either (i) directly to any email address you provide on your Request (or any updated address you provide later) or (ii) on our website. If Disclosures are provided on our website, we will give you our appropriate website address in advance and send an email or regular mail notice if that address changes. <br><br>

<b>Consenting to do Business Electronically: </b> By checking the box next to "Consent to Electronic Disclosures" and clicking on the "Continue" button, you agree that Fraud Protection Network Inc. ("FPN") may provide Disclosure to you electronically. Disclosure means any information that we are required by law to provide to you in writing in connection with your loan pre-qualification or any resulting or subsequent transactions with us. Disclosures include any agreement, periodic statement, privacy policy, adverse action notice or other notice we may provide to you. <br><br>

<b>Hardware and Software Requirements: </b> To access, view and retain Disclosures, you will need (i) a valid working e-mail account and (ii) access to a computer, operating system and telecommunication connections to the Internet capable of receiving, accessing, displaying and either printing or storing Disclosures electronically. You also need browser software that supports 256-bit security encryption and Adobe Reader® version 9.0 or higher. We will notify you of any changes to these requirements that create a risk that may prevent you from receiving Disclosures electronically. <br><br>

<b>Withdrawing Consent: </b> You may withdraw consent to electronic Disclosures at any time by calling 855.203.0683, e-mailing us at support@fraudprotectionnetwork.com, or writing to us at 2980 NE 207th Street Unit 509, Aventura, Florida, 33180. We will not charge you a fee for withdrawing your consent. If you withdraw your consent, the legal effectiveness, validity and/or enforceability of prior electronic Disclosures will not be affected. Any withdrawal of your consent will be effective only after we have a reasonable period of time to process your withdrawal. <br><br>

<b>Paper Copies: </b> You may request a paper copy of any Disclosure by contacting us at one of the channels provided above. To the extent permitted by law, there may be a $10 processing fee assessed for each request for a paper copy. <br><br>

<b>Changes to E-Mail Address: </b> You must promptly inform us of any change in your e-mail address by contacting us at one of the channels provided above. <br><br>

<b>Your Ability to Access Disclosures: </b> By checking the box next to "Consent to Electronic Disclosures" and clicking on the "Continue" button, you acknowledge that you can access the Disclosures in the formats described above.<br><br>
<b>Third-Party Application Usage:</b> You understand and consent to the utilization of the information you provide with a third-party credit application associated with MFL. This application is limited to a soft credit check that will not affect your credit score.

            </div>
        `;
        const container = this.template.querySelector('[data-id="consent-container"]');
        if (container) {
            container.innerHTML = consentText;
        }
    }

    get buttonDisabled() {
        return !(this.consentChecked && this.termsChecked);
    }

    get consentToggleLabel() {
        return this.showConsent ? 'Hide Consent Details' : 'Read Full Consent';
    }

    toggleConsent() {
        this.showConsent = !this.showConsent;
    }

    handleConsentChange(event) {
        this.consentChecked = event.target.checked;
        this.updateValidationState();
    }

    handleTermsChange(event) {
        this.termsChecked = event.target.checked;
        this.updateValidationState();
    }

    // Update the Flow output variable whenever checkbox state changes
    updateValidationState() {
        this.isConsentValid = this.consentChecked && this.termsChecked;
        
        // Notify Flow of the validation state change
        const attributeChangeEvent = new FlowAttributeChangeEvent('isConsentValid', this.isConsentValid);
        this.dispatchEvent(attributeChangeEvent);
    }

    handleAgree() {
        // Strict validation - prevent any navigation without both checkboxes
        if (!this.consentChecked || !this.termsChecked) {
            // Show error message if user somehow clicks without checking boxes
            this.showToast('Error', 'You must agree to both the Consent to Electronic Disclosures and Terms of Service to continue.', 'error');
            return;
        }
        
        console.log('User has agreed to terms and consent.');
        // Navigate to next step in Flow only if both are checked
        const navigateNextEvent = new FlowNavigationNextEvent();
        this.dispatchEvent(navigateNextEvent);
    }

    // Add toast message method for better user feedback
    showToast(title, message, variant) {
        // Since we can't import ShowToastEvent in Flow context, we'll use a custom approach
        console.error(title + ': ' + message);
        // You could also show a visual error message in the component
    }
}
