import { LightningElement, api, track } from 'lwc';
import { FlowNavigationNextEvent } from 'lightning/flowSupport';

export default class SsApplicationForm extends LightningElement {
    @api recordId; // Provided by Flow

    @track errorMessage = '';
    @track isLoading = false;

    handleSuccess(event) {
        this.isLoading = false;
        // Get the fields from the record-edit-form response
        const fields = event.detail.fields;

        // Clear any error message
        this.errorMessage = '';

        // Proceed to next Flow screen
        this.dispatchEvent(
            new FlowNavigationNextEvent({ detail: fields })
        );
    }

    /** user clicks our custom button */
    handleSave() {
        if (this.isLoading) return;
        this.isLoading = true;
        // submit the form
        const form = this.template.querySelector('lightning-record-edit-form');
        form.submit();
    }

    handleError(event) {
        this.isLoading = false;
        this.errorMessage = event.detail.detail || 'An error occurred.';
    }
}
