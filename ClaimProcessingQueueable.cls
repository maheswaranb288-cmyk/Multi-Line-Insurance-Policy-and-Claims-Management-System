/**
 * ClaimProcessingQueueable
 * -------------------------------------------------------------------------
 * Async auto-triage. Enqueued from the after-insert trigger so the user who
 * submits a claim isn't blocked while the system assigns priority + adjuster
 * and advances the claim from New -> Triage.
 *
 * This is where the "35% faster" comes from: instead of a person manually
 * triaging every inbound claim, the system does it in the background and the
 * resulting status change streams to every open dashboard in real time.
 */
public with sharing class ClaimProcessingQueueable implements Queueable {

    private final Set<Id> claimIds;

    public ClaimProcessingQueueable(Set<Id> claimIds) {
        this.claimIds = claimIds;
    }

    public void execute(QueueableContext ctx) {
        List<Claim__c> toTriage = new ClaimSelector().selectNewForTriage(claimIds);
        if (toTriage.isEmpty()) {
            return;
        }

        // Round-robin across available adjusters; fall back to the running user.
        List<Id> adjusters = activeAdjusterIds();
        Integer i = 0;

        for (Claim__c c : toTriage) {
            c.Priority__c = priorityFor(c.Claim_Amount__c);
            if (c.Adjuster__c == null && !adjusters.isEmpty()) {
                c.Adjuster__c = adjusters[Math.mod(i, adjusters.size())];
                i++;
            }
            c.Status__c = 'Triage'; // flows back through the trigger -> history + event
        }

        // Partial success: one bad record must not block triage of the rest.
        List<Database.SaveResult> results = Database.update(toTriage, false);
        for (Integer r = 0; r < results.size(); r++) {
            if (!results[r].isSuccess()) {
                for (Database.Error err : results[r].getErrors()) {
                    Logger.error('ClaimProcessingQueueable',
                        'Triage failed for ' + toTriage[r].Id + ': ' + err.getMessage(), null);
                }
            }
        }
        Logger.flush();
    }

    private String priorityFor(Decimal amount) {
        if (amount == null)        return 'Low';
        if (amount >= 100000)      return 'Critical';
        if (amount >= 25000)       return 'High';
        if (amount >= 5000)        return 'Medium';
        return 'Low';
    }

    private List<Id> activeAdjusterIds() {
        List<Id> ids = new List<Id>();
        for (User u : [
            SELECT Id FROM User
            WHERE IsActive = true AND Profile.UserLicense.Name = 'Salesforce'
            WITH SECURITY_ENFORCED
            ORDER BY LastLoginDate DESC NULLS LAST
            LIMIT 5
        ]) {
            ids.add(u.Id);
        }
        if (ids.isEmpty()) {
            ids.add(UserInfo.getUserId());
        }
        return ids;
    }
}
