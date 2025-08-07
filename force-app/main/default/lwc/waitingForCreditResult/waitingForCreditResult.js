import { LightningElement, api, wire } from 'lwc';
import { FlowNavigationNextEvent } from 'lightning/flowSupport';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { refreshApex } from '@salesforce/apex';
import CREDIT_DECISION_FIELD from '@salesforce/schema/Account.Credit_Decision__c';

export default class WaitingForCreditResult extends LightningElement {
    @api recordId;

    wiredAccountResult; 
    intervalId;
    pollCount = 0; 
    maxPolls = 5;  
    hasNavigated = false;

    @wire(getRecord, { recordId: '$recordId', fields: [CREDIT_DECISION_FIELD] })
    wiredAccount(result) {
        this.wiredAccountResult = result; 
        const { data, error } = result;
        if (data) {
            const creditDecision = getFieldValue(data, CREDIT_DECISION_FIELD);
            if (
                creditDecision !== null &&
                creditDecision !== undefined &&
                creditDecision !== '' &&
                !this.hasNavigated
            ) {
                this.stopPollingAndNavigate();
            }
        } else if (error) {
            console.error('Error wiring record:', error);
            this.stopPolling(); 
        }
    }

    connectedCallback() {
        this.intervalId = setInterval(() => {
            this.pollCount++;
            if (this.wiredAccountResult) {
                refreshApex(this.wiredAccountResult);
            }
            if (this.pollCount >= this.maxPolls && !this.hasNavigated) {
                this.stopPollingAndNavigate();
            }
        }, 3000); 
    }

    disconnectedCallback() {
        this.stopPolling();
    }

    stopPolling() {
        if (this.intervalId) {
            clearInterval(this.intervalId);
            this.intervalId = null;
        }
    }

    stopPollingAndNavigate() {
        if (!this.hasNavigated) {
            this.hasNavigated = true;
            this.stopPolling();
            this.dispatchEvent(new FlowNavigationNextEvent());
        }
    }
}
