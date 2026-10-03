/**
 * Claims360Controller
 * -------------------------------------------------------------------------
 * Backs the claims360Dashboard LWC. Returns aggregated KPIs + the open-claims
 * list, and lets the UI advance a claim's status (which fires the platform
 * event that pushes the change to every other open dashboard).
 */
public with sharing class Claims360Controller {

    // ------------------------------------------------------------------ data
    @AuraEnabled(cacheable=true)
    public static DashboardData getDashboardData() {
        try {
            DashboardData data = new DashboardData();
            data.openClaims = new ClaimSelector().selectOpenClaims(200);

            // KPIs.
            data.openCount = data.openClaims.size();
            Integer critical = 0;
            for (Claim__c c : data.openClaims) {
                if (c.Priority__c == 'Critical' || c.Priority__c == 'High') {
                    critical++;
                }
            }
            data.highPriorityCount = critical;

            // Average cycle time across claims closed in the last 30 days.
            AggregateResult[] agg = [
                SELECT AVG(Processing_Time_Hours__c) avgHrs, COUNT(Id) closed
                FROM Claim__c
                WHERE Is_Open__c = false
                AND Last_Status_Change__c = LAST_N_DAYS:30
                WITH SECURITY_ENFORCED
            ];
            Decimal avgHrs = (Decimal) agg[0].get('avgHrs');
            data.avgProcessingHours = avgHrs == null ? 0 : avgHrs.setScale(1);
            data.closedLast30 = (Integer) agg[0].get('closed');

            return data;
        } catch (Exception e) {
            throw new AuraHandledException('Could not load dashboard: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Claim_Status_History__c> getClaimHistory(Id claimId) {
        try {
            return new ClaimSelector().selectHistory(claimId);
        } catch (Exception e) {
            throw new AuraHandledException('Could not load history: ' + e.getMessage());
        }
    }

    // ----------------------------------------------------------------- action
    @AuraEnabled
    public static Claim__c updateClaimStatus(Id claimId, String newStatus) {
        try {
            // FLS check before DML.
            if (!Schema.sObjectType.Claim__c.fields.Status__c.isUpdateable()) {
                throw new AuraHandledException('You do not have permission to update claim status.');
            }
            Claim__c c = new Claim__c(Id = claimId, Status__c = newStatus);
            update c; // trigger validates the transition + emits history/event
            return new ClaimSelector().selectByIds(new Set<Id>{ claimId })[0];
        } catch (DmlException e) {
            // Surface the trigger's transition-validation message cleanly.
            throw new AuraHandledException(e.getDmlMessage(0));
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ---------------------------------------------------------------- wrapper
    public class DashboardData {
        @AuraEnabled public List<Claim__c> openClaims;
        @AuraEnabled public Integer openCount;
        @AuraEnabled public Integer highPriorityCount;
        @AuraEnabled public Decimal avgProcessingHours;
        @AuraEnabled public Integer closedLast30;
    }
}
