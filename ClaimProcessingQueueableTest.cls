/**
 * ClaimProcessingQueueableTest
 * -------------------------------------------------------------------------
 * Demonstrates the startTest/stopTest trick: the Queueable enqueued during
 * insert only runs when Test.stopTest() flushes the async queue. Asserting
 * before stopTest would fail.
 */
@isTest
private class ClaimProcessingQueueableTest {

    @isTest
    static void newClaim_isAutoTriaged() {
        Policy__c p = TestDataFactory.policy();

        Test.startTest();
        Claim__c c = TestDataFactory.claim(p.Id, 60000, true); // High band
        Test.stopTest(); // flushes the async triage job synchronously

        Claim__c result = [SELECT Status__c, Priority__c, Adjuster__c FROM Claim__c WHERE Id = :c.Id];
        System.assertEquals('Triage', result.Status__c, 'New claim should be auto-advanced to Triage');
        System.assertEquals('High', result.Priority__c, '60k claim should be High priority');
        System.assertNotEquals(null, result.Adjuster__c, 'An adjuster should be auto-assigned');
    }

    @isTest
    static void priorityBands_mapCorrectly() {
        Policy__c p = TestDataFactory.policy();

        Test.startTest();
        Claim__c low      = TestDataFactory.claim(p.Id, 1000,   true);
        Claim__c critical = TestDataFactory.claim(p.Id, 250000, true);
        Test.stopTest();

        Map<Id, Claim__c> byId = new Map<Id, Claim__c>(
            [SELECT Priority__c FROM Claim__c WHERE Id IN (:low.Id, :critical.Id)]
        );
        System.assertEquals('Low', byId.get(low.Id).Priority__c);
        System.assertEquals('Critical', byId.get(critical.Id).Priority__c);
    }
}
