# SOH-002-DIAG-01 — Salesforce Schema Investigation

## Summary

The four Case fields are present in SOH-DEV's Metadata API metadata, but the
connected user's runtime Case schema does not expose them. Describe, Field
Definition SOQL, anonymous Apex schema inspection, and runtime SOQL all confirm
that the fields cannot be resolved in that execution context. No explicit
field-permission grants for these fields were found for the connected user's
profile-backed permission set. This establishes the discrepancy, but does not
by itself establish why Metadata API and runtime schema results differ.

The validation failure originates in the candidate `Initialize_Case_SLA` Flow
invoking `CaseSlaInitializationAction.initialize()`. Its Case query references
the two deadline fields that the running context cannot resolve. This is a
field-visibility/access discrepancy, not evidence that the field definitions
are absent from org metadata.

## 1. Verified org identity

All Salesforce CLI commands in this investigation used target alias
`SOH-DEV`.

| Property | Verified value |
| --- | --- |
| Username | `[REDACTED username]` |
| Org ID | `[REDACTED org ID]` |
| Instance URL | `[REDACTED Salesforce instance URL]` |
| Edition | Developer Edition |
| Connected profile | `Systemadministrator` (Metadata API profile full name `Admin`) |
| Profile-backed PermissionSet | `[REDACTED Salesforce ID]` |
| `PermissionsModifyAllData` | `true` |

The identity was checked with `sf org list --json` and
`sf org display --target-org SOH-DEV --json`. The org ID and username in the
display output matched the `SOH-DEV` entry in the org list.

## 2. Actual Case schema and accessibility

### Metadata API definitions

`sf org list metadata --metadata-type CustomField --target-org SOH-DEV --json`
listed all four fields:

| Org component | Metadata component ID | Retrieved type/configuration |
| --- | --- | --- |
| `Case.Response_Deadline__c` | `[REDACTED Salesforce ID]` | DateTime |
| `Case.Resolution_Deadline__c` | `[REDACTED Salesforce ID]` | DateTime |
| `Case.SLA_Status__c` | `[REDACTED Salesforce ID]` | Restricted picklist |
| `Case.Resolution_Notes__c` | `[REDACTED Salesforce ID]` | LongTextArea, length 32768, visible lines 5 |

The metadata retrieve returned the same four Case field definitions. The org
SLA picklist has `Not_Calculated` as its default and includes `On Track`,
`Breached`, and `Met`; it also has an inactive `At Risk` value.

### Runtime schema results

The same fields were not visible through the connected user's runtime schema:

- `sf sobject describe --sobject Case --target-org SOH-DEV` contained none of
  the four fields.
- The `FieldDefinition` query for the four `QualifiedApiName` values returned
  zero records.
- Direct REST SOQL selecting `Response_Deadline__c` returned
  `INVALID_FIELD: No such column 'Response_Deadline__c' on entity 'Case'`.
- Anonymous Apex `Schema.SObjectType.Case.fields.getMap()` checks returned
  `exists=false` for each of the four fields; anonymous Apex SOQL selecting
  the deadline fields failed with the same missing-column error.
- A `FieldPermissions` query for the four fields returned no rows. The
  retrieved `Admin` profile also had no matching `<fieldPermissions>` entries.

Thus, **the field definitions exist in org metadata, but the current API/Apex
execution context cannot resolve them as Case fields**.

## 3. Local vs. org metadata

Local source files are under
[`force-app/main/default/objects/Case/fields/`](../../force-app/main/default/objects/Case/fields/).

| Field | Local metadata | Org metadata | Comparison |
| --- | --- | --- | --- |
| `Response_Deadline__c` | DateTime | DateTime | API name and type match |
| `Resolution_Deadline__c` | DateTime | DateTime | API name and type match |
| `SLA_Status__c` | Restricted picklist; default `Not_Calculated`; `Not_Calculated`, `On Track`, `Breached`, `Met` | Same values/default, plus inactive `At Risk` | Org has an additional inactive value |
| `Resolution_Notes__c` | LongTextArea; length 32768; visible lines 5 | LongTextArea; length 32768; visible lines 5 | API name and settings match |

No missing or differently named field definition was found in Metadata API.
The inactive `At Risk` value is a real local/org metadata difference, but is
unrelated to the missing-deadline-column exception. Do not redeploy or overwrite
the org's SLA field definition as a workaround for this issue without separate
approval.

The org definitions and local source were inspected read-only. No application
code, Salesforce metadata, or org configuration was changed.

## 4. Exact source of the exception

In
[`CaseSlaInitializationAction.cls`](../../force-app/main/default/classes/CaseSlaInitializationAction.cls),
`initialize()` executes this static SOQL at lines 21–25:

```apex
List<Case> cases = [
    SELECT Id, CreatedDate, Priority, Response_Deadline__c, Resolution_Deadline__c
    FROM Case
    WHERE Id IN :uniqueCaseIds
];
```

In
[`Initialize_Case_SLA.flow-meta.xml`](../../force-app/main/default/flows/Initialize_Case_SLA.flow-meta.xml),
the active Flow is a Case **create-only**, **after-save** Flow (lines 27–37).
It invokes `CaseSlaInitializationAction` and supplies `$Record.Id` (lines
38–53). During check-only test validation, this candidate Flow invokes the
action on Case inserts, and the action query fails when the running context
cannot resolve `Response_Deadline__c` and `Resolution_Deadline__c`.

The failure is therefore from **Apex SOQL called by the candidate record-
triggered Flow**, not from `SlaDeadlineCalculator` or
`BusinessHours.add()`. Metadata API listing of existing org Flows returned
only `sfdc_default_ReportExport_Protection_Flow`; ApexTrigger listing was
empty. The candidate SOH Flow was part of the validation package and is the
automation path shown by the test failure. This does not claim that every
possible Salesforce automation type was exhaustively audited.

## 5. Test failure analysis

The specified-tests check-only validation ran 10 tests: **7 passed, 3 failed**.
`CaseSlaInitializationAction` coverage was **39.583%**, below the 75%
deployment-validation threshold.

### Passed (7)

- `calculatesPriorityMatrixDuringBusinessHours`
- `calculatesFromAfterHoursStart`
- `calculatesFromWeekendStart`
- `carriesFridayEndOfDayCalculationIntoMonday`
- `rejectsInactiveAndAmbiguousBusinessHours`
- `rejectsMissingAndUnsupportedPriority`
- `rejectsMissingBusinessHoursConfiguration`

These passed tests exercise the deadline calculator, Business Hours behavior,
and configuration/priority validation.

### Failed (3)

- `doesNotOverwriteExistingDeadlines` — its Case insert starts the Flow, whose
  action query fails on the unavailable deadline columns.
- `initializesMultipleCasesInOneInvocation` — the bulk Case insert likewise
  invokes the Flow/action query and fails before the bulk initialization path
  can be exercised.
- `rejectsPartiallyPopulatedDeadlines` — the expected “only one SLA deadline”
  error is masked by the earlier missing-column query failure, so the test's
  error-message assertion fails.

The three observed failures share the same schema-visibility cause. They do
not demonstrate an independent defect in `SlaDeadlineCalculator`; however,
the action's complete end-to-end behavior remains unverified until the
execution context can resolve the fields. Coverage is low because the action
fails at its initial Case query, preventing most of its branches from running.

## 6. Root cause and evidence vs. inference

### Verified

1. Metadata API lists and retrieves the four field definitions from SOH-DEV.
2. REST describe, `FieldDefinition`, anonymous Apex schema inspection, and
   SOQL under the connected execution identity do not expose/resolve them.
3. There are no matching `FieldPermissions` rows and no matching explicit
   field-permission entries in the retrieved `Admin` profile.
4. The validation failure is raised by the static query in
   `CaseSlaInitializationAction.initialize()`, invoked by the candidate
   create-only Flow.

### Conclusion

The immediate failure mechanism is identified: the runtime schema used by the
API/Apex validation context does not resolve the deadline fields selected by
the action's query. The underlying cause of the discrepancy between the
Metadata API and runtime schema is **not conclusively identified**.

Missing explicit field-level grants are a plausible access-configuration
hypothesis, supported by the absence of matching `FieldPermissions` entries.
They are not proven to be the cause. In particular, the action is ordinary
Apex SOQL in an API 68 class. This report did not account for Salesforce's
API 67.0+ default that Apex database operations run in user mode; the claim
that it was “not a user-mode query” was incorrect. The follow-up
[SOH-002-DIAG-02 report](./SOH-002-DIAG-02-report.md) records that correction
and additional API-version and explicit-mode probes. An org/runtime schema
inconsistency or other validation-context difference has not been ruled out.
The connected profile's `ModifyAllData` permission does not change the
observed fact that describe and SOQL in this context do not resolve these
fields.

The test errors are not evidence that the four CustomField metadata
components are absent or need to be recreated.

## 7. Recommended corrective actions

1. Have the Salesforce administrator verify field-level access for the
   relevant SOH-DEV deployment and Flow/Apex execution identities. If access
   is missing, grant it through the approved profile/permission-set
   mechanism: the action queries the two deadline fields; grant appropriate
   read/edit access for those fields and `SLA_Status__c` according to the
   approved operating model. Grant `Resolution_Notes__c` access only as
   required by its intended users.
2. Confirm the Flow-running identity also has Apex class access to
   `CaseSlaInitializationAction`.
3. If field access is correct, have the Salesforce administrator investigate
   the discrepancy between Metadata API retrieval and runtime schema/validation
   context before changing field definitions.
4. Recheck `sf sobject describe` and a read-only Case SOQL query as the actual
   execution identity before rerunning check-only validation.
5. Rerun the specified Apex tests and verify action coverage exceeds the
   deployment threshold. Do not use `Test.isRunningTest()` to bypass the Flow.
6. Handle the org-only inactive `At Risk` picklist value separately. Do not
   redeploy the local SLA field definition as part of this access correction.

These are recommendations only; no permission, metadata, or code changes were
made as part of this investigation.

## 8. Commands and output evidence

Commands were run against `SOH-DEV`. Representative commands:

```text
sf org list --json
sf org display --target-org SOH-DEV --json
sf sobject describe --sobject Case --target-org SOH-DEV
sf data query --target-org SOH-DEV --query "<FieldDefinition query for the four fields>"
sf org list metadata --metadata-type CustomField --target-org SOH-DEV --json
sf project retrieve start --target-org SOH-DEV --metadata "<four Case CustomFields and Admin Profile>"
sf apex run --target-org SOH-DEV --file <anonymous Apex schema/SOQL check>
sf org list metadata --metadata-type Flow --target-org SOH-DEV
sf org list metadata --metadata-type ApexTrigger --target-org SOH-DEV
sf project deploy start --dry-run --target-org SOH-DEV --test-level RunSpecifiedTests --tests SlaDeadlineCalculatorTest
```

Relevant observed output:

```text
FieldDefinition query: 0 records
REST SOQL: INVALID_FIELD — No such column 'Response_Deadline__c' on entity 'Case'
Anonymous Apex schema checks: exists=false for each of the four fields
Metadata API CustomField list: all four Case fields present
Matching FieldPermissions records: 0
Specified tests: 10 total; 7 passed; 3 failed
CaseSlaInitializationAction coverage: 39.583%
```

The check-only validation does not deploy metadata. No actual deployment was
performed. Temporary metadata retrieval artifacts created for this diagnosis
were removed after inspection.

## Conclusion

**ROOT CAUSE NOT IDENTIFIED**
