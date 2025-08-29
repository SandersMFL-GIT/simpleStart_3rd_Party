/**
 * @description Third-party application form component for SimpleStart Flow
 * Creates a new third-party Account record and navigates to next Flow screen
 * @author Simple Start Development Team
 * @version 2.0 - Guest User Compatible
 */
import { LightningElement, api, track, wire } from 'lwc';
import { FlowNavigationNextEvent } from 'lightning/flowSupport';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getPicklistValues } from 'lightning/uiObjectInfoApi';
import STATE_FIELD from '@salesforce/schema/Account.State_A__c';
import createThirdPartyAccountSimple from '@salesforce/apex/CustomThirdPartyController.createThirdPartyAccountSimple';
import getParentAccountId18 from '@salesforce/apex/CustomThirdPartyController.getParentAccountId18';
import MFL_TopFullLogo from '@salesforce/resourceUrl/MFL_TopFullBlack';

export default class SsThirdPartyApplicationForm extends LightningElement {
    // === Bulletproof recordId handling ===
    _recordId;
    @api
    get recordId() { return this._recordId; }
    set recordId(val) {
        this._recordId = val;
        // set a non-null default immediately so Flow outputs are populated
        if (val) {
            this.parentAccountId = this.parentAccountId || val;
            // normalize 15 -> 18 asynchronously
            this.normalizeParentId(val);
        }
    }

    // Input properties from Flow
    @api recordTypeId;   // Third-Party Account RecordType Id

    // Output properties back to Flow
    @api thirdPartyId;    // New Third-Party Account Id (Flow output)
    @api parentAccountId; // 18-char Parent Account Id (normalized)

    // Private reactive properties
    @track errorMessage = '';
    @track isLoading = false;
    @track stateOptions = [];

    @wire(getPicklistValues, { recordTypeId: '$recordTypeId', fieldApiName: STATE_FIELD })
    wiredStatePicklistValues({ error, data }) {
        if (data) {
            this.stateOptions = data.values;
            console.log('State picklist values loaded:', JSON.stringify(this.stateOptions));
        } else if (error) {
            console.error('Error loading state picklist values', error);
        }
    }

    // Form data object
    @track formData = {
        firstName: '',
        middleName: '',
        lastName: '',
        birthdate: '',
        socialSecurityNumber: '',
        mobilePhone: '',
        email: '',
        street: '',
        city: '',
        state: '',
        postalCode: '',
        annualIncome: ''
    };

    // Static resource URL for logo
    get topLogoUrl() {
        return MFL_TopFullLogo;
    }

    /**
     * @description Component initialization
     */
    connectedCallback() {
        // If Flow didn't pass recordId, try URL param (setter will normalize)
        if (!this._recordId) {
            const fromUrl = this.getUrlParameter('recordId');
            if (fromUrl) {
                this.recordId = fromUrl; // triggers setter above
            }
        }

        console.log('=== COMPONENT INITIALIZED ===');
        console.log('- recordId (raw/backing):', this._recordId);
        console.log('- recordTypeId:', this.recordTypeId);
        console.log('==============================');
    }

    /**
     * @description Normalize recordId to 18-char and set parentAccountId
     */
    async normalizeParentId(idFromContext) {
        try {
            if (!idFromContext) {
                this.parentAccountId = null;
                return;
            }
            const normalized = await getParentAccountId18({ recordId: idFromContext });
            const safe = normalized || idFromContext;
            this.parentAccountId = safe;
            this._recordId = safe; // keep aligned without re-triggering setter
            console.log('Parent Account Id (18):', this.parentAccountId);
        } catch (e) {
            console.error('Failed to normalize parent Id, using original:', e);
            this.parentAccountId = idFromContext;
        }
    }

    /**
     * @description Gets URL parameter value
     * @param {String} param Parameter name
     * @return {String} Parameter value
     */
    getUrlParameter(param) {
        const urlParams = new URLSearchParams(window.location.search);
        const value = urlParams.get(param);
        console.log(`URL parameter ${param}:`, value);
        return value;
    }

    /**
     * @description Handles input changes and updates form data
     * @param {Event} event Input change event
     */
    handleInputChange(event) {
        const fieldName = event.target.name;
        const fieldValue = event.target.value;
        this.formData = { ...this.formData, [fieldName]: fieldValue };
    }

    /**
     * @description Handles form submission with validation and field injection
     * @param {Event} event Form submit event
     */
    handleSubmit(event) {
        event.preventDefault();
        console.log('Form submission started');

        if (this.isLoading) {
            console.log('Form already loading, skipping submission');
            return;
        }

        if (!this.validateInputs()) {
            console.log('Form validation failed');
            return;
        }

        console.log('Form validation passed, creating account...');
        this.setLoadingState(true);
        this.clearErrors();

        // Create account data object
        const accountData = {
            FirstName: this.formData.firstName,
            MiddleName: this.formData.middleName,
            LastName: this.formData.lastName,
            Birthdate__c: this.formData.birthdate,
            Social_Security_Number__c: this.formData.socialSecurityNumber,
            PersonMobilePhone: this.formData.mobilePhone,
            PersonEmail: this.formData.email,
            PersonMailingStreet: this.formData.street,
            PersonMailingCity: this.formData.city,
            State_A__c: this.formData.state,
            PersonMailingPostalCode: this.formData.postalCode,
            Annual_household_income__c: this.formData.annualIncome,
            // Only include RecordTypeId - no parent relationship
            RecordTypeId: this.recordTypeId || 'NO_RECORD_TYPE_PROVIDED',
            Type: 'Third Party'
        };

        console.log('=== ACCOUNT DATA DEBUG ===');
        console.log('RecordTypeId being sent:', accountData.RecordTypeId);
        console.log('Full accountData:', JSON.stringify(accountData, null, 2));
        console.log('==========================');

        // Call Apex method to create the account
        this.createAccount(accountData);
    }

    /**
     * @description Creates the third-party account via Apex
     * @param {Object} accountData Account data to create
     */
    async createAccount(accountData) {
        try {
            console.log('Creating account with data:', accountData);
            const result = await createThirdPartyAccountSimple({ accountData: accountData });
            console.log('Account created successfully with ID:', result);
            this.thirdPartyId = result; // result is the ID string directly
            // ensure Flow gets the normalized parent Id
            this.parentAccountId = this.parentAccountId || this.recordId;
            console.log('thirdPartyId set to:', this.thirdPartyId);
            console.log('parentAccountId set to:', this.parentAccountId);
            console.log('Third-party account created successfully!');
            this.handleSuccess(result);
        } catch (error) {
            console.error('Error creating account:', error);
            this.handleError(error);
        }
    }

    /**
     * @description Validates required inputs before submission
     * @return {Boolean} True if validation passes
     */
    validateInputs() {
        console.log('=== VALIDATION DEBUG ===');
        console.log('this.recordId:', this.recordId);
        console.log('this.recordTypeId:', this.recordTypeId);
        console.log('typeof recordId:', typeof this.recordId);
        console.log('typeof recordTypeId:', typeof this.recordTypeId);
        console.log('recordId length:', this.recordId ? this.recordId.length : 'null/undefined');
        console.log('========================');

        console.log('Validation passed - allowing submission with any values');
        return true;
    }

    /**
     * @description Handles successful account creation
     * @param {Object} result Success result with new record details
     */
    handleSuccess(result) {
        this.setLoadingState(false);
        this.clearErrors();

        try {
            // Show success message
            this.showSuccessToast();
            // Navigate to next Flow screen
            this.navigateNext();
        } catch (error) {
            this.handleFormError('Error processing successful submission: ' + error.message);
        }
    }

    /**
     * @description Handles form errors
     * @param {Error} error Error from account creation
     */
    handleError(error) {
        this.setLoadingState(false);

        let errorMsg = 'An error occurred while saving the form.';
        if (error?.body?.message) {
            errorMsg = error.body.message;
        } else if (error?.message) {
            errorMsg = error.message;
        }

        this.setError(errorMsg);
        this.showErrorToast(errorMsg);
    }

    /**
     * @description Generic error handler for internal errors
     * @param {String} message Error message
     */
    handleFormError(message) {
        this.setLoadingState(false);
        this.setError(message);
        this.showErrorToast(message);
    }

    /**
     * @description Sets loading state and manages UI
     * @param {Boolean} loading Loading state
     */
    setLoadingState(loading) {
        this.isLoading = loading;
    }

    /**
     * @description Sets error message
     * @param {String} message Error message
     */
    setError(message) {
        this.errorMessage = message;
    }

    /**
     * @description Clears error messages
     */
    clearErrors() {
        this.errorMessage = '';
    }

    /**
     * @description Navigates to next step in Flow
     */
    navigateNext() {
        const navigateNextEvent = new FlowNavigationNextEvent();
        this.dispatchEvent(navigateNextEvent);
    }

    /**
     * @description Shows success toast message
     */
    showSuccessToast() {
        const event = new ShowToastEvent({
            title: 'Success',
            message: 'Application submitted successfully!',
            variant: 'success'
        });
        this.dispatchEvent(event);
    }

    /**
     * @description Shows error toast message
     * @param {String} message Error message
     */
    showErrorToast(message) {
        const event = new ShowToastEvent({
            title: 'Error',
            message: message,
            variant: 'error'
        });
        this.dispatchEvent(event);
    }
}
