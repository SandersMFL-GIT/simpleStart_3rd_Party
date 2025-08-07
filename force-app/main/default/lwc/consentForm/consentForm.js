import { LightningElement, track } from 'lwc';
import { FlowNavigationNextEvent } from 'lightning/flowSupport';

export default class ConsentForm extends LightningElement {
    @track consentChecked = false;
    @track termsChecked = false;

    handleConsentChange(event) {
        this.consentChecked = event.target.checked;
    }
    handleTermsChange(event) {
        this.termsChecked = event.target.checked;
    }

    get buttonDisabled() {
        return !(this.consentChecked && this.termsChecked);
    }

    handleAgree() {
        this.dispatchEvent(new FlowNavigationNextEvent());
    }
}
