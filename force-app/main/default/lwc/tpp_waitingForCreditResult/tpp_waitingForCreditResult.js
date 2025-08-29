import { LightningElement, api, wire } from 'lwc';
import { FlowNavigationNextEvent } from 'lightning/flowSupport';
import { getRecordNotifyChange } from 'lightning/uiRecordApi';
import { refreshApex } from '@salesforce/apex';
import getDecisionAsMap from '@salesforce/apex/WaitingForCreditResultService.getDecisionAsMap';

export default class WaitingForCreditResult extends LightningElement {
    _parentAccountId;
    @api recordId;

    @api
    get parentAccountId() { return this._parentAccountId; }
    set parentAccountId(v) {
        this._parentAccountId = v;
        // FYI: wire will auto-refresh when this changes
        console.log('[WaitingForCreditResult] parentAccountId set:', v);
    }

    // Prefer parentAccountId, fall back to recordId
    get resolvedAccountId() {
        return this._parentAccountId ?? this.recordId ?? null;
    }

    wiredDecisionResult;
    intervalId;
    pollCount = 0;
    maxPolls = 5;            // Max attempts
    pollingInterval = 10000; // 10s
    initialDelay = 10000;    // 10s before first poll
    hasNavigated = false;

    @wire(getDecisionAsMap, { accountId: '$resolvedAccountId' })
    wiredDecision(result) {
        this.wiredDecisionResult = result;
        const { data, error } = result;

        if (data) {
            // Safely log
            try {
                console.log('[WaitingForCreditResult] Apex map result:', JSON.stringify(data));
            } catch (_) {
                console.log('[WaitingForCreditResult] Apex map result present (non-serializable).');
            }

            const creditDecision = data.creditDecision ?? null;

            // Adjust this predicate if you have other “non-final” markers like 'In Progress', 'Queued', etc.
            const isFinalDecision =
                creditDecision !== null &&
                creditDecision !== undefined &&
                String(creditDecision).trim() !== '' &&
                String(creditDecision).toLowerCase() !== 'pending';

            console.log('[WaitingForCreditResult] Polling… creditDecision:', creditDecision, 'isFinal:', isFinalDecision);

            if (isFinalDecision && !this.hasNavigated) {
                console.log('[WaitingForCreditResult] Decision found! Navigating…');
                this.stopPollingAndNavigate();
            }
        } else if (error) {
            console.error('[WaitingForCreditResult] Apex wire error:', error);
            // You can choose to stop polling on first error or keep trying.
            // Here we stop to avoid spamming; comment this next line if you prefer to keep polling.
            this.stopPolling();
        }
    }

    connectedCallback() {
        console.log('[WaitingForCreditResult] Connected. Starting initial delay…');
        // Wait the initial delay before polling
        setTimeout(() => {
            console.log('[WaitingForCreditResult] Initial delay finished. Starting polling.');
            this.startPolling();
        }, this.initialDelay);
    }

    startPolling() {
        console.log(`[WaitingForCreditResult] Polling started every ${this.pollingInterval}ms, max ${this.maxPolls} times`);
        this.intervalId = setInterval(() => {
            const id = this.resolvedAccountId;
            if (!id) {
                console.log('[WaitingForCreditResult] Poll tick skipped — no resolvedAccountId yet.');
                return;
            }

            this.pollCount++;
            console.log(`[WaitingForCreditResult] Poll #${this.pollCount}`);

            if (this.wiredDecisionResult) {
                console.log('[WaitingForCreditResult] Refreshing Apex data…');
                refreshApex(this.wiredDecisionResult);
                // Nudge LDS cache for this record as well
                getRecordNotifyChange([{ recordId: id }]);
            }

            if (this.pollCount >= this.maxPolls && !this.hasNavigated) {
                console.log('[WaitingForCreditResult] Max polls reached. Stopping and navigating.');
                this.stopPollingAndNavigate();
            }
        }, this.pollingInterval);
    }

    disconnectedCallback() {
        console.log('[WaitingForCreditResult] Disconnected. Stopping polling.');
        this.stopPolling();
    }

    stopPolling() {
        if (this.intervalId) {
            clearInterval(this.intervalId);
            this.intervalId = null;
            console.log('[WaitingForCreditResult] Polling stopped.');
        }
    }

    stopPollingAndNavigate() {
        if (!this.hasNavigated) {
            this.hasNavigated = true;
            this.stopPolling();
            this.dispatchEvent(new FlowNavigationNextEvent());
            console.log('[WaitingForCreditResult] Navigation event dispatched.');
        }
    }
}
