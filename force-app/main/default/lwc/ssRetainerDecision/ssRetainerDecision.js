import { LightningElement, api, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import CREDIT_DECISION_FIELD from '@salesforce/schema/Account.Credit_Decision__c';
import QUOTED_RETAINER_FIELD from '@salesforce/schema/Account.Quoted_Retainer__c';
import REDUCED_RETAINER_FIELD from '@salesforce/schema/Account.Quoted_Retainer_Amount__c';
import NAME_FIELD from '@salesforce/schema/Account.Name';

const FIELDS = [
    CREDIT_DECISION_FIELD,
    QUOTED_RETAINER_FIELD,
    REDUCED_RETAINER_FIELD,
    NAME_FIELD
];

const DISCOUNTS = {
    'Gold - 0% Retainer': 0,
    'Silver - 50% Retainer': 0.5,
    'Bronze - 80% Retainer': 0.8
};

export default class SsRetainerDecision extends LightningElement {
    @api recordId;
    creditDecision;
    quotedRetainer;
    reducedRetainer;
    accountName;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredAccount({ data }) {
        if (data) {
            this.creditDecision   = data.fields.Credit_Decision__c.value;
            this.quotedRetainer  = data.fields.Quoted_Retainer__c.value;
            this.reducedRetainer = data.fields.Quoted_Retainer_Amount__c.value;
            this.accountName     = data.fields.Name.value;
        }
    }

    get isQualified() {
        return Object.keys(DISCOUNTS).includes(this.creditDecision);
    }

    get showFull() {
         return (
        this.creditDecision === 'Full Retainer' ||
        (!this.isQualified && !this.showFrozen)
    );
    }

    get showFrozen() {
    return this.creditDecision === 'Credit Frozen';
}


    get showFailed() {
    return this.creditDecision === 'Failed- Follow up with PC';
}

    // Improved logic: Calculate standard retainer from discounted if needed
    get standardRetainer() {
        if (this.creditDecision === 'Gold - 0% Retainer') {
            return 0;
        }
        const discount = DISCOUNTS[this.creditDecision];
        if (discount && this.reducedRetainer) {
            return this.reducedRetainer / discount;
        }
        return this.quotedRetainer != null ? this.quotedRetainer : 0;
    }

    get reducedRetainerDisplay() {
         if (this.creditDecision === 'Gold - 0% Retainer') {
            return 0;
        }
        const discount = DISCOUNTS[this.creditDecision];
        if (typeof discount !== "undefined" && this.standardRetainer) {
            return this.standardRetainer * discount;
        }
        return this.reducedRetainer != null ? this.reducedRetainer : 0;
    }




}