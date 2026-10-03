/**
 * ClaimService
 * -------------------------------------------------------------------------
 * Service layer: all Claim__c business logic lives here. Bulkified end to end.
 *
 * Responsibilities:
 *   1. Validate status transitions (state machine).
 *   2. Stamp Last_Status_Change__c and Processing_Time_Hours__c on change.
 *   3. Write an immutable Claim_Status_History__c row per transition,
 *      IN-TRANSACTION (all-or-none) for FinTech auditability.
 *   4. Publish a Claim_Status_Update__e platform event per transition so the
 *      claims360Dashboard updates in real time with no polling.
 */
public with sharing class ClaimService {

    private static final Set<String> TERMINAL = new Set<String>{ 'Paid', 'Denied' };

    // Allowed state machine. Key = current status, value = set of legal next statuses.
    private static final Map<String, Set<String>> ALLOWED = new Map<String, Set<String>>{
        'New'       => new Set<String>{ 'Triage', 'Denied' },
        'Triage'    => new Set<String>{ 'In Review', 'Denied' },
        'In Review' => new Set<String>{ 'Approved', 'Denied' },
        'Approved'  => new Set<String>{ 'Paid', 'Denied' },
        'Paid'      => new Set<String>(),
        'Denied'    => new Set<String>()
    };

    // -----------------------------------------------------------------------
    // BEFORE UPDATE: validate transitions and stamp timing fields in-place.
    // -----------------------------------------------------------------------
    public void onBeforeUpdate(Map<Id, Claim__c> newMap, Map<Id, Claim__c> oldMap) {
        for (Claim__c rec : newMap.values()) {
            Claim__c prior = oldMap.get(rec.Id);
            if (rec.Status__c == prior.Status__c) {
                continue;
            }

            // Validate the transition against the state machine.
            Set<String> legal = ALLOWED.get(prior.Status__c);
            if (legal == null || !legal.contains(rec.Status__c)) {
                rec.Status__c.addError(
                    'Illegal status transition: "' + prior.Status__c +
                    '" -> "' + rec.Status__c + '". Allowed next: ' +
                    (legal == null || legal.isEmpty() ? 'none (terminal state)' : String.join(new List<String>(legal), ', '))
                );
                continue;
            }

            // Stamp the change time.
            rec.Last_Status_Change__c = System.now();

            // Capture cycle time when the claim reaches a terminal status.
            if (TERMINAL.contains(rec.Status__c) && rec.Processing_Time_Hours__c == null) {
                Long ms = System.now().getTime() - prior.CreatedDate.getTime();
                rec.Processing_Time_Hours__c = ((Decimal) ms / (1000 * 60 * 60)).setScale(2);
            }
        }
    }

    // -----------------------------------------------------------------------
    // AFTER UPDATE: persist audit history + broadcast real-time events.
    // -----------------------------------------------------------------------
    public void onAfterUpdate(Map<Id, Claim__c> newMap, Map<Id, Claim__c> oldMap) {
        List<Claim_Status_History__c> history = new List<Claim_Status_History__c>();
        List<Claim_Status_Update__e>  events  = new List<Claim_Status_Update__e>();

        for (Claim__c rec : newMap.values()) {
            Claim__c prior = oldMap.get(rec.Id);
            if (rec.Status__c == prior.Status__c) {
                continue;
            }

            history.add(new Claim_Status_History__c(
                Claim__c      = rec.Id,
                Old_Status__c = prior.Status__c,
                New_Status__c = rec.Status__c,
                Changed_By__c = UserInfo.getUserId(),
                Changed_At__c = System.now(),
                Notes__c      = 'Transition via ' + resolveSource()
            ));

            events.add(new Claim_Status_Update__e(
                Claim_Id__c       = rec.Id,
                Claim_Number__c   = rec.Name,
                Old_Status__c     = prior.Status__c,
                New_Status__c     = rec.Status__c,
                Priority__c       = rec.Priority__c,
                Changed_By__c     = UserInfo.getName(),
                Message__c        = rec.Name + ' moved to ' + rec.Status__c
            ));
        }

        if (history.isEmpty()) {
            return;
        }

        // All-or-none: in FinTech, the audit row and the data change must commit
        // together. If history can't be written, the whole transaction fails.
        insert history;

        // Platform events fire AFTER commit (PublishAfterCommit), so they will
        // only reach subscribers if the audit row above committed successfully.
        if (!events.isEmpty()) {
            List<Database.SaveResult> results = EventBus.publish(events);
            for (Database.SaveResult sr : results) {
                if (!sr.isSuccess()) {
                    for (Database.Error err : sr.getErrors()) {
                        Logger.warn('ClaimService.publish', err.getMessage());
                    }
                }
            }
            Logger.flush();
        }
    }

    private String resolveSource() {
        return System.isFuture() || System.isQueueable() || System.isBatch()
            ? 'automated process'
            : 'user';
    }
}
