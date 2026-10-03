import { LightningElement, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getDashboardData from '@salesforce/apex/Claims360Controller.getDashboardData';
import updateClaimStatus from '@salesforce/apex/Claims360Controller.updateClaimStatus';

const CHANNEL = '/event/Claim_Status_Update__e';

export default class Claims360Dashboard extends LightningElement {
    kpi = { openCount: 0, highPriorityCount: 0, avgProcessingHours: 0, closedLast30: 0 };
    claims = [];
    isLive = false;
    isLoading = true;
    error;

    _wired;          // holds the wired result for refreshApex
    _subscription;   // empApi subscription handle
    _recentlyUpdated = new Set();

    // -------------------------------------------------------------- data wire
    @wire(getDashboardData)
    wiredDashboard(result) {
        this._wired = result;
        const { data, error } = result;
        if (data) {
            this.kpi = {
                openCount: data.openCount,
                highPriorityCount: data.highPriorityCount,
                avgProcessingHours: data.avgProcessingHours,
                closedLast30: data.closedLast30
            };
            this.claims = data.openClaims.map((c) => ({
                ...c,
                _flash: this._recentlyUpdated.has(c.Id)
            }));
            this.error = undefined;
        } else if (error) {
            this.error = this.reduceError(error);
        }
        this.isLoading = false;
    }

    // ------------------------------------------------- platform event stream
    async connectedCallback() {
        onError((err) => {
            // empApi-level errors (e.g. lost connection)
            // eslint-disable-next-line no-console
            console.error('empApi error', JSON.stringify(err));
            this.isLive = false;
        });
        try {
            this._subscription = await subscribe(CHANNEL, -1, (message) =>
                this.handleEvent(message)
            );
            this.isLive = true;
        } catch (e) {
            this.isLive = false;
        }
    }

    disconnectedCallback() {
        if (this._subscription) {
            unsubscribe(this._subscription);
            this._subscription = undefined;
        }
    }

    handleEvent(message) {
        const payload = message?.data?.payload || {};
        const claimId = payload.Claim_Id__c;
        if (claimId) {
            this._recentlyUpdated.add(claimId);
            // auto-clear the flash flag after the animation
            setTimeout(() => this._recentlyUpdated.delete(claimId), 1600);
        }
        this.toast(
            'Claim updated',
            `${payload.Claim_Number__c || 'A claim'} → ${payload.New_Status__c}`,
            'info'
        );
        // Pull fresh data so KPIs + ordering recompute server-side.
        refreshApex(this._wired);
    }

    // ------------------------------------------------------------ user action
    async handleStatusChange(event) {
        const { claimId, newStatus } = event.detail;
        try {
            await updateClaimStatus({ claimId, newStatus });
            // The platform event the update fires will refresh us, but refresh
            // immediately too so the acting user never waits on the bus.
            await refreshApex(this._wired);
        } catch (e) {
            this.toast('Could not update claim', this.reduceError(e), 'error');
        }
    }

    handleRefresh() {
        this.isLoading = true;
        refreshApex(this._wired).finally(() => (this.isLoading = false));
    }

    // ----------------------------------------------------------------- getters
    get hasClaims() {
        return this.claims && this.claims.length > 0;
    }

    get liveClass() {
        return this.isLive ? 'live-dot live-dot_on' : 'live-dot live-dot_off';
    }

    get liveLabel() {
        return this.isLive ? 'Live' : 'Reconnecting…';
    }

    // ----------------------------------------------------------------- helpers
    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    reduceError(error) {
        if (Array.isArray(error?.body)) {
            return error.body.map((e) => e.message).join(', ');
        }
        return error?.body?.message || error?.message || 'Unknown error';
    }
}
