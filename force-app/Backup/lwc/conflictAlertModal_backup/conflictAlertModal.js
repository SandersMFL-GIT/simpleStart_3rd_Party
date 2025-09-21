import { api, track } from 'lwc';
import LightningModal from 'lightning/modal';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import findPotentialConflicts from '@salesforce/apex/ConflictAlertController.findPotentialConflicts';

/**
 * ConflictAlertModal Lightning Web Component
 * 
 * A modal component for displaying conflict alerts with potential matches.
 * Extends LightningModal for proper modal behavior and communication.
 * 
 * Features:
 * - Displays conflict messages with score information
 * - Shows potential matches with navigation capabilities
 * - Handles dismiss and close actions properly
 * - Provides loading states and error handling
 * 
 * @author Salesforce Development Team
 * @version 1.0
 */
export default class ConflictAlertModal extends NavigationMixin(LightningModal) {
    /**
     * Public API properties passed from parent component
     */
    @api message = '';
    @api score = '';
    @api accountId = '';

    /**
     * Component state management
     */
    @track loading = false;
    @track viewing = false;
    @track matches = [];
    @track error = null;
    @track showMatchesInline = false;

    /**
     * Component lifecycle - automatically load matches when modal opens
     */
    connectedCallback() {
        // Auto-load matches when component initializes
        if (this.accountId) {
            this.autoLoadMatches();
        }
    }

    /**
     * Automatically load potential matches without user interaction
     */
    async autoLoadMatches() {
        try {
            await this.loadPotentialMatches();
            this.showMatchesInline = true;
        } catch (error) {
            console.warn('Failed to auto-load matches:', error);
            // Don't show error toast for auto-load failure, just log it
        }
    }

    /**
     * CSS class for modal body based on loading state
     * @returns {string} CSS class string
     */
    get bodyClass() {
        return this.loading ? 'ca-busy' : '';
    }

    /**
     * Clean message display without embedded score information
     * Only shows matched fields (true values) to keep it simple
     * @returns {string} Formatted message text
     */
    get displayMessage() {
        if (!this.message) return 'Potential conflict detected';
        
        // Remove any "Score: N" lines and only show matched fields
        const msg = String(this.message).trim();
        const cleanMsg = msg.replace(/(^|\n)\s*Score\s*:\s*\d+\s*/gi, '').trim();
        
        // Filter out false values to only show what matched
        const lines = cleanMsg.split('\n');
        const matchedLines = lines.filter(line => {
            const trimmedLine = line.trim();
            if (!trimmedLine) return false;
            
            // Skip lines that explicitly show 'false'
            if (trimmedLine.toLowerCase().includes(': false')) return false;
            
            // Keep lines that show 'true' or don't have boolean values
            return true;
        });
        
        return matchedLines.join('\n').trim() || 'Potential conflict detected on this account.';
    }

    /**
     * Display score from either direct property or extracted from message
     * @returns {string|number} Score value for display
     */
    get displayScore() {
        // First check direct score property
        if (this.score !== null && this.score !== undefined && this.score !== '') {
            return this.score;
        }
        
        // Fallback: extract from message
        const scoreMatch = (this.message || '').match(/Score\s*:\s*(\d+)/i);
        return scoreMatch ? scoreMatch[1] : '';
    }

    /**
     * First line of message for prominent display (cleaned of boolean values)
     * @returns {string} Introduction line text
     */
    get introLine() {
        const msg = this.displayMessage || '';
               const firstLine = msg.split('\n')[0];
        
        if (!firstLine) return 'Potential conflict detected on this account.';
        
        // Clean up the first line by removing ': true' or ': false'
        const cleanLine = firstLine.replace(/:\s*(true|false)\s*$/, '');
        
        return cleanLine || 'Potential conflict detected on this account.';
    }

    /**
     * Remaining lines with formatted labels (only matched fields)
     * *** Simplified: no rich-text headers — return empty so nothing renders. ***
     * @returns {string} HTML formatted details
     */
    get detailsRich() {
        return ''; // no additional headers; we’re keeping UI simple
    }

    /**
     * Whether score should be displayed
     * @returns {boolean} True if score exists and is valid
     */
    get hasScore() {
        const s = this.displayScore;
        return s !== '' && s !== null && s !== undefined;
    }

    /**
     * Whether there are details to show beyond the intro line
     * *** Since detailsRich is empty, this is false to prevent the block from rendering. ***
     * @returns {boolean} True if additional details exist
     */
    get hasDetails() {
        return false;
    }

    /**
     * Loading message for accessibility
     * @returns {string} Appropriate loading message
     */
    get loadingMessage() {
        return this.viewing ? 'Loading potential matches...' : 'Processing request...';
    }

    /**
     * Text for matches count display
     * @returns {string} Formatted matches count text
     */
    get matchesCountText() {
        const count = this.matches.length;
        if (count === 0) return 'No matches found';
        if (count === 1) return 'Found 1 potential match';
        return `Found ${count} potential matches`;
    }

    /**
     * Text for the view matches link
     * @returns {string} Link text with context
     */
    get viewMatchesLinkText() {
        return 'View potential matches';
    }

    // ========== EVENT HANDLERS ==========

    /**
     * Handle dismiss button click
     * Returns 'dismiss' to parent component for proper handling
     */
    handleDismiss() {
        if (this.loading) return;
        
        this.loading = true;
        
        // Brief delay for visual feedback, then close with dismiss result
        setTimeout(() => {
            this.close('dismiss');
        }, 100);
    }

    /**
     * Handle close button click
     * Returns 'close' to parent component (no action taken)
     */
    handleClose() {
        if (this.loading) return;
        this.close('close');
    }

    /**
     * Handle view matches button click
     * Loads potential conflicts and shows them inline
     */
    async handleView() {
        if (this.loading) return;
        
        this.loading = true;
        this.error = null;
        
        try {
            await this.loadPotentialMatches();
            this.showMatchesInline = true;
            
            if (this.matches.length === 0) {
                this.showInfoToast('No Matches Found', 'No potential conflicts were found for this account.');
            }
        } catch (error) {
            this.handleError('Failed to load potential matches', error);
        } finally {
            this.loading = false;
        }
    }

    /**
     * Handle navigation to match record
     * 
     * @param {Event} event - Click event containing record ID
     */
    handleNav(event) {
        event.preventDefault();
        event.stopPropagation();
        
        if (this.loading) return;
        
        const recordId = event.currentTarget.dataset.id;
        if (!recordId) {
            this.handleError('Navigation Error', new Error('No record ID found'));
            return;
        }
        
        console.log('Navigating to record:', recordId);
        this.navigateToRecord(recordId);
    }

    /**
     * Handle back button from matches view
     */
    handleBack() {
        this.viewing = false;
        this.matches = [];
        this.error = null;
    }

    // ========== UTILITY METHODS ==========

    /**
     * Load potential matches from Apex controller
     * 
     * @throws {Error} When Apex call fails
     */
    async loadPotentialMatches() {
        if (!this.accountId) {
            throw new Error('Account ID is required to load potential matches');
        }
        
        const rawMatches = await findPotentialConflicts({ accountId: this.accountId });
        this.matches = this.processPotentialMatches(rawMatches || []);
    }

    /**
     * Process raw matches data for display
     * 
     * @param {Array} rawMatches - Raw matches from Apex
     * @returns {Array} Processed matches for display
     */
    processPotentialMatches(rawMatches) {
        if (!Array.isArray(rawMatches)) return [];
        
        return rawMatches.map((match, index) => ({
            id: match.Id || match.id || `match-${index}`,
            name: match.Name || match.name || 'Unknown',
            subtitle: this.buildMatchSubtitle(match),
            url: `/${match.Id || match.id}`
        }));
    }

    /**
     * Build subtitle for match display
     * NOTE: Show actual VALUES (not labels) directly under the name.
     * Order: Phone • Email • ZIP • Type (only if present). Dedupe and trim.
     * 
     * @param {Object} match - Match record
     * @returns {string} Formatted subtitle, e.g., "(555) 111-1001 • ct_e1@example.test • 80202 • Client"
     */
    buildMatchSubtitle(match) {
        const val = (v) => (v === null || v === undefined ? '' : String(v).trim());
        const phone = val(match.Phone || match.phone);
        const email = val(match.Email || match.email);
        const zip =
            val(
                match.MailingPostalCode ||
                match.BillingPostalCode ||
                match.PostalCode ||
                match.zip
            );
        const type = val(match.Type || match.type); // this is a value like "Client", not a label

        // Build list of non-empty values, keep order, remove dupes
        const seen = new Set();
        const parts = [phone, email, zip, type].filter((p) => {
            if (!p) return false;
            if (seen.has(p)) return false;
            seen.add(p);
            return true;
        });

        return parts.join(' • ');
    }

    /**
     * Navigate to a record using NavigationMixin
     * 
     * @param {string} recordId - Salesforce record ID
     */
    navigateToRecord(recordId) {
        console.log('NavigateToRecord called with:', recordId);
        
        // Try NavigationMixin first
        try {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: recordId,
                    actionName: 'view'
                }
            }).catch(navError => {
                console.warn('NavigationMixin failed:', navError);
                this.fallbackNavigation(recordId);
            });
        } catch (error) {
            console.warn('NavigationMixin not available:', error);
            this.fallbackNavigation(recordId);
        }
    }

    /**
     * Fallback navigation method
     * 
     * @param {string} recordId - Salesforce record ID
     */
    fallbackNavigation(recordId) {
        // First try opening in same tab
        try {
            window.location.href = `/${recordId}`;
        } catch (error) {
            // Last resort - open in new tab
            console.warn('Same tab navigation failed, opening new tab:', error);
            window.open(`/${recordId}`, '_blank');
        }
    }

    /**
     * Handle errors with consistent user feedback
     * 
     * @param {string} title - Error title
     * @param {Error} error - Error object
     */
    handleError(title, error) {
        console.error(`ConflictAlertModal: ${title}`, error);
        
        this.error = {
            title,
            message: error.body?.message || error.message || 'An unexpected error occurred'
        };
        
        this.dispatchEvent(new ShowToastEvent({
            title,
            message: this.error.message,
            variant: 'error',
            mode: 'dismissable'
        }));
    }

    /**
     * Show informational toast message
     * 
     * @param {string} title - Toast title
     * @param {string} message - Toast message
     */
    showInfoToast(title, message) {
        this.dispatchEvent(new ShowToastEvent({
            title,
            message,
            variant: 'info',
            mode: 'dismissable'
        }));
    }

    /**
     * Show success toast message
     * 
     * @param {string} title - Toast title
     * @param {string} message - Toast message
     */
    showSuccessToast(title, message) {
        this.dispatchEvent(new ShowToastEvent({
            title,
            message,
            variant: 'success',
            mode: 'dismissable'
        }));
    }
}
