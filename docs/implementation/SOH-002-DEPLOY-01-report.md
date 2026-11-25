# SOH-002-DEPLOY-01 — Final Review and SLA Deployment

## Summary

The approved SOH-002 Apex classes and active Case-create Flow were deployed to
SOH-DEV after a successful check-only validation. All 10 tests passed, both
production Apex classes exceeded 75% coverage, and a real High-priority Case
was created and verified using Salesforce `BusinessHours.diff()`.

Salesforce org, user, deployment, validation, Flow-version, and Case record
identifiers are redacted in this public report.

## 1. Source and repository state

| Property | Result |
| --- | --- |
| Project root | `service-operations-hub` |
| Branch | `main` |
| Source commit deployed | `888c3da105509c0162291f406120bb28f16e0fc1` |
| Published source commit matched local `main` | Yes |
| Worktree before deployment | Clean |
| Source/API version | `68.0` |

Reviewed source:

- [`SlaDeadlineCalculator.cls`](../../force-app/main/default/classes/SlaDeadlineCalculator.cls)
- [`CaseSlaInitializationAction.cls`](../../force-app/main/default/classes/CaseSlaInitializationAction.cls)
- [`SlaDeadlineCalculatorTest.cls`](../../force-app/main/default/classes/SlaDeadlineCalculatorTest.cls)
- [`Initialize_Case_SLA.flow-meta.xml`](../../force-app/main/default/flows/Initialize_Case_SLA.flow-meta.xml)
- [`SOH_SLA_Field_Access.permissionset-meta.xml`](../../force-app/main/default/permissionsets/SOH_SLA_Field_Access.permissionset-meta.xml)

The second-precision correction from FIX-02 is present. No business logic,
field metadata, Permission Set, or Business Hours configuration was changed
for this deployment task.

## 2. Target org and dependency verification

`sf org display --target-org SOH-DEV --json` confirmed a connected org at API
version `68.0`. Its Org ID matched the previously established SOH-DEV Org ID;
the identifier, username, and instance URL are redacted here.

### Case and service schema

Tooling API and REST Case Describe confirmed the required fields are present
and resolvable:

| Component | Org type |
| --- | --- |
| `Case.Response_Deadline__c` | DateTime |
| `Case.Resolution_Deadline__c` | DateTime |
| `Case.SLA_Status__c` | Picklist |
| `Case.Resolution_Notes__c` | LongTextArea (32768 characters) |
| `Case.Service__c` | Lookup to `Service__c` |
| `Service__c` | Present; label `Service` |

The action does not query or otherwise depend on `Case.Service__c`; the lookup
and its target object were nevertheless confirmed in SOH-DEV.

### Permission Set and field access

`SOH_SLA_Field_Access` exists and remains assigned to the connected
SOH-DEV execution user. Its four `FieldPermissions` records were queried
using Salesforce-qualified field names. Every record had Read and Edit set to
true:

- `Case.Response_Deadline__c`
- `Case.Resolution_Deadline__c`
- `Case.SLA_Status__c`
- `Case.Resolution_Notes__c`

### Business Hours

Exactly one `SOH Support Hours – Germany` record was found:

| Property | Verified value |
| --- | --- |
| Active | true |
| Default | false |
| Time zone | `Europe/Berlin` |
| Monday–Friday | 09:00–17:00 |
| Saturday and Sunday | Closed |

No org configuration was modified.

## 3. Final code review

### `SlaDeadlineCalculator`

- Maps High to 1/4 business hours, Medium to 4/8, and Low to 8/24.
- Uses the supplied Case `CreatedDate` and Business Hours ID with
  `BusinessHours.add()`.
- Restores start seconds only when the start is within the Business Hours
  interval; after-hours and weekend starts retain the API's next-open-interval
  behavior.
- Rejects null start, Business Hours ID, priority, unsupported priorities,
  and null calculation results with explicit exceptions.
- Contains no SOQL or DML.

### `CaseSlaInitializationAction`

- Deduplicates IDs and performs bulk SOQL and one bulk DML outside loops.
- Requires exactly one active Business Hours record with the approved name;
  it does not fall back to default hours.
- Preserves records with both deadlines already populated and rejects partial
  deadline state.
- Runs at API 68.0, where its Case query enforces user-mode field access.
  The required Read/Edit grants are present. Its narrowly scoped update uses
  explicit system mode.
- Surfaces missing, inaccessible, or invalid configuration instead of
  silently skipping calculations.

### Tests and Flow

All 10 tests remain present, including the High/Medium/Low matrix, in-hours,
after-hours, weekend and Friday-boundary behavior, bulk initialization,
existing and partial deadline handling, missing/ambiguous Business Hours,
and invalid priorities. Business-time duration assertions use
`BusinessHours.diff()`; the assertions were not weakened.

The Flow is API 68.0, active, on Case create only, after save, and calls the
`CaseSlaInitializationAction` Apex action with `$Record.Id` as `caseIds`.
It has no update trigger or extra update element, so the action's Case update
does not retrigger this Flow.

## 4. Check-only validation

Command:

```text
sf project deploy start --dry-run --metadata ApexClass:SlaDeadlineCalculator --metadata ApexClass:CaseSlaInitializationAction --metadata ApexClass:SlaDeadlineCalculatorTest --metadata Flow:Initialize_Case_SLA --target-org SOH-DEV --api-version 68.0 --test-level RunSpecifiedTests --tests SlaDeadlineCalculatorTest --wait 10 --json
```

| Result | Value |
| --- | --- |
| Validation ID | `[REDACTED Salesforce ID]` |
| Status | Succeeded |
| Components validated | 4 |
| Component failures | 0 |
| Tests run / passed / failed | 10 / 10 / 0 |

All test methods passed:

- `calculatesFromAfterHoursStart`
- `calculatesFromWeekendStart`
- `calculatesPriorityMatrixDuringBusinessHours`
- `carriesFridayEndOfDayCalculationIntoMonday`
- `doesNotOverwriteExistingDeadlines`
- `initializesMultipleCasesInOneInvocation`
- `rejectsInactiveAndAmbiguousBusinessHours`
- `rejectsMissingAndUnsupportedPriority`
- `rejectsMissingBusinessHoursConfiguration`
- `rejectsPartiallyPopulatedDeadlines`

| Apex class | Covered locations | Total | Coverage |
| --- | ---: | ---: | ---: |
| `SlaDeadlineCalculator` | 31 | 34 | 91.18% |
| `CaseSlaInitializationAction` | 44 | 48 | 91.67% |

Flow coverage reported one element covered and none uncovered.

## 5. Deployment

The same four components were deployed; no Case fields, `Service__c`,
Permission Set, or Business Hours metadata were included.

Command:

```text
sf project deploy start --metadata ApexClass:SlaDeadlineCalculator --metadata ApexClass:CaseSlaInitializationAction --metadata ApexClass:SlaDeadlineCalculatorTest --metadata Flow:Initialize_Case_SLA --target-org SOH-DEV --api-version 68.0 --test-level RunSpecifiedTests --tests SlaDeadlineCalculatorTest --wait 10 --json
```

| Result | Value |
| --- | --- |
| Deployment ID | `[REDACTED Salesforce ID]` |
| Status | Succeeded |
| Components deployed | 4 of 4 |
| Component failures | 0 |
| Tests run / passed / failed | 10 / 10 / 0 |

## 6. Post-deployment verification

- Tooling API returned both production Apex classes as active at API 68.0.
- `Initialize_Case_SLA` has an active version, version number 1, and its
  active and latest versions match.
- The Flow's active metadata references the deployed
  `CaseSlaInitializationAction` Apex action.
- The Permission Set, assignment, and all four Read/Edit field grants remain
  present.

### End-to-end Case verification

Before creating the test record, Case Describe showed no non-defaulted
required fields, no active Case validation rules were found, and the org had
no Case Apex triggers. The only active Flow found was the deployed
`Initialize_Case_SLA`.

Created one Case with:

| Field | Value |
| --- | --- |
| Subject | `SOH SLA Deployment Verification` |
| Priority | High |
| Status | New |
| Origin | Phone |

The record was read back after insert. Its `CreatedDate`, both deadlines, and
SLA status were populated:

| Value | Timestamp / result |
| --- | --- |
| CreatedDate (UTC) | `2026-11-25 15:22:45.000Z` |
| Response deadline (UTC) | `2026-11-26 08:22:45.000Z` |
| Resolution deadline (UTC) | `2026-11-26 11:22:45.000Z` |
| SLA status | `On Track` |

A read-only Execute Anonymous probe asserted both deadlines were later than
`CreatedDate` and checked durations with the configured Business Hours ID:

| Deadline | `BusinessHours.diff()` result | Expected |
| --- | ---: | ---: |
| Response | 3,600,000 ms | 1 business hour |
| Resolution | 14,400,000 ms | 4 business hours |

All assertions passed. The verification Case remains in SOH-DEV for
inspection; no unrelated Case records were modified.

## 7. Files, GitHub, and limitations

Created:

- `docs/implementation/SOH-002-DEPLOY-01-report.md`

No Apex, Flow, field, Permission Set, or Business Hours source files were
changed. This report redacts Salesforce identifiers for public publication.
This report is committed on the public GitHub `main` branch after deployment;
the published commit is verified to match local `main`.

The approved task initializes deadlines and sets `On Track`; ongoing
Breached/Met monitoring remains out of scope. The business-hours integration
tests require the named Business Hours record in the test org.

## Final status

**DEPLOYMENT SUCCESSFUL — END-TO-END VERIFIED**
