import { LightningElement, api, track } from 'lwc';
import { FlowNavigationNextEvent } from 'lightning/flowSupport';

export default class SsApplicationForm extends LightningElement {
    @api recordTypeId;

    // Output Variables,,
    @api firstName;
    @api middleName;
    @api lastName;
    @api mobile;
    @api email;
    @api birthdate;
    @api ssn;
    @api mailingStreet;
    @api mailingCity;
    @api mailingState;
    @api mailingPostalCode;
    @api annualHouseholdIncome;
    @api testOutput;


    @track errorMessage = '';
    @track isLoading = false;

    handleSuccess(event) {
        this.isLoading = false;
        const fields = event.detail.fields;

        this.firstName             = fields.FirstName && fields.FirstName.value;
        this.middleName            = fields.MiddleName && fields.MiddleName.value;
        this.lastName              = fields.LastName && fields.LastName.value;
        this.mobile                = fields.MobilePhone && fields.MobilePhone.value;
        this.email                 = fields.Email && fields.Email.value;
        this.birthdate             = fields.Birthdate && fields.Birthdate.value;
        this.ssn                   = fields.SSN__c && fields.SSN__c.value;
        this.mailingStreet         = fields.MailingStreet && fields.MailingStreet.value;
        this.mailingCity           = fields.MailingCity && fields.MailingCity.value;
        this.mailingState          = fields.MailingState && fields.MailingState.value;
        this.mailingPostalCode     = fields.MailingPostalCode && fields.MailingPostalCode.value;
        this.annualHouseholdIncome = fields.Annual_Household_Income__c && fields.Annual_Household_Income__c.value;

        this.errorMessage = '';
        this.dispatchEvent(new FlowNavigationNextEvent());
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
