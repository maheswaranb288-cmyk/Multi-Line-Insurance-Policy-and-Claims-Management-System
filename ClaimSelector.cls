/**
 * ClaimSelector
 * -------------------------------------------------------------------------
 * Selector layer: the ONLY place Claim__c SOQL lives. Centralising queries
 * keeps them bulk-safe, FLS-enforced, and easy to reuse/test.
 */
public with sharing class ClaimSelector {

    private static final String FIELDS =
        'Id, Name, Claim_Number__c, Status__c, Priority__c, Claim_Amount__c, ' +
        'Submitted_Date__c, Age_Days__c, Is_Open__c, Processing_Time_Hours__c, ' +
        'Last_Status_Change__c, Adjuster__c, Adjuster__r.Name, ' +
        'Policy__c, Policy__r.Policy_Number__c, Policy__r.Policyholder_Name__c, ' +
        'Policy__r.Policy_Type__c';

    /** Open claims (not Paid/Denied), highest priority + oldest first. */
    public List<Claim__c> selectOpenClaims(Integer rowLimit) {
        Integer lim = (rowLimit == null || rowLimit <= 0) ? 200 : rowLimit;
        String soql =
            'SELECT ' + FIELDS +
            ' FROM Claim__c' +
            ' WHERE Is_Open__c = true' +
            ' WITH SECURITY_ENFORCED' +
            ' ORDER BY Priority__c DESC, Submitted_Date__c ASC' +
            ' LIMIT :lim';
        return Database.query(soql);
    }

    public List<Claim__c> selectByIds(Set<Id> ids) {
        String soql = 'SELECT ' + FIELDS + ' FROM Claim__c WHERE Id IN :ids WITH SECURITY_ENFORCED';
        return Database.query(soql);
    }

    /** New claims awaiting automated triage. */
    public List<Claim__c> selectNewForTriage(Set<Id> ids) {
        return [
            SELECT Id, Claim_Amount__c, Status__c, Priority__c, Adjuster__c
            FROM Claim__c
            WHERE Id IN :ids AND Status__c = 'New'
            WITH SECURITY_ENFORCED
        ];
    }

    public List<Claim_Status_History__c> selectHistory(Id claimId) {
        return [
            SELECT Id, Old_Status__c, New_Status__c, Changed_At__c,
                   Changed_By__r.Name, Notes__c
            FROM Claim_Status_History__c
            WHERE Claim__c = :claimId
            WITH SECURITY_ENFORCED
            ORDER BY Changed_At__c DESC
            LIMIT 200
        ];
    }
}
