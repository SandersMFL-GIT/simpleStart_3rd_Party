import { LightningElement, api, wire } from 'lwc';
import SimpleStartCongrats from '@salesforce/resourceUrl/SimpleStartCongrats';
import SimpleStartFamilyLaw from '@salesforce/resourceUrl/SimpleStartFamilyLaw';
import getDecisionWithLink from '@salesforce/apex/WaitingForCreditResultService.getDecisionWithLink';

const DISCOUNTS = {
    'Gold - 0% Retainer': 0,
    'Silver - 50% Retainer': 0.5,
    'Bronze - 80% Retainer': 0.8
};

export default class SsRetainerDecision extends LightningElement {
    /** Pass the PARENT account id here (not the third-party id) */
    @api parentAccountId;

    // Returned from Apex (DecisionResult)
    creditDecision;
    quotedRetainer;   // (may be present, but we won't calculate with it)
    reducedRetainer;  // **this is the only amount we display**
    accountName;

    /*** --- Apex wire --- ***/
    @wire(getDecisionWithLink, { accountId: '$parentAccountId' })
    wiredDecision({ data, error }) {
        if (data) {
            this.creditDecision  = data.creditDecision || null;
            this.quotedRetainer  = data.quotedRetainer ?? null;
            this.reducedRetainer = data.reducedRetainer ?? null;
            this.accountName     = data.accountName || '';
            this.updateBackgroundImages();
        } else if (error) {
            // eslint-disable-next-line no-console
            console.error('[SsRetainerDecision] getDecisionWithLink error:', error);
        }
    }

    renderedCallback() {
        this.updateBackgroundImages();
    }

    updateBackgroundImages() {
        const imageSection = this.template.querySelector('.image-section');
        if (imageSection) {
            imageSection.style.backgroundImage = `url('${SimpleStartCongrats}')`;
        }
        const familyLawImage = this.template.querySelector('.family-law-image');
        if (familyLawImage) {
            familyLawImage.style.backgroundImage = `url('${SimpleStartFamilyLaw}')`;
        }
    }

    /*** --- State getters (unchanged UI logic) --- ***/
    get isQualified() {
        return Object.prototype.hasOwnProperty.call(DISCOUNTS, this.creditDecision);
    }
    get showFrozen() {
        return this.creditDecision === 'Credit Frozen';
    }
    get showFailed() {
        return this.creditDecision === 'Failed- Follow up with PC';
    }
    get showFull() {
        return (
            this.creditDecision === 'Full Retainer' ||
            (!this.isQualified && !this.showFrozen)
        );
    }

    /*** --- Amount to display (ONLY reduced retainer) --- ***/
    get reducedRetainerDisplay() {
        // Gold is always $0 by definition
        if (this.creditDecision === 'Gold - 0% Retainer') return 0;

        // Show exactly what Apex returned as reduced retainer.
        // If Apex didn’t provide it, fall back to quotedRetainer; otherwise 0.
        return this.reducedRetainer != null
            ? this.reducedRetainer
            : (this.quotedRetainer ?? 0);
    }
    get showFrozenAmount() {
        return this.showFrozen && this.quotedRetainer != null;
    }
    get frozenRetainerDisplay() {
        // fall back to 0 if Apex didn’t send quotedRetainer
        return this.quotedRetainer ?? 0;
    }
}
