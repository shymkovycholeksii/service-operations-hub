# SOH-004 — Create Service Request from Service Catalog

## Files included in the SOH-004 commit

- `force-app/main/default/lwc/serviceCatalog/serviceCatalog.js` — navigates to
  the standard Case creation form with the selected Service prepopulated.
- `force-app/main/default/lwc/serviceCatalog/serviceCatalog.html` — adds the
  per-Service Create Request action.
- `force-app/main/default/lwc/serviceCatalog/serviceCatalog.css` and
  `serviceCatalog.js-meta.xml` — existing bundle files included with the
  component source.
- `force-app/main/default/permissionsets/SOH_Service_Catalog_Access.permissionset-meta.xml`
  — grants Read/Edit field access to `Case.Service__c`; no Case object CRUD
  permissions were added.
- `force-app/main/default/layouts/Case-Case Layout.layout-meta.xml` — adds
  the editable Service lookup to the Case Information section.
- `force-app/main/default/flexipages/Service_Catalog.flexipage-meta.xml` —
  existing Lightning page hosting the catalog, included as a runtime dependency.
- `docs/implementation/SOH-003-report.md` — clarifies the Permission Set's
  Case lookup grant.
- `docs/implementation/SOH-004-report.md` — this deployment report.

## Deployment and runtime verification

- Check-only validation passed for `LightningComponentBundle:serviceCatalog`,
  `PermissionSet:SOH_Service_Catalog_Access`, and `Layout:Case-Case Layout`.
- Deployment of those same three components to `SOH-DEV` succeeded.
- In Lightning Experience, the Service Catalog displayed its five existing
  Service records. Create Request opened the standard Case form with the
  Service lookup set to Workplace Support.
- Created one Case with Priority High and the required Origin set to Web.
  The saved Case references Workplace Support.
- The active `Initialize_Case_SLA` Flow populated both deadlines and set
  `SLA_Status__c` to `On Track`.
- `BusinessHours.diff()` against the active Europe/Berlin support hours
  returned 3,600,000 ms for response and 14,400,000 ms for resolution, matching
  the approved High-priority SLA.
- A browser console toast warning appeared after save, but the form navigated
  to the saved Case and the persisted record and SLA values were verified.

No SLA Apex, Flow, Case field definitions, or Service object definitions were
changed.

**SERVICE REQUEST CREATION VERIFIED**
