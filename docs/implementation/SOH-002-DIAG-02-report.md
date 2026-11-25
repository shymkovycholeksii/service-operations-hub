# SOH-002-DIAG-02 — Runtime Schema and Field Access Investigation

## Summary

All four Case fields exist in SOH-DEV according to both the Metadata API and
the Tooling API. They have the expected Case API names, are unmanaged, and
have no namespace prefix. Metadata API retrieval returned their current field
definitions.

The connected API user does not see those fields in REST Case Describe or the
Apex Case field map. The user has Case object access, but no matching
`FieldPermissions` records were found for the fields in any permission set.
This is direct evidence of missing field-level access in the user's effective
REST/Apex schema; missing permission records alone would not have established
that result.

The SOH-002 Apex classes and Flow use API version 68. Salesforce documents
that Apex database operations default to user mode in API 67.0 and later.
Therefore the action's unqualified SOQL runs with object and field security
enforced. Missing field access is a strong explanation for that action query
failure. However, API 66 anonymous SOQL and an explicit `WITH SYSTEM_MODE`
probe also returned `No such column`; the `Database.query(...,
AccessLevel.SYSTEM_MODE)` overload could not be tested because Salesforce
rejects it in Execute Anonymous. Consequently, FLS is verified as a visibility
problem and likely contributor, but the evidence does not conclusively explain
the Apex schema discrepancy in every execution mode.

**The underlying runtime-schema cause remains unidentified.**

## 1. Org identity and execution user

Commands targeted `SOH-DEV`.

| Property | Result |
| --- | --- |
| Org ID | `[REDACTED org ID]` |
| Username | `[REDACTED username]` |
| User ID | `[REDACTED Salesforce ID]` |
| Profile | `Systemadministrator` |
| Profile ID | `[REDACTED Salesforce ID]` |
| Instance URL | `[REDACTED Salesforce instance URL]` |
| Connected status | Connected |

`sf org display --target-org SOH-DEV --json` reported API version `68.0`.
Its `edition` property was null in this run; the earlier DIAG-01 identity
check recorded Developer Edition for the same org ID.

The integrated browser was not authenticated to this Salesforce org. Opening
the Case Object Manager Setup URL redirected to the Salesforce login page. No
credentials were entered. Setup access was therefore inspected through the
authenticated Salesforce APIs and retrieved Profile metadata, not by reading
the UI.

## 2. Profile, permission sets, and effective access

### Assignments and object access

The authenticated user's `PermissionSetAssignment` query returned six
assignments: the profile-owned permission set and five directly assigned
permission sets:

- Profile-owned: `[REDACTED Salesforce ID]`
- `GenieAdmin`
- `EinsteinGPTPromptTemplateManager`
- `CopilotSalesforceAdmin`
- `AgentforceServiceAgentBuilder`
- `ServiceUserPsl`

The profile-owned PermissionSet
(`[REDACTED Salesforce ID]`, `IsOwnedByProfile=true`) has
`PermissionsModifyAllData=true` and `PermissionsViewAllData=true`.
`CopilotSalesforceAdmin` has a Case `ObjectPermissions` record with Read,
Create, Edit, Delete, View All Records, and Modify All Records all true.
REST Case Describe also reports the Case object as createable, updateable, and
deletable. Case object-level CRUD/record access is therefore not the missing
permission evidenced here.

These object-level permissions do not prove field-level access. `View All
Data` and `Modify All Data` are not substitutes for explicit field-level
permissions.

### Field permissions

A `FieldPermissions` query across permission sets for the four fields returned
**zero rows**. The previously retrieved `Admin` Profile metadata also had no
matching `<fieldPermissions>` entries. The profile-owned PermissionSet and
the directly assigned permission sets therefore have no explicit
`FieldPermissions` grant for these fields in the queried metadata.

This result is considered alongside, not instead of, effective schema
evidence: REST Case Describe and Apex field describe both omit the four fields
for this same user. The Tooling `FieldDefinition` records report
`IsFlsEnabled=true` for all four.

## 3. API schema comparison

Every result below is for the same authenticated user and SOH-DEV org.

### REST sObject Describe — API v68.0

Request:

```text
GET /services/data/v68.0/sobjects/Case/describe
```

The response was HTTP 200. It described Case as createable/updateable/
deletable and returned 40 fields. It included `Id`, `Subject`, and `Priority`
but none of:

- `Response_Deadline__c`
- `Resolution_Deadline__c`
- `SLA_Status__c`
- `Resolution_Notes__c`

Thus, the four fields are not REST-visible to this user at v68.0.

### Tooling API `FieldDefinition` — API v68.0

The query returned four rows, all with `EntityDefinition.QualifiedApiName =
'Case'`, `NamespacePrefix = null`, `IsFlsEnabled = true`, and
`IsEverApiAccessible = true`:

| QualifiedApiName | Tooling `DataType` | Label |
| --- | --- | --- |
| `Response_Deadline__c` | `Datum/Uhrzeit` (DateTime) | Response Deadline |
| `Resolution_Deadline__c` | `Datum/Uhrzeit` (DateTime) | Resolution Deadline |
| `SLA_Status__c` | `Auswahlliste` (Picklist) | SLA Status |
| `Resolution_Notes__c` | `Langer Textbereich(32768)` (LongTextArea) | Resolution Notes |

`RunningUserFieldAccessId` was populated for each field with a composite
identifier ending in the connected user's ID. It is not itself a
readable/editable permission boolean and was not treated as proof of access.

The all-Case `FieldDefinition` query returned 65 rows. This included all four
SLA fields plus the existing `Service__c` and `Service_Category__c` Case
fields, which were also absent from the REST Describe response.

### Tooling API `CustomField` — API v68.0

All four rows were returned with `TableEnumOrId = Case`,
`NamespacePrefix = null`, and `ManageableState = unmanaged`:

| Field | CustomField ID | DeveloperName |
| --- | --- | --- |
| `Response_Deadline__c` | `[REDACTED Salesforce ID]` | `Response_Deadline` |
| `Resolution_Deadline__c` | `[REDACTED Salesforce ID]` | `Resolution_Deadline` |
| `SLA_Status__c` | `[REDACTED Salesforce ID]` | `SLA_Status` |
| `Resolution_Notes__c` | `[REDACTED Salesforce ID]` | `Resolution_Notes` |

The Tooling `CustomField` describe does not expose an `IsDeleted` property.
The current rows, Metadata API list, and successful retrieve establish that
the components are currently present; they do not establish whether an older
delete/recreate event ever occurred.

### Metadata API — API v68.0

`sf org list metadata` returned all four `CustomField` components:

| Component | ID | Last modified |
| --- | --- | --- |
| `Case.Response_Deadline__c` | `[REDACTED Salesforce ID]` | 2026-11-25 11:54:37Z |
| `Case.Resolution_Deadline__c` | `[REDACTED Salesforce ID]` | 2026-11-25 11:54:37Z |
| `Case.SLA_Status__c` | `[REDACTED Salesforce ID]` | 2026-11-25 12:41:37Z |
| `Case.Resolution_Notes__c` | `[REDACTED Salesforce ID]` | 2026-11-25 12:41:37Z |

A source-format retrieve at API v68 returned all four files. The retrieved
definitions confirm:

- The exact `fullName` values are the requested Case field API names.
- `Response_Deadline__c` and `Resolution_Deadline__c` are DateTime.
- `SLA_Status__c` is a restricted picklist, with `Not_Calculated` default;
  its org metadata also contains inactive `At Risk`.
- `Resolution_Notes__c` is LongTextArea, length 32768, visible lines 5.
- No field has a namespace prefix. `SLA_Status__c` uses an inline value-set
  definition, not an external/global value-set reference.

The retrieve command's local file result state `Created` means the CLI wrote
the retrieved files into the temporary output directory; it is not a
deployment result. No deployment was run.

## 4. Anonymous Apex schema and SOQL checks

All checks were read-only and used the connected user. The v68 debug log
identified user `[REDACTED Salesforce ID]`; it reported zero DML statements.

### Global describe and Case field map — API v68.0

```text
GLOBAL_CASE=true
CASE_NAME=Case; READ=true; FIELD_MAP_SIZE=40
FIELD=Id; PRESENT=true; READ=true; UPDATE=false
FIELD=Subject; PRESENT=true; READ=true; UPDATE=true
FIELD=Priority; PRESENT=true; READ=true; UPDATE=true
FIELD=Response_Deadline__c; PRESENT=false
FIELD=Resolution_Deadline__c; PRESENT=false
FIELD=SLA_Status__c; PRESENT=false
FIELD=Resolution_Notes__c; PRESENT=false
```

Because each requested field lookup returned null, a
`DescribeFieldResult.isAccessible()` or `.isUpdateable()` call could not be
made for those names in this execution context. For comparison, accessible
standard fields returned field tokens and their access checks succeeded.

### Static and dynamic SOQL

Static anonymous SOQL selecting the two deadlines failed compilation:

```text
No such column 'Response_Deadline__c' on entity 'Case'
```

Dynamic SOQL at API v68.0, without an explicit access-mode clause, raised the
same `System.QueryException`. A dynamic query containing `WITH SYSTEM_MODE`
also returned `No such column`. A comparative dynamic query at API v66.0
without an explicit access mode returned the same error.

An attempt to pass `AccessLevel.SYSTEM_MODE` to `Database.query` was rejected
by Salesforce in Execute Anonymous:

```text
System.SecurityException:
Die Zugriffsebene SYSTEM_MODE kann nicht bei der anonymen Ausführung von Apex verwendet werden.
```

Therefore that overload could not provide a valid privileged-mode
comparison. No DML was performed.

## 5. Metadata state, namespace, and deletion

The combination of current Metadata API list/retrieve and Tooling API
`CustomField`/`FieldDefinition` results verifies that these are currently
present Case fields, not just local source files. Their exact API names and
parent object match; `NamespacePrefix` is null and Tooling reports
`ManageableState=unmanaged`. No packaging or namespace mismatch was found.

Metadata API has no separate active/inactive property for the field
components themselves. The picklist value `At Risk` is explicitly inactive;
that is a value-level difference from local source and is unrelated to the
four fields' runtime visibility. The currently listed/retrieved fields are
not in a current deleted state. Historical deletion state was not exposed by
the queried Tooling object.

## 6. API versions

| Surface | Version observed/used |
| --- | --- |
| Salesforce CLI | `@salesforce/cli/2.159.7`, Node `v26.13.0` |
| CLI org display | API version `68.0`; global `org-api-version` setting was unset |
| Apex class metadata | `68.0` for `CaseSlaInitializationAction` and `SlaDeadlineCalculator` |
| Flow metadata | `68.0` for `Initialize_Case_SLA` |
| REST Describe | Explicit `/services/data/v68.0/...` |
| Tooling API queries | Explicit `--api-version 68.0`; URLs returned `/services/data/v68.0/tooling/...` |
| Metadata API list/retrieve | Explicit API version `68.0` |
| Anonymous Apex probes | v68.0, plus a v66.0 comparison |

There is no API-version mismatch among the SOH-002 Apex classes, Flow, and the
primary API probes. API 68's Apex security behavior is relevant, however:
Salesforce's [Secure Apex Classes](https://developer.salesforce.com/docs/platform/lwc/guide/apex-security.html)
documentation states that Apex database operations default to user mode in
API 67.0 and later. The class API version is 68.0, and its initial Case query
does not specify `WITH SYSTEM_MODE`; that query therefore enforces the
running user's field-level access. The later explicit
`Database.update(..., AccessLevel.SYSTEM_MODE)` applies only to the update,
not the earlier query.

This is a correction to DIAG-01's statement that the action's ordinary SOQL
was “not a user-mode query.” That statement relied on the absence of an
explicit `WITH USER_MODE` clause and overlooked the API 67+ default.

## 7. Root-cause analysis

| Candidate | Evidence and assessment |
| --- | --- |
| FLS / permission configuration | **Verified visibility problem.** No explicit field grants were found; `IsFlsEnabled=true`; REST Describe and Apex describe omit the fields. API 68 Apex SOQL defaults to user mode, so missing field access is a strong explanation for the action query. It is not proven to explain every probe: API 66 and explicit `WITH SYSTEM_MODE` probes also failed. |
| Case object permission | **Not supported as the cause.** The user has effective Case create/update/delete access; an assigned permission set has all Case CRUD and View/Modify All Records. |
| Missing or incorrectly named metadata | **Ruled out.** Metadata API and Tooling API return all four exact Case fields and expected types. |
| Namespace or packaging issue | **Ruled out by observed metadata.** Namespace is null, `ManageableState=unmanaged`, and `TableEnumOrId=Case`. |
| Current deletion state | **Ruled out.** Metadata API lists and retrieves all four current components. Historical deletion state is not exposed by the queried CustomField describe. |
| API-version mismatch | **Not supported.** The deployed code/Flow and primary API probes use v68. API 66 also fails, so the version-67 default-mode change alone does not reconcile the observations. |
| Runtime schema/cache inconsistency | **Strongly indicated, not confirmed as the underlying cause.** Metadata/Tooling sees the fields, while REST and Apex runtime schema/SOQL do not. Salesforce-side cache or schema state was not changed or independently inspected. |

The immediate failure path remains the static SOQL in
[`CaseSlaInitializationAction.cls`](../../force-app/main/default/classes/CaseSlaInitializationAction.cls),
lines 21–25, invoked by the active create-only after-save
[`Initialize_Case_SLA.flow-meta.xml`](../../force-app/main/default/flows/Initialize_Case_SLA.flow-meta.xml).

**Conclusion:** the evidence identifies a real field-access/schema discrepancy
and shows that FLS is relevant to the API 68 action. It does not conclusively
identify why Apex cannot resolve these fields even in the comparative probes.
Do not treat redeploying the existing field definitions as an evidence-based
fix.

## 8. Recommended next action

1. In Setup, have an administrator with an authenticated org session verify
   the four fields' read/edit access for the Flow/Apex execution user and the
   deployment user. If the approved security model requires access, grant
   explicit field permissions using the approved profile/permission-set
   mechanism.
2. Recheck REST Case Describe and the API 68 user-mode SOQL as that same user.
   If fields then appear and the action query succeeds, the FLS explanation is
   confirmed for the validation failure.
3. If fields remain absent, or the issue needs system-mode Apex access, open a
   Salesforce Support investigation with the org ID and the contrasting
   REST, Tooling, Metadata, API 66, and Apex v68 results. Ask Salesforce to
   verify the org's active runtime schema/catalog state.
4. Rerun the specified SOH-002 tests only after the access/schema state is
   verified. Do not change Apex, Flow, field metadata, permissions, or deploy
   as part of this diagnostic.

## 9. Commands and output excerpts

Representative commands (all target `SOH-DEV`; requests specify API v68
unless noted):

```text
sf --version
sf org display --target-org SOH-DEV --json
sf config get org-api-version --json
sf api request rest '/services/data/v68.0/sobjects/Case/describe' --target-org SOH-DEV --json
sf data query --target-org SOH-DEV --api-version 68.0 --use-tooling-api --query "SELECT QualifiedApiName, DataType, IsFlsEnabled, IsEverApiAccessible, NamespacePrefix FROM FieldDefinition WHERE EntityDefinition.QualifiedApiName = 'Case' AND QualifiedApiName IN (...)"
sf data query --target-org SOH-DEV --api-version 68.0 --query "SELECT ParentId, SobjectType, Field, PermissionsRead, PermissionsEdit FROM FieldPermissions WHERE SobjectType = 'Case' AND Field IN (...)"
sf data query --target-org SOH-DEV --api-version 68.0 --query "SELECT Id, AssigneeId, PermissionSetId, PermissionSet.Name, PermissionSet.IsOwnedByProfile FROM PermissionSetAssignment WHERE AssigneeId = '[REDACTED Salesforce ID]'"
sf org list metadata --metadata-type CustomField --api-version 68.0 --target-org SOH-DEV --json
sf project retrieve start --target-org SOH-DEV --api-version 68.0 --output-dir tmp/soh-s002-diag-02 --metadata CustomField:Case.Response_Deadline__c --metadata CustomField:Case.Resolution_Deadline__c --metadata CustomField:Case.SLA_Status__c --metadata CustomField:Case.Resolution_Notes__c
sf apex run --target-org SOH-DEV --api-version 68.0 --file <temporary read-only probe>
sf apex run --target-org SOH-DEV --api-version 66.0 --file <temporary read-only probe>
```

Key output excerpts:

```text
REST Case Describe: HTTP 200; Case createable/updateable/deletable=true;
  40 fields; none of the four requested SLA fields returned.
Tooling FieldDefinition: totalSize=4; exact Case API names; IsFlsEnabled=true;
  NamespacePrefix=null.
Tooling CustomField: four records; TableEnumOrId=Case; unmanaged;
  NamespacePrefix=null.
Metadata API list/retrieve: all four components present.
FieldPermissions query: totalSize=0.
Apex v68: GLOBAL_CASE=true; Case field map size=40; all four target map lookups absent.
Apex static and dynamic SOQL: No such column 'Response_Deadline__c' on entity 'Case'.
Apex v66 dynamic SOQL: same No such column error.
Apex execute-anonymous AccessLevel.SYSTEM_MODE overload: rejected by Salesforce.
```

No code, Flow, Salesforce metadata, or permissions were modified. No
deployment or DML was performed. The temporary metadata retrieval files and
Apex probe files were removed after inspection.

## Conclusion

**ROOT CAUSE NOT IDENTIFIED**
