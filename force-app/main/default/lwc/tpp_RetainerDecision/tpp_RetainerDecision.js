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
    quotedRetainer;   // standard retainer (full)
    reducedRetainer;  // discounted retainer (if Apex provided one)
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
            // optional: surface to UI/toast
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

    /*** --- State getters --- ***/
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
        // show full-retainer view when explicitly "Full Retainer"
        // OR when not in a qualified discount tier and not frozen
        return (
            this.creditDecision === 'Full Retainer' ||
            (!this.isQualified && !this.showFrozen)
        );
    }

    /*** --- Calculations --- ***/
    // Standard/full retainer:
    // 1) If Apex gave us quotedRetainer, prefer it.
    // 2) Else infer from reducedRetainer + discount (except Gold 0% which would divide by zero).
    get standardRetainer() {
        if (this.quotedRetainer != null) return this.quotedRetainer;

        const discount = DISCOUNTS[this.creditDecision];
        if (typeof discount === 'number') {
            if (discount === 0) {
                // Gold 0%: can’t infer standard from reduced (always 0); fall back to 0
                return 0;
            }
            if (this.reducedRetainer != null) {
                return this.reducedRetainer / discount;
            }
        }
        return 0;
    }

    // Reduced/discounted retainer for display:
    // 1) If Gold 0%, always 0
    // 2) If we have a discount & standard, compute standard*discount
    // 3) Else fall back to Apex’s reducedRetainer (if present)
    get reducedRetainerDisplay() {
        if (this.creditDecision === 'Gold - 0% Retainer') return 0;

        const discount = DISCOUNTS[this.creditDecision];
        if (typeof discount === 'number' && this.standardRetainer) {
            return this.standardRetainer * discount;
        }
        return this.reducedRetainer != null ? this.reducedRetainer : 0;
    }
}
