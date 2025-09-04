import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue, updateRecord, getRecordNotifyChange } from 'lightning/uiRecordApi';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import ConflictAlertModal from 'c/conflictAlertModal';
import findPotentialConflicts from '@salesforce/apex/ConflictAlertController.findPotentialConflicts';

// Schema imports for Account fields
import ALERT from '@salesforce/schema/Account.Conflict_Alert__c';
import MESSAGE from '@salesforce/schema/Account.Conflict_Alert_Message__c';
import SCORE from '@salesforce/schema/Account.Conflict_Score__c';
import DISMISSED from '@salesforce/schema/Account.Conflict_Alert_Dismissed__c';
import SIGFIELD from '@salesforce/schema/Account.Conflict_Alert_Signature__c';
import ID_FIELD from '@salesforce/schema/Account.Id';

/**
 * Required fields for the wire service
 */
const FIELDS = [ALERT, MESSAGE, SCORE, DISMISSED, SIGFIELD];

/**
 * ConflictAlert Lightning Web Component
 * 
 * Manages conflict alerts for Account records by monitoring changes in conflict scores
 * and displaying appropriate modals when conflicts are detected.
 * 
 * Features:
 * - Automatic conflict detection based on score changes
 * - Modal-based alert system with dismiss functionality
 * - Session-based signature tracking for offline scenarios
 * - Re-arming logic when new conflicts arise after dismissal
 * 
 * @author Salesforce Development Team
 * @version 1.0
 */
export default class ConflictAlert extends LightningElement {
    /**
     * The record ID of the Account being monitored
     * @type {string}
     */
    @api recordId;

    /**
     * Tracked properties for component state management
     */
    @track showModal = false;
    @track showResults = false;
    @track message = '';
    @track score = '';
    @track matches = [];
    @track loading = false;

    /**
     * Private properties for internal state management
     */
    _wiredAccountResult;
    _refreshedOnce = false;
    _lastSessionSigByRecord = new Map();
    _modalOpen = false;
    _isDismissing = false;

    /**
     * Wire service to get Account record data
     * Monitors changes and triggers conflict detection logic
     * 
     * @param {Object} result - Wire service result containing data or error
     */
    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredAccount(result) {
        this._wiredAccountResult = result;
        const { error, data } = result;
        
        if (error) {
            this.handleError('Failed to load account data', error);
            return;
        }
        
        if (!data) return;

        // Prevent multiple modal instances
        if (this._modalOpen) return;

        try {
            this.processAccountData(data);
        } catch (processError) {
            this.handleError('Error processing account data', processError);
        }
    }

    /**
     * Process account data and determine if conflict alert should be shown
     * 
     * @param {Object} data - Account record data from wire service
     */
    processAccountData(data) {
        const alertOn = getFieldValue(data, ALERT) === true;
        const dismissed = getFieldValue(data, DISMISSED) === true;
        const message = getFieldValue(data, MESSAGE) || 'Potential conflict detected. Please review.';
        const score = getFieldValue(data, SCORE);
        const serverSigRaw = getFieldValue(data, SIGFIELD);

        const currentSig = this.buildSignature({ score });
        const serverSig = this.normalizeServerSig(serverSigRaw);
        const sessionSig = this._lastSessionSigByRecord.get(this.recordId);

        // Re-arm logic: if dismissed but signature changed, undismiss & show
        if (alertOn && dismissed) {
            const changedVsServer = !!serverSig && serverSig !== currentSig;
            const changedVsSession = !serverSig && sessionSig && sessionSig !== currentSig;
            
            if (changedVsServer || changedVsSession) {
                this.undismissAndShow({ currentSig, message, score });
                return;
            }
        }

        // Normal show rule
        if (alertOn && !dismissed) {
            this.showConflictAlert({ message, score, currentSig });
            this.performRefreshIfNeeded();
        }
    }

    /**
     * Build signature for conflict tracking (score-only for stability)
     * 
     * @param {Object} params - Parameters containing score
     * @param {number|string} params.score - Conflict score
     * @returns {string} Normalized signature string
     */
    buildSignature({ score }) {
        if (score === null || score === undefined || score === '') return '';
        const n = Number(score);
        return Number.isFinite(n) ? String(n) : String(score).trim();
    }

    /**
     * Normalize server signatures to handle legacy formats
     * 
     * @param {string} sig - Raw signature from server
     * @returns {string} Normalized signature
     */
    normalizeServerSig(sig) {
        if (!sig) return '';
        const s = String(sig);
        const parts = s.split('|');
        return parts[parts.length - 1].trim();
    }

    /**
     * Undismiss alert and show when signature changes
     * 
     * @param {Object} params - Parameters for undismissing alert
     * @param {string} params.currentSig - Current signature
     * @param {string} params.message - Alert message
     * @param {number} params.score - Conflict score
     */
    async undismissAndShow({ currentSig, message, score }) {
        try {
            const fields = {
                [ID_FIELD.fieldApiName]: this.recordId,
                [DISMISSED.fieldApiName]: false
            };
            
            if (SIGFIELD?.fieldApiName) {
                fields[SIGFIELD.fieldApiName] = currentSig;
            }
            
            await updateRecord({ fields });
            getRecordNotifyChange([{ recordId: this.recordId }]);
            this._lastSessionSigByRecord.set(this.recordId, currentSig);
            
            await this.showConflictAlert({ message, score, currentSig });
        } catch (error) {
            this.handleError('Failed to undismiss conflict alert', error);
            // Still show the modal even if update fails
            await this.showConflictAlert({ message, score, currentSig });
        }
    }

    /**
     * Show conflict alert modal or inline alert
     * 
     * @param {Object} params - Parameters for showing alert
     * @param {string} params.message - Alert message
     * @param {number} params.score - Conflict score
     * @param {string} params.currentSig - Current signature
     */
    async showConflictAlert({ message, score, currentSig }) {
        if (this._modalOpen) return;
        
        this.message = message;
        this.score = score;
        this._modalOpen = true;

        try {
            // Use ConflictAlertModal component (don't show inline modal)
            const result = await ConflictAlertModal.open({
                size: 'small',
                message,
                score,
                accountId: this.recordId
            });

            await this.handleModalResult(result, currentSig);
        } catch (error) {
            // Fallback to inline modal if ConflictAlertModal fails
            this.showModal = true;
            this.handleError('Modal failed to open, using inline alert', error);
        }
    }

    /**
     * Handle modal result (dismiss or close)
     * 
     * @param {string} result - Modal result ('dismiss' or 'close')
     * @param {string} currentSig - Current signature for tracking
     */
    async handleModalResult(result, currentSig) {
        if (result === 'dismiss') {
            await this.dismissAlert(currentSig);
        }
        this.closeModal();
    }

    /**
     * Dismiss the alert and update the record
     * 
     * @param {string} currentSig - Current signature to store
     */
    async dismissAlert(currentSig) {
        this._isDismissing = true;
        
        try {
            await updateRecord({
                fields: {
                    [ID_FIELD.fieldApiName]: this.recordId,
                    [DISMISSED.fieldApiName]: true,
                    ...(SIGFIELD?.fieldApiName ? { [SIGFIELD.fieldApiName]: currentSig } : {})
                }
            });
            
            getRecordNotifyChange([{ recordId: this.recordId }]);
            this._lastSessionSigByRecord.set(this.recordId, currentSig);
            
            this.showSuccessToast('Conflict alert dismissed successfully');
        } catch (error) {
            this.handleError('Failed to dismiss conflict alert', error);
        } finally {
            this._isDismissing = false;
        }
    }

    /**
     * Close modal and reset state
     */
    closeModal() {
        this.showModal = false;
        this._modalOpen = false;
    }

    /**
     * Perform refresh if needed (one-time refresh)
     */
    performRefreshIfNeeded() {
        if (!this._refreshedOnce) {
            this._refreshedOnce = true;
            refreshApex(this._wiredAccountResult).catch((error) => {
                this.handleError('Failed to refresh data', error);
            });
        }
    }

    // ========== EVENT HANDLERS ==========

    /**
     * Handle dismiss button click
     */
    handleDismiss() {
        const currentSig = this.buildSignature({ score: this.score });
        this.dismissAlert(currentSig);
    }

    /**
     * Handle view matches button click
     */
    async handleView() {
        this.loading = true;
        
        try {
            const result = await findPotentialConflicts({ accountId: this.recordId });
            this.matches = this.processMatches(result);
            this.showResults = true;
        } catch (error) {
            this.handleError('Failed to load potential matches', error);
        } finally {
            this.loading = false;
        }
    }

    /**
     * Close results modal
     */
    closeResults() {
        this.showResults = false;
        this.matches = [];
    }

    /**
     * Handle row click in results
     * 
     * @param {Event} event - Click event
     */
    handleRowClick(event) {
        event.preventDefault();
        const recordId = event.currentTarget.dataset.id;
        
        if (recordId) {
            // Navigate to record (implementation depends on your navigation strategy)
            this.navigateToRecord(recordId);
        }
    }

    /**
     * Handle backdrop click to close modal
     * 
     * @param {Event} event - Click event
     */
    handleBackdropClick(event) {
        // Only close if clicking directly on backdrop, not on modal content
        if (event.target === event.currentTarget) {
            this.closeModal();
        }
    }

    // ========== UTILITY METHODS ==========

    /**
     * Process matches data for display
     * 
     * @param {Array} rawMatches - Raw matches from Apex
     * @returns {Array} Processed matches for display
     */
    processMatches(rawMatches) {
        if (!Array.isArray(rawMatches)) return [];
        
        return rawMatches.map(match => ({
            id: match.Id,
            name: match.Name,
            subtitle: match.Phone || match.Email || '',
            url: `/${match.Id}`
        }));
    }

    /**
     * Navigate to record (placeholder - implement based on your navigation strategy)
     * 
     * @param {string} recordId - Record ID to navigate to
     */
    navigateToRecord(recordId) {
        // Implement navigation logic based on your requirements
        // This could use NavigationMixin, window.open, or other navigation methods
        window.open(`/${recordId}`, '_blank');
    }

    /**
     * Handle errors with consistent user feedback
     * 
     * @param {string} title - Error title for user display
     * @param {Error} error - The actual error object
     */
    handleError(title, error) {
        console.error(`ConflictAlert: ${title}`, error);
        
        this.dispatchEvent(new ShowToastEvent({
            title,
            message: error.body?.message || error.message || 'An unexpected error occurred',
            variant: 'error',
            mode: 'dismissable'
        }));
    }

    /**
     * Show success toast message
     * 
     * @param {string} message - Success message
     */
    showSuccessToast(message) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Success',
            message,
            variant: 'success',
            mode: 'dismissable'
        }));
    }
}
