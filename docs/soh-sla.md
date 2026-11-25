# SOH Case SLA Initialization

## Architecture

The active `Initialize_Case_SLA` record-triggered Flow runs after a Case is created and calls the `CaseSlaInitializationAction` invocable Apex action with `$Record.Id`. It is configured for create events only, so the Apex update of the Case does not invoke this Flow again.

The action bulk-loads the Cases and the uniquely named Business Hours record, then delegates deadline calculation to `SlaDeadlineCalculator`. The calculator has no database reads or writes and uses `BusinessHours.add()` for business-time arithmetic. The action performs one bulk system-mode update after all records have passed validation.

## SLA Matrix

| Case Priority | Response SLA | Resolution SLA |
|---|---:|---:|
| High | 1 business hour | 4 business hours |
| Medium | 4 business hours | 8 business hours |
| Low | 8 business hours | 24 business hours |

`Case.CreatedDate` is the starting timestamp. Assignment time, status changes, and action execution time are not used. After successful initialization, the action sets `SLA_Status__c` to `On Track`. Breached and Met monitoring are out of scope.

## Business Hours

The action requires exactly one active Business Hours record named `SOH Support Hours – Germany`. The SOH-DEV record was verified as active, non-default, in `Europe/Berlin`, and configured for Monday through Friday, 09:00–17:00, with weekends closed.

The action fails explicitly if the named record is missing, inactive, or ambiguous. It never falls back to default Business Hours. `BusinessHours.add()` applies Salesforce holidays associated with the selected Business Hours record; this implementation does not create or change holidays or Business Hours.

## Existing Fields and Idempotency

The action uses `Case.Response_Deadline__c`, `Case.Resolution_Deadline__c`, and `Case.SLA_Status__c`; it does not create or modify field metadata. Cases with both deadlines already populated are left unchanged. If only one deadline is populated, the action fails rather than overwriting it or guessing the missing value.

## Execution and Security

The Flow is an active after-save Case create flow and passes `$Record.Id` to the Apex action. It does not run on updates. The Apex action uses `with sharing` for Case queries and performs a narrowly scoped system-mode update only for IDs passed by the Flow, so deadline initialization works without granting end users direct field edit access. Configuration, invalid input, and inaccessible Case errors are surfaced to Flow.

Before activation for business users, grant the Flow-running users Apex class access to `CaseSlaInitializationAction` through the existing access-management process. No profile, permission-set, or other security metadata is added here.

## Tests

`SlaDeadlineCalculatorTest` creates its Case records as test data. Salesforce does not allow Apex tests to insert Business Hours, so only tests that exercise `BusinessHours.add()` query the named SOH Business Hours configuration with `SeeAllData=true`; the configuration resolver's missing, inactive, and ambiguous cases are tested with isolated in-memory records. Date assertions use March 2026 weekdays outside German public-holiday dates.

The tests cover:

- All three priority durations, checked with `BusinessHours.diff()` and `BusinessHours.add()`.
- Starts during and after hours, on a weekend, and near Friday closing.
- Multiple Cases in one action invocation.
- Missing, inactive, and ambiguous Business Hours configuration.
- Missing and unsupported priority.
- Preserving already populated deadlines and rejecting partial deadline state.
