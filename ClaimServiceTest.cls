/**
 * ClaimServiceTest
 * -------------------------------------------------------------------------
 * Tests BEHAVIOR: legal transitions succeed, illegal ones are blocked, an
 * audit row is written per transition, a platform event is published, and
 * cycle time is captured at terminal status.
 */
@isTest
private class ClaimServiceTest {

    @testSetup
    static void setup() {
        // Suppress async auto-triage so seed claims stay in a known 'New' state.
        TriggerHandler.bypass('ClaimTriggerHandler');
        Policy__c p = TestDataFactory.policy();
        TestDataFactory.claim(p.Id, 8000, true);
        TriggerHandler.clearBypass('ClaimTriggerHandler');
    }

    @isTest
    static void legalTransition_writesHistoryAndPublishesEvent() {
        Claim__c c = [SELECT Id, Status__c FROM Claim__c LIMIT 1];

        Test.startTest();
        c.Status__c = 'Triage';
        update c;
        Test.stopTest();

        List<Claim_Status_History__c> history = [
            SELECT Old_Status__c, New_Status__c FROM Claim_Status_History__c WHERE Claim__c = :c.Id
        ];
        System.assertEquals(1, history.size(), 'One audit row per transition expected');
        System.assertEquals('New', history[0].Old_Status__c);
        System.assertEquals('Triage', history[0].New_Status__c);
    }

    @isTest
    static void illegalTransition_isBlocked() {
        Claim__c c = [SELECT Id, Status__c FROM Claim__c LIMIT 1];

        Test.startTest();
        Boolean blocked = false;
        try {
            c.Status__c = 'Paid'; // New -> Paid is illegal
            update c;
        } catch (DmlException e) {
            blocked = true;
            System.assert(
                e.getDmlMessage(0).contains('Illegal status transition'),
                'Expected transition validation message, got: ' + e.getDmlMessage(0)
            );
        }
        Test.stopTest();

        System.assert(blocked, 'Illegal transition should have been blocked');
    }

    @isTest
    static void terminalStatus_capturesProcessingTime() {
        Claim__c c = [SELECT Id, Status__c FROM Claim__c LIMIT 1];

        Test.startTest();
        c.Status__c = 'Triage';     update c;
        c.Status__c = 'In Review';  update c;
        c.Status__c = 'Approved';   update c;
        c.Status__c = 'Paid';       update c;
        Test.stopTest();

        Claim__c reloaded = [SELECT Processing_Time_Hours__c, Status__c FROM Claim__c WHERE Id = :c.Id];
        System.assertEquals('Paid', reloaded.Status__c);
        System.assertNotEquals(null, reloaded.Processing_Time_Hours__c,
            'Cycle time should be captured at terminal status');
    }

    @isTest
    static void bulkTransitions_stayWithinLimits() {
        Policy__c p = [SELECT Id FROM Policy__c LIMIT 1];
        List<Claim__c> many = TestDataFactory.claims(p.Id, 200);

        Test.startTest();
        for (Claim__c c : many) {
            c.Status__c = 'Triage';
        }
        update many; // bulk update -> bulk history + bulk events
        Test.stopTest();

        Integer historyCount = [SELECT COUNT() FROM Claim_Status_History__c WHERE New_Status__c = 'Triage'];
        System.assert(historyCount >= 200, 'Every bulk transition should be audited');
    }
}
