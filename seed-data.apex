/**
 * UPC-360 seed data — run via:
 *   sf apex run --file scripts/apex/seed-data.apex
 *
 * Creates policies + claims so the dashboard has live data to screenshot.
 * Triggers will auto-triage the new claims asynchronously; wait a few seconds
 * and refresh the dashboard to watch statuses move in real time.
 */
List<Policy__c> policies = new List<Policy__c>();
String[] holders = new String[]{
    'Jordan Rivera','Priya Natarajan','Marcus Bell','Wei Chen','Sofia Alvarez',
    'Daniel Okafor','Hana Suzuki','Liam O''Connor','Amara Diallo','Noah Schmidt'
};
String[] types = new String[]{ 'Auto','Homeowners','Health','Life','Commercial' };

for (Integer i = 0; i < holders.size(); i++) {
    policies.add(new Policy__c(
        Name                 = 'Policy ' + (i + 1),
        Policy_Number__c     = 'POL-' + (10000 + i),
        Policyholder_Name__c = holders[i],
        Policy_Type__c       = types[Math.mod(i, types.size())],
        Status__c            = 'Active',
        Effective_Date__c    = Date.today().addMonths(-(Math.mod(i, 12) + 1)),
        Premium_Amount__c    = 800 + (i * 150)
    ));
}
insert policies;

Decimal[] amounts = new Decimal[]{ 1200, 7500, 32000, 110000, 4200, 88000, 15000, 260000, 600, 21000 };
List<Claim__c> claims = new List<Claim__c>();
for (Integer i = 0; i < policies.size(); i++) {
    claims.add(new Claim__c(
        Claim_Number__c   = 'CN-' + (50000 + i),
        Policy__c         = policies[i].Id,
        Status__c         = 'New',
        Claim_Amount__c   = amounts[i],
        Submitted_Date__c = Date.today().addDays(-Math.mod(i, 9))
    ));
}
insert claims;

System.debug('Seeded ' + policies.size() + ' policies and ' + claims.size() +
    ' claims. Async triage will advance them to Triage shortly.');
