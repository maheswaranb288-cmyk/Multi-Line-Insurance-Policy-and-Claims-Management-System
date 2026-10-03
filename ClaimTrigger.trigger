/**
 * The ONE and only trigger on Claim__c. No logic here by design.
 */
trigger ClaimTrigger on Claim__c (
    before insert, before update, before delete,
    after insert, after update, after delete, after undelete
) {
    new ClaimTriggerHandler().run();
}
