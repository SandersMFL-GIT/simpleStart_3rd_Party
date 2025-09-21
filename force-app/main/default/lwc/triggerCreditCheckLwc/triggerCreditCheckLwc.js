import { LightningElement, api, track } from 'lwc';

export default class TriggerCreditCheckLwc extends LightningElement {
    @api recordId;
    @track isLoading = false;
    @track message = '';

    handleTriggerClick() {
        this.isLoading = true;
        this.message = '';
        launchCreditCheck({ accountId: this.recordId })
            .then(() => {
                this.message = 'Credit check started successfully.';
            })
            .catch(error => {
                this.message = 'Error: ' + (error && error.body && error.body.message ? error.body.message : 'Unknown error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }
}
