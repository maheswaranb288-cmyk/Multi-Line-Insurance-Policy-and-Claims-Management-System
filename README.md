# UPC-360 : Unified Policyholder Claims 360

A real-time insurance claims processing dashboard for Salesforce, built on
**Lightning Web Components + Platform Events**. Claims are auto-triaged the
moment they're submitted, every status change is broadcast over the event bus,
and every open dashboard updates **live: with zero polling**.

> The architecture that took claims processing from manual, refresh-driven
> reviews to an event-driven pipeline — cutting hands-on processing time ~35%
> by removing the two slowest steps: manual triage and status polling.

---

## Why it's faster

Traditional claims queues lose time in two invisible places:

1. **Manual triage** — a person opens each new claim, sets priority, assigns an
   adjuster. UPC-360 does this asynchronously the instant a claim is created.
2. **Status polling** — adjusters and managers refresh to see what changed.
   UPC-360 pushes every transition over a Platform Event, so the UI reflects
   reality the moment it changes.

Remove those two and the human only spends time on the decision that actually
needs a human: approve, review, or deny.

---

## Architecture

```
  New Claim (UI / API / data load)
          │
          ▼
   ClaimTrigger  ──►  ClaimTriggerHandler (extends TriggerHandler)
          │                     │ after insert
          │                     ▼
          │           ClaimProcessingQueueable  ── async auto-triage
          │             • priority by amount      (sets Priority, Adjuster,
          │             • round-robin adjuster     status → Triage)
          │                     │ Database.update(partial success)
          │                     ▼
          └──────────►  before update: ClaimService.onBeforeUpdate()
                           • validate state machine (illegal → addError)
                           • stamp Last_Status_Change__c
                           • capture Processing_Time_Hours__c at terminal
                                 │
                                 ▼
                        after update: ClaimService.onAfterUpdate()
                           • insert Claim_Status_History__c   (in-transaction,
                             all-or-none → FinTech audit)
                           • EventBus.publish(Claim_Status_Update__e)
                                 │  (PublishAfterCommit)
                                 ▼
                  ┌──────────────────────────────────────┐
                  │  /event/Claim_Status_Update__e        │
                  └──────────────────────────────────────┘
                                 │ lightning/empApi subscribe
                                 ▼
                     claims360Dashboard (LWC)
                       • refreshApex() → KPIs recompute
                       • flashes the affected card
                       • toast notification
```

### Layered design (one responsibility each)

| Layer | Class | Responsibility |
|-------|-------|----------------|
| Trigger | `ClaimTrigger` | Delegates only. No logic. |
| Handler | `ClaimTriggerHandler` | Routes context → service / async. |
| Service | `ClaimService` | State machine, audit history, event publishing. |
| Selector | `ClaimSelector` | All Claim SOQL, FLS-enforced. |
| Async | `ClaimProcessingQueueable` | Auto-triage, priority, assignment. |
| Controller | `Claims360Controller` | `@AuraEnabled` API for the LWC. |
| Logging | `Logger` + `Apex_Log__c` | Persistent logs that survive async. |

---

## Data model

- **Policy__c** — policyholder, type, status, premium. `Policy_Number__c` is a
  unique External ID.
- **Claim__c** — amount, status, priority, adjuster, submitted date. Formula
  fields `Age_Days__c` and `Is_Open__c`; cycle-time captured in
  `Processing_Time_Hours__c`.
- **Claim_Status_History__c** — immutable audit row per transition (master-detail
  to Claim).
- **Claim_Status_Update__e** — high-volume Platform Event, `PublishAfterCommit`.
- **Apex_Log__c** — persistent application log.

### Claim state machine

```
New ─► Triage ─► In Review ─► Approved ─► Paid
 │        │          │            │
 └────────┴──────────┴────────────┴────► Denied
```
Any other transition is rejected in `ClaimService.onBeforeUpdate()` with a
clear error.

---

## Deploy

Requires the Salesforce CLI (`sf`).

```bash
# 1. Authorize a dev/scratch org
sf org login web --alias upc360

# 2. Deploy source
sf project deploy start --target-org upc360

# 3. Assign the permission set
sf org assign permset --name UPC_360_User --target-org upc360

# 4. Seed demo data (auto-triage runs async — wait a few seconds)
sf apex run --file scripts/apex/seed-data.apex --target-org upc360

# 5. Open the org and add the "UPC-360 Claims Command Center" component
#    to a Lightning App / Home page via the Lightning App Builder.
sf org open --target-org upc360
```

> Older CLI? Swap in `sfdx force:source:deploy -p force-app`,
> `sfdx force:user:permset:assign -n UPC_360_User`, and
> `sfdx force:apex:execute -f scripts/apex/seed-data.apex`.

### See it live
Open the dashboard in two browser windows. Advance a claim in one — the other
updates instantly via the Platform Event. No refresh.

---

## Tests

```bash
sf apex run test --target-org upc360 --code-coverage --result-format human
```

Tests assert **behavior**, not just line coverage:
- legal vs. illegal status transitions
- one audit row + one event per transition
- cycle time captured at terminal status
- async triage via `Test.startTest()/stopTest()`
- bulk (200-record) transitions stay within limits
- controller error paths surface `AuraHandledException`

---

## Tech highlights for reviewers

- One trigger per object; logic in a service layer, never the trigger body.
- Bulkified everywhere — verified with a 200-record test.
- `WITH SECURITY_ENFORCED` SOQL + FLS check before DML.
- Platform Events fire **after commit**, so the UI only ever shows committed state.
- Audit history is written all-or-none in the same transaction as the data change.

---


