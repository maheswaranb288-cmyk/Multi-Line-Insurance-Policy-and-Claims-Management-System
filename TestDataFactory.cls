/**
 * TestDataFactory
 * -------------------------------------------------------------------------
 * One place to build test records so test classes describe behavior, not
 * record construction. See Week 4 of the content plan.
 */
@isTest
public class TestDataFactory {

    public static Policy__c policy() {
        return policy(true);
    }

    public static Policy__c policy(Boolean doInsert) {
        Policy__c p = new Policy__c(
            Name                 = 'Test Policy',
            Policy_Number__c     = 'POL-' + uniqueSuffix(),
            Policyholder_Name__c = 'Jordan Rivera',
            Policy_Type__c       = 'Auto',
            Status__c            = 'Active',
            Effective_Date__c    = Date.today().addMonths(-6),
            Premium_Amount__c    = 1200
        );
        if (doInsert) {
            insert p;
        }
        return p;
    }

    public static Claim__c claim(Id policyId, Decimal amount, Boolean doInsert) {
        Claim__c c = new Claim__c(
            Claim_Number__c = 'CN-' + uniqueSuffix(),
            Policy__c       = policyId,
            Status__c       = 'New',
            Claim_Amount__c = amount,
            Submitted_Date__c = Date.today()
        );
        if (doInsert) {
            insert c;
        }
        return c;
    }

    public static List<Claim__c> claims(Id policyId, Integer count) {
        List<Claim__c> list = new List<Claim__c>();
        for (Integer i = 0; i < count; i++) {
            list.add(claim(policyId, 1000 * (i + 1), false));
        }
        insert list;
        return list;
    }

    private static Integer counter = 0;
    private static String uniqueSuffix() {
        counter++;
        return String.valueOf(Datetime.now().getTime()) + '-' + counter;
    }
}
