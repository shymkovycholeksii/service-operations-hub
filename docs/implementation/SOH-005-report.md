# SOH-005: Case Management Workspace — Implementation Report

**Status:** `DEPLOYED — RUNTIME VERIFICATION PENDING`
**Ticket:** SOH-005
**Branch:** `main`
**Commit:** `86a4e41`
**Date:** 2026-11-25
**Org:** SOH-DEV (`orgfarm-e958f5f827-dev-ed.develop.my.salesforce.com`)

---

## Summary

Deployed the Case Management Workspace — a Lightning Web Component that lets service agents view, filter, and inline-edit Cases (Status, Priority, Resolution Notes) with SLA visibility, surfaced as a tab in the Service Console.

---

## Artefacts

| File | Type | Status |
|---|---|---|
| `lwc/caseManagementWorkspace/caseManagementWorkspace.html` | LWC Template | ✅ Deployed (pre-existing) |
| `lwc/caseManagementWorkspace/caseManagementWorkspace.js` | LWC Controller | ✅ Deployed (pre-existing) |
| `lwc/caseManagementWorkspace/caseManagementWorkspace.css` | LWC Styles | ✅ Deployed (pre-existing) |
| `lwc/caseManagementWorkspace/caseManagementWorkspace.js-meta.xml` | LWC Metadata | ✅ Deployed (pre-existing) |
| `flexipages/SOH_Case_Workspace.flexipage-meta.xml` | FlexiPage (AppPage) | ✅ Deployed this session |
| `tabs/SOH_Case_Workspace.tab-meta.xml` | Custom Tab | ✅ Deployed (`01rgL000029afxyQAA`) |
| `permissionsets/SOH_Case_Workspace_Access.permissionset-meta.xml` | Permission Set | ✅ Deployed (`0PSgL00000Q5yEHWAZ`) & assigned |
| `applications/standard__ServiceConsole.app-meta.xml` | App metadata (source of truth) | Committed; Lightning nav applied in `standard__LightningService` |

---

## Deployment Steps Performed

### 1. Org Access Verified
- Target org: `SOH-DEV` (alias), instance `orgfarm-e958f5f827-dev-ed.develop.my.salesforce.com`
- Connected user: `Oleksii Shymkovych` (System Administrator)

### 2. Pre-deployment State Check (Retrieve from org)
- `caseManagementWorkspace` LWC — **already in org** (deployed previously, `0RdgL000009JIgnSAG`)
- `SOH_Case_Workspace` FlexiPage — not in org
- `SOH_Case_Workspace` CustomTab — not in org
- Service Console nav — did not include SOH_Case_Workspace tab

### 3. App Navigation Metadata Analysis
- Local `standard__ServiceConsole.app-meta.xml` diff vs org: **adds only 2 lines** — the tab entry and workspace mapping for `SOH_Case_Workspace`. All other settings identical.
- Deployment of this file blocked by org: `standard__ServiceConsole` is typed as a Salesforce Classic application in this org; FlexiPage-based tabs cannot be added via Metadata API to Classic-typed apps.
- **Resolution:** Applied tab addition via Lightning App Manager (App Builder) manually. Source file committed as the canonical record of intended state.

### 4. FlexiPage Template Fix
- Original template `flexipage:appHomeTemplateOneRegion` not available in org.
- Changed to `flexipage:appHomeTemplateThreeColumns` (matching the existing `Service_Catalog` FlexiPage pattern already deployed in this org).
- Component placed in `region2` (main content region).

### 5. Access & Tab Visibility Verification
- System Administrator profile: full CRUD on Case standard fields (Status, Priority, Subject, Description, CaseNumber, AccountId, ContactId, OwnerId).
- `SOH_SLA_Field_Access` permission set (already assigned): Read+Edit on `Resolution_Notes__c`, `Resolution_Deadline__c`, `Response_Deadline__c`, `SLA_Status__c`, `Service__c`.
- `SOH_Case_Workspace_Access` permission set (created & deployed `0AfgL00000fRUFLSA4`): grants `Visible` (`DefaultOn`) tab visibility for `SOH_Case_Workspace` only (no extra object/field/system permissions).
- Assigned to `ucharal.35f352789bd6@agentforce.com` (`PermissionSetAssignment: 0PagL00000tmTGGSA2`).
- Confirmed via SOQL:
  - `PermissionSetTabSetting`: `SOH_Case_Workspace` → `DefaultOn` (`01PgL0000dTOMQvUAP`)
  - `TabDefinition`: `SOH_Case_Workspace` (`Label: SOH Case Workspace`, `SobjectName: 0M0gL00000Am6N7`) now exposed.

---

## ⚠️ Pending: Runtime Verification

The app navigation update requires manual verification. Complete the following:

### Step 1 — Confirm tab appears in Lightning Service Console
1. Open Lightning Service Console (`standard__LightningService`): `https://orgfarm-e958f5f827-dev-ed.develop.my.salesforce.com/lightning/app/standard__LightningService`
2. Verify **SOH Case Workspace** tab is visible in the navigation bar / menu (tab visibility and `TabDefinition` are now confirmed).

### Step 2 — Functional verification checklist

| Check | Expected Result |
|---|---|
| Page loads | Filter combos (Status, Priority, SLA Status) and Cases card visible |
| Real Cases shown | Datatable populates from org data |
| Status filter | Filters case list to selected status |
| Priority filter | Filters case list to selected priority |
| SLA Status filter | Filters case list to selected SLA status |
| Row selection | Detail panel opens on right with Case fields |
| Status change + save | Toast "Case updated — Your changes were saved." appears |
| Priority change + save | Toast appears; list refreshes |
| Resolution Notes update | Saves correctly; persists after page refresh |
| "Open Case" button | Navigates to full Case record page |

---

## What Was Intentionally Left Unchanged

- `SlaDeadlineCalculator.cls` / `SlaDeadlineCalculatorTest.cls`
- `Initialize_Case_SLA.flow-meta.xml`
- `lwc/serviceCatalog/`
- `flexipages/Service_Catalog.flexipage-meta.xml`
- `permissionsets/SOH_SLA_Field_Access.permissionset-meta.xml`
- `permissionsets/SOH_Service_Catalog_Access.permissionset-meta.xml`
- All existing Case object custom fields

---

## Git

```
86a4e41  SOH-005: Case Management Workspace LWC, FlexiPage, Tab and app navigation
c8b2419  SOH-004: enable Case requests from Service Catalog
0c29189  docs: record SOH-002 deployment verification
888c3da  Initial Service Operations Hub project
```
