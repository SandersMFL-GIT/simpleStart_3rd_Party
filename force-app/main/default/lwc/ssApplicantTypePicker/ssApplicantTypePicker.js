import { LightningElement, api, track, wire } from 'lwc';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';
import ACCOUNT_OBJECT from '@salesforce/schema/Account';
import CREDIT_APPLICANT from '@salesforce/schema/Account.Credit_Applicant__c';

export default class SsApplicantTypePicker extends LightningElement {
    /** Exposed to Flow as the chosen value */
    @api applicantType = '';

    @track options = [];

    // 1) Grab the default Record Type ID for Account
    @wire(getObjectInfo, { objectApiName: ACCOUNT_OBJECT })
    objectInfo;

    // 2) Load the picklist values for Credit_Applicant__c
    @wire(getPicklistValues, {
        recordTypeId: '$objectInfo.data.defaultRecordTypeId',
        fieldApiName: CREDIT_APPLICANT
    })
    loadValues({ data }) {
        if (data) {
            this.options = data.values.map(v => ({
                label: v.label,
                value: v.value
            }));
        }
    }

    handleChange(event) {
        this.applicantType = event.detail.value;
    }

    /** Flow will call this to block Next until they pick something */
    @api
    validate() {
        if (!this.applicantType) {
            return {
                isValid: false,
                errorMessage: 'Please select Client or Third Party.'
            };
        }
        return { isValid: true };
    }
}
