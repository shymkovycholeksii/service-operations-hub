# Service Operations Hub

Service Operations Hub (SOH) is a Salesforce DX portfolio project for
enterprise service management. This repository snapshot focuses on the
incident data foundation and Case SLA initialization.

## Current implementation

- `Service__c` service catalog metadata and related Case service fields.
- Case SLA deadline, status, and resolution fields.
- An after-save, Case-create Flow that invokes bulkified Apex initialization.
- Priority-based response and resolution deadlines calculated with
  Salesforce Business Hours.
- A dedicated Permission Set for SLA field access.
- Apex tests covering the priority matrix, business-hours boundaries, bulk
  initialization, and invalid configuration.

The current source does not include Lightning Web Components or a GitHub
Actions workflow.

See [the SLA implementation notes](docs/soh-sla.md) for the architecture,
business-hours requirements, and test scenarios. The implementation and
diagnostic reports in `docs/implementation/` have org, user, and Salesforce
record identifiers redacted for public release.

## Requirements

- Salesforce CLI
- A Salesforce org with API version 68.0 support
- An active Business Hours record named `SOH Support Hours – Germany`,
  configured for Europe/Berlin, Monday–Friday 09:00–17:00

The SLA calculation intentionally does not fall back to the org's default
Business Hours. Salesforce holidays associated with the named record are
respected.

## Validation

The SLA Apex test class is `SlaDeadlineCalculatorTest`. Business-hours
integration tests use the named org configuration, so the required Business
Hours record must exist in the test org.

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

Do not commit Salesforce CLI authentication data. The project `.gitignore`
excludes `.sf/`, `.sfdx/`, and local temporary artifacts.
