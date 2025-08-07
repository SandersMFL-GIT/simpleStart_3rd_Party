import { LightningElement, api, track } from 'lwc';
import { FlowNavigationNextEvent } from 'lightning/flowSupport';

export default class SsApplicationForm extends LightningElement {
    @api recordId; 

    @track errorMessage = '';
    @track isLoading = false;

    handleSuccess(event) {
        this.isLoading = false;
        
        const fields = event.detail.fields;

        
        this.errorMessage = '';

        this.dispatchEvent(
            new FlowNavigationNextEvent({ detail: fields })
        );
    }

    
    handleSave() {
        if (this.isLoading) return;
        this.isLoading = true;
        const form = this.template.querySelector('lightning-record-edit-form');
        form.submit();
    }

    handleError(event) {
        this.isLoading = false;
        this.errorMessage = event.detail.detail || 'An error occurred.';
    }
}