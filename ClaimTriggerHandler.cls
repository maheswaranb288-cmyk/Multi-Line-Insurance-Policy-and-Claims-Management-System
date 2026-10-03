/**
 * ClaimTriggerHandler
 * -------------------------------------------------------------------------
 * Thin orchestration only. All real work is delegated to ClaimService
 * (synchronous logic) and ClaimProcessingQueueable (async triage).
 */
public with sharing class ClaimTriggerHandler extends TriggerHandler {

    private final ClaimService service = new ClaimService();

    protected override void afterInsert(Map<Id, SObject> newMap) {
        // Kick off async triage for newly created claims (only if async allowed).
        if (Limits.getLimitQueueableJobs() - Limits.getQueueableJobs() > 0) {
            System.enqueueJob(new ClaimProcessingQueueable(newMap.keySet()));
        }
    }

    protected override void beforeUpdate(Map<Id, SObject> newMap, Map<Id, SObject> oldMap) {
        service.onBeforeUpdate(
            (Map<Id, Claim__c>) newMap,
            (Map<Id, Claim__c>) oldMap
        );
    }

    protected override void afterUpdate(Map<Id, SObject> newMap, Map<Id, SObject> oldMap) {
        service.onAfterUpdate(
            (Map<Id, Claim__c>) newMap,
            (Map<Id, Claim__c>) oldMap
        );
    }
}
