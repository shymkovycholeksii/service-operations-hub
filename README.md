# Service Operations Hub

Service Operations Hub (SOH) is a Salesforce DX portfolio project for enterprise service management built on Salesforce Lightning Platform (API v68.0).

## Implemented Modules (SOH-001 – SOH-005)

- **Customer / Case Foundation:** Standard Case object configuration extended with service classification (`Service__c`, `Service_Category__c`), SLA tracking (`Response_Deadline__c`, `Resolution_Deadline__c`, `SLA_Status__c`), and `Resolution_Notes__c`.
- **Service Catalog (`SOH-003`):** Custom `Service__c` object (`Active__c`, `Category__c`, `Description__c`) surfaced through the `serviceCatalog` Lightning Web Component (`Service_Catalog` FlexiPage and tab) using GraphQL (`lightning/uiGraphQLApi`).
- **Case Request Creation (`SOH-004`):** Enables users to submit new Case requests directly from the `serviceCatalog` LWC using Lightning Data Service (`lightning/uiRecordApi`), linking the created Case to the selected `Service__c` record.
- **SLA Initialization (`SOH-002`):** After-save, Case-create Record-Triggered Flow (`Initialize_Case_SLA`) invoking bulkified Apex (`CaseSlaInitializationAction` / `SlaDeadlineCalculator`) to compute priority-based response and resolution deadlines using Salesforce Business Hours (`SOH Support Hours – Germany`).
- **Case Management Workspace (`SOH-005`):** Split-pane `caseManagementWorkspace` Lightning Web Component (`SOH_Case_Workspace` FlexiPage and tab) powered by `lightning/uiGraphQLApi`, `lightning/uiObjectInfoApi`, `lightning/navigation`, and `lightning-record-view-form` / `lightning-record-edit-form` for viewing Cases, inspecting SLA deadlines, and updating Status, Priority, and Resolution Notes.
- **Security & Permission Sets:**
  - `SOH_SLA_Field_Access` — Read/Edit access to Case SLA and resolution fields.
  - `SOH_Service_Catalog_Access` — Read access to `Service__c` and `Case.Service__c`.
  - `SOH_Case_Workspace_Access` — `Visible` tab access for `SOH_Case_Workspace`.

## Architecture & Technologies

- **UI:** Lightning Web Components (`serviceCatalog`, `caseManagementWorkspace`), Lightning App Pages (`FlexiPage`), Lightning Design System (SLDS), and Flexbox/CSS Grid responsive layouts.
- **Data & Metadata APIs:** Lightning GraphQL (`lightning/uiGraphQLApi`), UI Object Info & Record APIs (`lightning/uiObjectInfoApi`, `lightning/uiRecordApi`), and `lightning-record-edit-form`.
- **Automation:** Record-Triggered Flow (`Initialize_Case_SLA`) + Invocable Apex (`CaseSlaInitializationAction`, `SlaDeadlineCalculator`).
- **Testing & Tooling:** Apex unit tests (`SlaDeadlineCalculatorTest`), ESLint, Prettier, and Salesforce CLI (`sf`). This repository does not include a GitHub Actions workflow.

See [the SLA implementation notes](docs/soh-sla.md) for the SLA architecture, business-hours requirements, and test scenarios. Implementation and diagnostic reports in `docs/implementation/` have org, user, and Salesforce record identifiers redacted for public release.

## Requirements

- Salesforce CLI (`sf`)
- A Salesforce org with API version 68.0 support
- An active Business Hours record named `SOH Support Hours – Germany`, configured for `Europe/Berlin`, Monday–Friday 09:00–17:00

The SLA calculation intentionally does not fall back to the org's default Business Hours. Salesforce holidays associated with the named record are respected.

## Validation

The SLA Apex test class is `SlaDeadlineCalculatorTest`. Business-hours integration tests use the named org configuration, so the required Business Hours record must exist in the test org.

To validate the Apex and Flow components without deploying them:

```sh
sf project deploy start --dry-run \
  --metadata ApexClass:SlaDeadlineCalculator \
  --metadata ApexClass:CaseSlaInitializationAction \
  --metadata ApexClass:SlaDeadlineCalculatorTest \
  --metadata Flow:Initialize_Case_SLA \
  --target-org <org-alias> \
  --api-version 68.0 \
  --test-level RunSpecifiedTests \
  --tests SlaDeadlineCalculatorTest
```

Do not commit Salesforce CLI authentication data. The project `.gitignore` excludes `.sf/`, `.sfdx/`, and local temporary artifacts.
