public with sharing class CaseSlaInitializationAction {
    private static final String BUSINESS_HOURS_NAME = 'SOH Support Hours – Germany';

    @InvocableMethod(
        label='Initialize Case SLA'
        description='Calculates Case SLA deadlines from CreatedDate using SOH Support Hours – Germany.'
    )
    public static void initialize(List<Id> caseIds) {
        if (caseIds == null || caseIds.isEmpty()) {
            return;
        }

        Set<Id> uniqueCaseIds = new Set<Id>();
        for (Id caseId : caseIds) {
            if (caseId == null) {
                throw new SlaDeadlineCalculator.CalculationException('A Case record ID is required.');
            }
            uniqueCaseIds.add(caseId);
        }

        List<Case> cases = [
            SELECT Id, CreatedDate, Priority, Response_Deadline__c, Resolution_Deadline__c
            FROM Case
            WHERE Id IN :uniqueCaseIds
        ];
        if (cases.size() != uniqueCaseIds.size()) {
            throw new SlaDeadlineCalculator.CalculationException(
                'One or more Case records were not found or are not accessible to the Flow running user.'
            );
        }

        List<BusinessHours> matchingHours = [
            SELECT Id, Name, IsActive
            FROM BusinessHours
            WHERE Name = :BUSINESS_HOURS_NAME
            LIMIT 2
        ];
        Id businessHoursId = getBusinessHoursId(matchingHours);

        List<Case> updates = new List<Case>();
        for (Case caseRecord : cases) {
            Boolean hasResponseDeadline = caseRecord.Response_Deadline__c != null;
            Boolean hasResolutionDeadline = caseRecord.Resolution_Deadline__c != null;

            if (hasResponseDeadline && hasResolutionDeadline) {
                continue;
            }
            if (hasResponseDeadline != hasResolutionDeadline) {
                throw new SlaDeadlineCalculator.CalculationException(
                    'Case ' + caseRecord.Id + ' has only one SLA deadline populated; refusing to overwrite or infer the other.'
                );
            }

            SlaDeadlineCalculator.Deadlines deadlines = SlaDeadlineCalculator.calculate(
                caseRecord.CreatedDate,
                caseRecord.Priority,
                businessHoursId
            );
            updates.add(
                new Case(
                    Id = caseRecord.Id,
                    Response_Deadline__c = deadlines.responseDeadline,
                    Resolution_Deadline__c = deadlines.resolutionDeadline,
                    SLA_Status__c = 'On Track'
                )
            );
        }

        if (!updates.isEmpty()) {
            Database.update(updates, true, AccessLevel.SYSTEM_MODE);
        }
    }

    @TestVisible
    private static Id getBusinessHoursId(List<BusinessHours> matchingHours) {
        if (matchingHours == null || matchingHours.isEmpty()) {
            throw new SlaDeadlineCalculator.CalculationException(
                'Active Business Hours "' + BUSINESS_HOURS_NAME + '" were not found; no default-calendar fallback is allowed.'
            );
        }
        if (matchingHours.size() > 1) {
            throw new SlaDeadlineCalculator.CalculationException(
                'Business Hours "' + BUSINESS_HOURS_NAME + '" is ambiguous; exactly one record is required.'
            );
        }
        if (!matchingHours[0].IsActive) {
            throw new SlaDeadlineCalculator.CalculationException(
                'Business Hours "' + BUSINESS_HOURS_NAME + '" exists but is inactive.'
            );
        }
        return matchingHours[0].Id;
    }

}
