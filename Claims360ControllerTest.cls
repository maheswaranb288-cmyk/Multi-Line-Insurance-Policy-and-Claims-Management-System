/**
 * Claims360ControllerTest
 * -------------------------------------------------------------------------
 * Covers the LWC-facing controller: dashboard aggregation, status update
 * (incl. the validation error path), and history retrieval.
 */
@isTest
private class Claims360ControllerTest {

    @testSetup
    static void setup() {
        // Bypass the Claim trigger handler during seeding so the async
        // auto-triage queueable never reshuffles status/priority. This keeps
        // the seed claims pinned at 'New' and makes every assertion below
        // deterministic regardless of org-side automation.
        TriggerHandler.bypass('ClaimTriggerHandler');
        Policy__c p = TestDataFactory.policy();
        TestDataFactory.claims(p.Id, 3);
        TriggerHandler.clearBypass('ClaimTriggerHandler');
    }

    @isTest
    static void getDashboardData_returnsKpisAndOpenClaims() {
        Test.startTest();
        Claims360Controller.DashboardData data = Claims360Controller.getDashboardData();
        Test.stopTest();

        System.assert(data.openCount >= 3, 'Should report open claims');
        System.assertNotEquals(null, data.avgProcessingHours);
        System.assertEquals(data.openCount, data.openClaims.size());
    }

    @isTest
    static void updateClaimStatus_advancesClaim() {
        Claim__c c = [SELECT Id, Status__c FROM Claim__c LIMIT 1];

        Test.startTest();
        Claim__c updated = Claims360Controller.updateClaimStatus(c.Id, 'Triage');
        Test.stopTest();

        System.assertEquals('Triage', updated.Status__c);
    }

    @isTest
    static void updateClaimStatus_illegalTransition_throwsHandled() {
        Claim__c c = [SELECT Id FROM Claim__c LIMIT 1];

        Test.startTest();
        Boolean thrown = false;
        try {
            Claims360Controller.updateClaimStatus(c.Id, 'Paid'); // illegal from New
        } catch (AuraHandledException e) {
            thrown = true;
        }
        Test.stopTest();

        System.assert(thrown, 'Illegal transition should raise an AuraHandledException');
    }

    @isTest
    static void getClaimHistory_returnsRows() {
        Claim__c c = [SELECT Id FROM Claim__c LIMIT 1];
        update new Claim__c(Id = c.Id, Status__c = 'Triage');

        Test.startTest();
        List<Claim_Status_History__c> history = Claims360Controller.getClaimHistory(c.Id);
        Test.stopTest();

        System.assert(!history.isEmpty(), 'History should contain the recorded transition');
    }
}
