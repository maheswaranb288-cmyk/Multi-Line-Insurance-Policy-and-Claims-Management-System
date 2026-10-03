/**
 * TriggerHandler
 * -------------------------------------------------------------------------
 * Lightweight base class that gives every object exactly ONE trigger whose
 * only job is to delegate to a handler. Business logic never lives in the
 * trigger body. Override only the contexts you need.
 *
 * Also provides a simple per-instance bypass so async / data-load jobs can
 * suppress handler logic when they need to.
 *
 * Usage:
 *   trigger ClaimTrigger on Claim__c (before insert, before update,
 *                                     after insert, after update) {
 *       new ClaimTriggerHandler().run();
 *   }
 */
public virtual class TriggerHandler {

    // Names of handlers that should be skipped this transaction.
    @TestVisible
    private static Set<String> bypassedHandlers = new Set<String>();

    public void run() {
        if (!Trigger.isExecuting) {
            // Allows the handler to be unit-tested via runForTest(...) without
            // a real DML trigger context.
            return;
        }
        if (isBypassed(getHandlerName())) {
            return;
        }

        switch on Trigger.operationType {
            when BEFORE_INSERT  { beforeInsert(Trigger.new); }
            when BEFORE_UPDATE  { beforeUpdate(Trigger.newMap, Trigger.oldMap); }
            when BEFORE_DELETE  { beforeDelete(Trigger.oldMap); }
            when AFTER_INSERT   { afterInsert(Trigger.newMap); }
            when AFTER_UPDATE   { afterUpdate(Trigger.newMap, Trigger.oldMap); }
            when AFTER_DELETE   { afterDelete(Trigger.oldMap); }
            when AFTER_UNDELETE { afterUndelete(Trigger.newMap); }
        }
    }

    // ---- Context hooks (override what you need) ----------------------------
    protected virtual void beforeInsert(List<SObject> newRecords) {}
    protected virtual void beforeUpdate(Map<Id, SObject> newMap, Map<Id, SObject> oldMap) {}
    protected virtual void beforeDelete(Map<Id, SObject> oldMap) {}
    protected virtual void afterInsert(Map<Id, SObject> newMap) {}
    protected virtual void afterUpdate(Map<Id, SObject> newMap, Map<Id, SObject> oldMap) {}
    protected virtual void afterDelete(Map<Id, SObject> oldMap) {}
    protected virtual void afterUndelete(Map<Id, SObject> newMap) {}

    // ---- Bypass API -------------------------------------------------------
    public static void bypass(String handlerName) { bypassedHandlers.add(handlerName); }
    public static void clearBypass(String handlerName) { bypassedHandlers.remove(handlerName); }
    public static Boolean isBypassed(String handlerName) { return bypassedHandlers.contains(handlerName); }
    public static void clearAllBypasses() { bypassedHandlers.clear(); }

    private String getHandlerName() {
        return String.valueOf(this).split(':')[0];
    }
}
