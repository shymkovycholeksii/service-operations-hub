# SOH-003-FIX-01 — Service Catalog Access and Demo Data

## Schema and access

Verified the existing fields; no object or field definitions were changed:

- `Active__c`: Checkbox.
- `Category__c`: Picklist — Network, Infrastructure, Application, Workplace,
  Database, Other.
- `Description__c`: Long Text Area (1000 characters).

Created and deployed `SOH_Service_Catalog_Access` (`SOH Service Catalog
Access`) to SOH-DEV and assigned it to the connected user. It grants object
Read and field Read for `Name`, `Active__c`, `Category__c`, and
`Description__c`; it grants no create, edit, or delete access on `Service__c`.
For SOH-004, the Permission Set was extended with Read/Edit field access for
`Case.Service__c` so the standard Case form can use the lookup. No Case object
CRUD permissions were added. Any other effective Case field access was not
changed.

## Demo records

The object was empty before creation. Five active demonstration records were
created using verified categories:

- Workplace Support — Workplace.
- Network Support — Network.
- Microsoft 365 Support — Application.
- Application Support — Application.
- Database Support — Database.

## Runtime verification

- The connected user's REST Describe now exposes all four requested fields.
- The component's UI API GraphQL query returned all five records, including
  their categories, descriptions, and active status, with no GraphQL errors.
- Created and deployed the `Service_Catalog` Lightning App Page with the
  existing `serviceCatalog` component. Activated the page for System
  Administrators and added it to the Service Console navigation.
- Opened the page in Lightning Experience and verified all five service
  names, categories, descriptions, and Active badges rendered.
- Clicked `Workplace Support`; Lightning Experience opened that Service
  record.
- The populated path was exercised. The component source was unchanged, so
  its loading, empty, and error-state implementation was not retested here.

## Files and status

Created:

- `force-app/main/default/permissionsets/SOH_Service_Catalog_Access.permissionset-meta.xml`
- `force-app/main/default/flexipages/Service_Catalog.flexipage-meta.xml`
- Five SOH-003 demo `Service__c` records in SOH-DEV.

Updated:

- `docs/implementation/SOH-003-report.md`

The SOH-003 LWC implementation was not modified.

**SERVICE CATALOG VERIFIED**
