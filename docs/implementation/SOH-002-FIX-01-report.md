# SOH-002-FIX-01 — SLA Field-Level Security

## Summary

Created and deployed the new `SOH_SLA_Field_Access` Permission Set to
SOH-DEV, granting Read and Edit for exactly the four requested Case fields.
Assigned it to the currently authenticated user,
`[REDACTED username]`.

Post-assignment REST Describe, Apex schema/access checks, a read-only SOQL
projection, and Tooling API `FieldPermissions` checks all succeeded. This
confirms the fields' prior user-visible schema/access failure was corrected
by the FLS grant.

The SOH-002 check-only validation ran all 10 tests: 9 passed and 1 still
fails. The remaining failure is
`initializesMultipleCasesInOneInvocation`, with a duration assertion
mismatch (`Expected: 3600000, Actual: 3580000`), not a missing-column error.
Coverage was above 75% for both production Apex classes. The check-only
validation did not deploy the SOH-002 Apex or Flow components.

## 1. Permission Set implementation

Added:

- [`SOH_SLA_Field_Access.permissionset-meta.xml`](../../force-app/main/default/permissionsets/SOH_SLA_Field_Access.permissionset-meta.xml)

The repository had no existing Permission Set metadata files; this uses the
Salesforce DX source-format convention under
`force-app/main/default/permissionsets/`.

| Permission Set property | Value |
| --- | --- |
| Label | `SOH SLA Field Access` |
| API Name | `SOH_SLA_Field_Access` |
| Case object permissions | None added |
| Field permission entries | Exactly four |

| Field | Read | Edit |
| --- | --- | --- |
| `Case.Response_Deadline__c` | true | true |
| `Case.Resolution_Deadline__c` | true | true |
| `Case.SLA_Status__c` | true | true |
| `Case.Resolution_Notes__c` | true | true |

The XML was parsed and structurally checked: expected `PermissionSet` root and
label, exactly these four field entries, all Read/Edit true, and no
`objectPermissions` element.

## 2. Org and deployment

Immediately before deployment, `sf org display --target-org SOH-DEV --json`
confirmed:

- Alias: `SOH-DEV`
- Org ID: `[REDACTED org ID]`
- Username: `[REDACTED username]`
- Instance: `[REDACTED Salesforce instance URL]`
- Connected status: `Connected`
- API version: `68.0`

Deployment command:

```text
sf project deploy start --metadata PermissionSet:SOH_SLA_Field_Access --target-org SOH-DEV --api-version 68.0 --test-level NoTestRun --wait 10 --json
```

`NoTestRun` was used for this Permission Set-only metadata deployment.

| Result | Value |
| --- | --- |
| Deployment ID | `[REDACTED Salesforce ID]` |
| Status | `Succeeded` |
| Success | true |
| Components | 1 of 1 |
| Component ID | `[REDACTED Salesforce ID]` |
| Component created | true |
| Component failures | 0 |

The org query after deployment returned one PermissionSet with API name
`SOH_SLA_Field_Access`, label `SOH SLA Field Access`, and
`IsOwnedByProfile=false`.

## 3. Assignment

Assignment command:

```text
sf org assign permset --name SOH_SLA_Field_Access --target-org SOH-DEV --api-version 68.0 --on-behalf-of [REDACTED username] --json
```

The CLI returned one success for the intended username and no failures.
`PermissionSetAssignment` verification returned exactly one matching
assignment:

| Property | Value |
| --- | --- |
| Assignment ID | `[REDACTED Salesforce ID]` |
| User ID | `[REDACTED Salesforce ID]` |
| Username | `[REDACTED username]` |
| PermissionSet ID | `[REDACTED Salesforce ID]` |
| PermissionSet API Name | `SOH_SLA_Field_Access` |

A subsequent `FieldPermissions` query returned four records under that
Permission Set. Every record had `SobjectType=Case`,
`PermissionsRead=true`, and `PermissionsEdit=true` for the expected field.

## 4. Runtime verification

DIAG-02 recorded the before state for this same user: REST Describe and Apex
field map omitted all four fields, and a Case SOQL projection failed with
`No such column 'Response_Deadline__c' on entity 'Case'`.

### A. REST Case Describe

Request:

```text
GET /services/data/v68.0/sobjects/Case/describe
```

After assignment, the response was HTTP 200 and contained all four:

| Field | REST type | Createable | Updateable |
| --- | --- | --- | --- |
| `Response_Deadline__c` | datetime | true | true |
| `Resolution_Deadline__c` | datetime | true | true |
| `SLA_Status__c` | picklist | true | true |
| `Resolution_Notes__c` | textarea | true | true |

### B. Apex schema and access checks

Read-only Execute Anonymous at API v68.0 reported:

```text
GLOBAL_CASE=true
FIELD_MAP_SIZE=44
FIELD=Response_Deadline__c; PRESENT=true; READ=true; UPDATE=true
FIELD=Resolution_Deadline__c; PRESENT=true; READ=true; UPDATE=true
FIELD=SLA_Status__c; PRESENT=true; READ=true; UPDATE=true
FIELD=Resolution_Notes__c; PRESENT=true; READ=true; UPDATE=true
```

The Apex log reported zero DML statements.

### C. SOQL

This read-only query succeeded at API v68.0:

```sql
SELECT Id, Response_Deadline__c, Resolution_Deadline__c,
       SLA_Status__c, Resolution_Notes__c
FROM Case
LIMIT 0
```

The query returned successfully with zero rows. `LIMIT 0` verified that
Salesforce accepts all selected fields without reading Case record values.

### D. Tooling API FieldPermissions

The post-assignment query returned exactly four records for parent
`[REDACTED Salesforce ID]`, one per required field. All four had Read and Edit
enabled. This matches the deployed Permission Set XML.

## 5. SOH-002 regression validation

The SOH-002 Apex classes and Flow were not present in SOH-DEV before this
check-only run, so the existing local test class was executed as part of a
dry-run deployment validation. The validation payload contained only:

- `ApexClass:SlaDeadlineCalculator`
- `ApexClass:CaseSlaInitializationAction`
- `ApexClass:SlaDeadlineCalculatorTest`
- `Flow:Initialize_Case_SLA`

Command:

```text
sf project deploy start --dry-run --metadata ApexClass:SlaDeadlineCalculator --metadata ApexClass:CaseSlaInitializationAction --metadata ApexClass:SlaDeadlineCalculatorTest --metadata Flow:Initialize_Case_SLA --target-org SOH-DEV --api-version 68.0 --test-level RunSpecifiedTests --tests SlaDeadlineCalculatorTest --wait 10 --json
```

| Validation result | Value |
| --- | --- |
| Validation ID | `[REDACTED Salesforce ID]` |
| Dry run | true |
| SOH-002 components validated | 4 |
| Component failures | 0 |
| Tests run | 10 |
| Tests passed | 9 |
| Tests failed | 1 |
| Overall validation | Failed due to the one failed test |

The two previously failing tests that depended on field access now pass:

- `doesNotOverwriteExistingDeadlines` — passed
- `rejectsPartiallyPopulatedDeadlines` — passed

`initializesMultipleCasesInOneInvocation` now reaches its deadline assertions
but fails with:

```text
System.AssertException: Assertion Failed: Expected: 3600000, Actual: 3580000
Class.SlaDeadlineCalculatorTest.assertBusinessHoursDuration: line 272
Class.SlaDeadlineCalculatorTest.assertCaseDeadlines: line 251
Class.SlaDeadlineCalculatorTest.initializesMultipleCasesInOneInvocation: line 108
```

The failure is no longer a missing-column or FLS error. Its cause was not
changed or investigated in this FLS-only task.

Coverage reported by the check-only run:

| Apex class | Covered locations | Total | Coverage |
| --- | ---: | ---: | ---: |
| `SlaDeadlineCalculator` | 28 | 31 | 90.32% |
| `CaseSlaInitializationAction` | 44 | 48 | 91.67% |

The Flow coverage result reported its one element covered and none uncovered.
Although coverage exceeds 75% for both Apex classes, the validation as a whole
is unsuccessful until the remaining test failure is addressed. No actual
deployment of the Apex classes or Flow was performed.

## 6. Files and scope

Created:

- `force-app/main/default/permissionsets/SOH_SLA_Field_Access.permissionset-meta.xml`
- `docs/implementation/SOH-002-FIX-01-report.md`

No existing Case field definitions, Apex classes, Flow, profiles, or other
Permission Sets were modified. The new Permission Set contains no object
permissions, so existing Case CRUD permissions were left unchanged.

The only org changes were the explicitly requested Permission Set deployment
and its assignment to the connected user. The read-only SOQL/Apex probes made
no record changes. The SOH-002 validation used `--dry-run` and did not deploy
the Flow or Apex components.

## Final status

**PARTIALLY FIXED — FLS was corrected, but runtime-schema or other failures remain.**
