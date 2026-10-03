import { LightningElement, api } from 'lwc';

// Mirror of the Apex ClaimService state machine for instant UI affordances.
const NEXT = {
    New: ['Triage', 'Denied'],
    Triage: ['In Review', 'Denied'],
    'In Review': ['Approved', 'Denied'],
    Approved: ['Paid', 'Denied'],
    Paid: [],
    Denied: []
};

const STATUS_THEME = {
    New: 'badge badge_new',
    Triage: 'badge badge_triage',
    'In Review': 'badge badge_review',
    Approved: 'badge badge_approved',
    Paid: 'badge badge_paid',
    Denied: 'badge badge_denied'
};

export default class ClaimStatusCard extends LightningElement {
    @api claim;
    @api justUpdated = false; // parent flips this on real-time event to flash the card

    get badgeClass() {
        return STATUS_THEME[this.claim?.Status__c] || 'badge';
    }

    get cardClass() {
        return this.justUpdated ? 'card card_flash' : 'card';
    }

    get priorityClass() {
        return `pill pill_${(this.claim?.Priority__c || 'low').toLowerCase().replace(' ', '')}`;
    }

    get amountFormatted() {
        const amt = this.claim?.Claim_Amount__c;
        return amt == null
            ? '—'
            : new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD', maximumFractionDigits: 0 }).format(amt);
    }

    get policyholder() {
        return this.claim?.Policy__r?.Policyholder_Name__c || 'Unknown';
    }

    get policyNumber() {
        return this.claim?.Policy__r?.Policy_Number__c || '';
    }

    get adjuster() {
        return this.claim?.Adjuster__r?.Name || 'Unassigned';
    }

    get nextActions() {
        return (NEXT[this.claim?.Status__c] || []).map((s) => ({
            label: s,
            variant: s === 'Denied' ? 'destructive-text' : 'brand-outline'
        }));
    }

    get hasActions() {
        return this.nextActions.length > 0;
    }

    handleAdvance(event) {
        const newStatus = event.target.label;
        this.dispatchEvent(
            new CustomEvent('statuschange', {
                detail: { claimId: this.claim.Id, newStatus }
            })
        );
    }
}
