import { LightningElement, api, wire } from 'lwc';
import getSigningUrl from '@salesforce/apex/AdobeSignUtils.getSigningUrl';

export default class AdobeSignWebForm extends LightningElement {
    @api agreementId;
    signingUrl;
    error;

    @wire(getSigningUrl, { agreementId: '$agreementId' })
    wiredSigningUrl({ error, data }) {
        if (data) {
            this.signingUrl = data;
            this.error = undefined;
        } else if (error) {
            this.signingUrl = undefined;
            this.error = error.body ? error.body.message : error.message;
        }
    }
}
