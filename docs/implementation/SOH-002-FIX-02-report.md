# SOH-002-FIX-02 — Bulk SLA Duration Test

## Summary

The short duration was caused by `BusinessHours.add()` dropping the start
timestamp's seconds when the start is within the configured business-hours
window. The calculator now restores those seconds to both computed deadlines.
The tests retain an exact `BusinessHours.diff()` assertion and account for the
documented behavior when checking the exact deadline.

The complete `SlaDeadlineCalculatorTest` suite passes in a successful
check-only validation. No Apex or Flow deployment was performed.

## Investigation findings

- The invocable action queries the Case's actual `CreatedDate` and passes it
  with `Priority` and the selected Business Hours ID to
  [`SlaDeadlineCalculator.cls`](../../force-app/main/default/classes/SlaDeadlineCalculator.cls).
- Neither the production calculation nor the bulk test uses
  `Test.setCreatedDate()`. The calculation start is the inserted Case's
  `CreatedDate`; the bulk test reads that timestamp back from the Case.
- `BusinessHours.add()` receives that exact `CreatedDate`, the active SOH
  Business Hours record ID, and the priority's SLA duration in milliseconds.
- The test helper measures business time with
  `BusinessHours.diff()`. It also checks the exact deadline against
  `BusinessHours.add()` with the start's seconds restored only if
  `BusinessHours.isWithin()` is true.
- Milliseconds were retained in the Apex probe; the observed loss was the
  seconds component, not timezone conversion or rounding of the test's
  expected duration.

The configured Business Hours record used by the calculator was:

| Property | Value |
| --- | --- |
| Name | `SOH Support Hours – Germany` |
| ID | `[REDACTED Salesforce ID]` |
| Active | true |
| Default Business Hours | false |
| Time zone | `Europe/Berlin` |
| Schedule | Monday–Friday, 09:00–17:00; Saturday and Sunday closed |

### Timestamp evidence

A read-only Apex probe used an in-hours start of
`2026-11-25 14:53:20.000Z` and a one-business-hour duration:

| Calculation | Timestamp / result |
| --- | --- |
| Start | `2026-11-25 14:53:20.000Z` |
| Raw `BusinessHours.add()` result | `2026-11-25 15:53:00.000Z` |
| `BusinessHours.diff()` to raw result | `3,580,000 ms` |
| Corrected deadline | `2026-11-25 15:53:20.000Z` |
| `BusinessHours.diff()` to corrected result | `3,600,000 ms` |

This demonstrates the original 20,000 ms shortfall: the start's 20 seconds
were not counted by `BusinessHours.add()`'s returned deadline. A separate
bulk diagnostic run created Cases at
`2026-11-25 14:56:49.000Z`; raw deadlines were short by 49,000 ms, matching
those Cases' 49-second start offset. The shortfall therefore varied with the
actual creation timestamp and was not a fixed SLA-duration error.

For starts after business hours or on weekends, `BusinessHours.add()` rolls
forward to the next open interval. The implementation does not add the
original seconds in those cases. A Friday boundary test verifies a start at
`2026-03-20 15:30:20Z` (16:30:20 in Berlin) plus one business hour resolves
to `2026-03-23 08:30:20Z` (09:30:20 in Berlin), with exactly 3,600,000 ms
of business time.

## Changes

1. In `SlaDeadlineCalculator.calculate()`, after validating that both
   `BusinessHours.add()` results are non-null, add the start timestamp's
   seconds to each deadline only when the start has nonzero seconds and is
   within the selected Business Hours.
2. In
   [`SlaDeadlineCalculatorTest.cls`](../../force-app/main/default/classes/SlaDeadlineCalculatorTest.cls),
   keep the `BusinessHours.diff()` assertion for the exact required SLA
   duration. Adjust the test's expected deadline for the same experimentally
   verified `BusinessHours.add()` seconds behavior. The Friday boundary case
   now uses the shared duration assertion instead of comparing directly to
   the unadjusted API result.

The test changes correct an invalid exact-timestamp expectation; they do not
weaken the duration assertion. No production Business Hours, fields,
Permission Set, action, Flow, or unrelated project configuration was changed
for this task.

## Regression validation

Target org identity was rechecked with
`sf org display --target-org SOH-DEV --json`:

- Alias: `SOH-DEV`
- Org ID: `[REDACTED org ID]`
- Username: `[REDACTED username]`
- Instance: `[REDACTED Salesforce instance URL]`
- Connected status: `Connected`

Validation command:

```text
sf project deploy start --dry-run --metadata ApexClass:SlaDeadlineCalculator --metadata ApexClass:CaseSlaInitializationAction --metadata ApexClass:SlaDeadlineCalculatorTest --metadata Flow:Initialize_Case_SLA --target-org SOH-DEV --api-version 68.0 --test-level RunSpecifiedTests --tests SlaDeadlineCalculatorTest --wait 10 --json
```

| Result | Value |
| --- | --- |
| Validation ID | `[REDACTED Salesforce ID]` |
| Status | Succeeded |
| Components validated | 4 |
| Component failures | 0 |
| Tests run | 10 |
| Tests passed / failed | 10 / 0 |

All required scenarios passed:

- Priority matrix for High, Medium, and Low
- In-hours, after-hours, weekend, and Friday closing calculations
- Bulk initialization of multiple Cases
- Existing deadlines preserved
- Partial deadlines rejected
- Missing, inactive, or ambiguous Business Hours rejected
- Missing and unsupported priorities rejected

Coverage reported by this validation:

| Apex class | Covered locations | Total | Coverage |
| --- | ---: | ---: | ---: |
| `SlaDeadlineCalculator` | 31 | 34 | 91.18% |
| `CaseSlaInitializationAction` | 44 | 48 | 91.67% |

Flow coverage reported its one element covered and none uncovered.

## Files and deployment status

Modified:

- `force-app/main/default/classes/SlaDeadlineCalculator.cls`
- `force-app/main/default/classes/SlaDeadlineCalculatorTest.cls`

Created:

- `docs/implementation/SOH-002-FIX-02-report.md`

The validation used `--dry-run`; it validated the Apex and Flow payload but
did not deploy those components. No other org configuration was changed.
The current workspace does not contain a Git repository, so `git status` and
`git diff` could not be used to independently enumerate the worktree changes.

## Final status

**FIX CONFIRMED**
