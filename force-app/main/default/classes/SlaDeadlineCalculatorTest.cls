@IsTest
private class SlaDeadlineCalculatorTest {
    private static final String BUSINESS_HOURS_NAME = 'SOH Support Hours – Germany';

    @IsTest(SeeAllData=true)
    static void calculatesPriorityMatrixDuringBusinessHours() {
        BusinessHours supportHours = getBusinessHours();
        Datetime startTime = Datetime.newInstanceGMT(2026, 3, 16, 9, 0, 20);

        assertCalculatedDuration(supportHours.Id, startTime, 'High', 1, 4);
        assertCalculatedDuration(supportHours.Id, startTime, 'Medium', 4, 8);
        assertCalculatedDuration(supportHours.Id, startTime, 'Low', 8, 24);
    }

    @IsTest(SeeAllData=true)
    static void calculatesFromAfterHoursStart() {
        BusinessHours supportHours = getBusinessHours();
        Datetime startTime = Datetime.newInstanceGMT(2026, 3, 16, 16, 0, 20);
        Long oneBusinessHour = 60 * 60 * 1000;

        SlaDeadlineCalculator.Deadlines deadlines = SlaDeadlineCalculator.calculate(
            startTime,
            'High',
            supportHours.Id
        );

        System.assertEquals(Datetime.newInstanceGMT(2026, 3, 17, 9, 0, 0), deadlines.responseDeadline);
        System.assertEquals(
            BusinessHours.add(supportHours.Id, startTime, oneBusinessHour),
            deadlines.responseDeadline
        );
    }

    @IsTest(SeeAllData=true)
    static void calculatesFromWeekendStart() {
        BusinessHours supportHours = getBusinessHours();
        Datetime startTime = Datetime.newInstanceGMT(2026, 3, 21, 11, 0, 20);
        Long oneBusinessHour = 60 * 60 * 1000;

        SlaDeadlineCalculator.Deadlines deadlines = SlaDeadlineCalculator.calculate(
            startTime,
            'High',
            supportHours.Id
        );

        System.assertEquals(Datetime.newInstanceGMT(2026, 3, 23, 9, 0, 0), deadlines.responseDeadline);
        System.assertEquals(
            BusinessHours.add(supportHours.Id, startTime, oneBusinessHour),
            deadlines.responseDeadline
        );
    }

    @IsTest(SeeAllData=true)
    static void carriesFridayEndOfDayCalculationIntoMonday() {
        BusinessHours supportHours = getBusinessHours();
        Datetime startTime = Datetime.newInstanceGMT(2026, 3, 20, 15, 30, 20);
        Long oneBusinessHour = 60 * 60 * 1000;

        SlaDeadlineCalculator.Deadlines deadlines = SlaDeadlineCalculator.calculate(
            startTime,
            'High',
            supportHours.Id
        );

        System.assertEquals(Datetime.newInstanceGMT(2026, 3, 23, 8, 30, 20), deadlines.responseDeadline);
        assertBusinessHoursDuration(supportHours.Id, startTime, deadlines.responseDeadline, 1);
    }

    @IsTest(SeeAllData=true)
    static void initializesMultipleCasesInOneInvocation() {
        BusinessHours supportHours = getBusinessHours();
        List<Case> casesToInsert = new List<Case>{
            newCase('High'),
            newCase('Medium'),
            newCase('Low')
        };

        Test.startTest();
        Database.insert(casesToInsert, AccessLevel.SYSTEM_MODE);
        Test.stopTest();

        Set<Id> caseIds = new Set<Id>();
        for (Case caseRecord : casesToInsert) {
            caseIds.add(caseRecord.Id);
        }
        Map<Id, Case> updatedCases = new Map<Id, Case>([
            SELECT Id, CreatedDate, Priority, Response_Deadline__c, Resolution_Deadline__c, SLA_Status__c
            FROM Case
            WHERE Id IN :caseIds
        ]);
        for (Case createdCase : casesToInsert) {
            Case updatedCase = updatedCases.get(createdCase.Id);
            Integer responseHours;
            Integer resolutionHours;
            if (updatedCase.Priority == 'High') {
                responseHours = 1;
                resolutionHours = 4;
            } else if (updatedCase.Priority == 'Medium') {
                responseHours = 4;
                resolutionHours = 8;
            } else {
                responseHours = 8;
                resolutionHours = 24;
            }
            assertCaseDeadlines(
                updatedCase,
                supportHours.Id,
                updatedCase.CreatedDate,
                responseHours,
                resolutionHours
            );
        }
    }

    @IsTest
    static void rejectsMissingBusinessHoursConfiguration() {
        try {
            CaseSlaInitializationAction.getBusinessHoursId(new List<BusinessHours>());
            System.assert(false, 'Expected missing Business Hours configuration to fail.');
        } catch (SlaDeadlineCalculator.CalculationException exceptionValue) {
            System.assert(exceptionValue.getMessage().contains('were not found'));
            System.assert(exceptionValue.getMessage().contains('no default-calendar fallback'));
        }
    }

    @IsTest
    static void rejectsInactiveAndAmbiguousBusinessHours() {
        BusinessHours inactiveHours = new BusinessHours(
            Name = BUSINESS_HOURS_NAME,
            IsActive = false
        );
        try {
            CaseSlaInitializationAction.getBusinessHoursId(new List<BusinessHours>{ inactiveHours });
            System.assert(false, 'Expected inactive Business Hours configuration to fail.');
        } catch (SlaDeadlineCalculator.CalculationException exceptionValue) {
            System.assert(exceptionValue.getMessage().contains('inactive'));
        }

        BusinessHours firstHours = new BusinessHours(Name = BUSINESS_HOURS_NAME, IsActive = true);
        BusinessHours secondHours = new BusinessHours(Name = BUSINESS_HOURS_NAME, IsActive = true);
        try {
            CaseSlaInitializationAction.getBusinessHoursId(
                new List<BusinessHours>{ firstHours, secondHours }
            );
            System.assert(false, 'Expected ambiguous Business Hours configuration to fail.');
        } catch (SlaDeadlineCalculator.CalculationException exceptionValue) {
            System.assert(exceptionValue.getMessage().contains('ambiguous'));
        }
    }

    @IsTest(SeeAllData=true)
    static void rejectsMissingAndUnsupportedPriority() {
        BusinessHours supportHours = getBusinessHours();
        Datetime startTime = Datetime.newInstanceGMT(2026, 3, 16, 9, 0, 0);

        assertPriorityFailure(startTime, null, supportHours.Id, 'Priority is required');
        assertPriorityFailure(startTime, 'Urgent', supportHours.Id, 'Unsupported Case Priority');
    }

    @IsTest(SeeAllData=true)
    static void doesNotOverwriteExistingDeadlines() {
        getBusinessHours();
        Datetime responseDeadline = Datetime.newInstanceGMT(2026, 3, 16, 12, 0, 0);
        Datetime resolutionDeadline = Datetime.newInstanceGMT(2026, 3, 17, 12, 0, 0);
        Case existingCase = newCase('High');
        existingCase.Response_Deadline__c = responseDeadline;
        existingCase.Resolution_Deadline__c = resolutionDeadline;
        Database.insert(existingCase, AccessLevel.SYSTEM_MODE);

        CaseSlaInitializationAction.initialize(new List<Id>{ existingCase.Id });

        Case actual = [
            SELECT Response_Deadline__c, Resolution_Deadline__c
            FROM Case
            WHERE Id = :existingCase.Id
        ];
        System.assertEquals(responseDeadline, actual.Response_Deadline__c);
        System.assertEquals(resolutionDeadline, actual.Resolution_Deadline__c);
    }

    @IsTest(SeeAllData=true)
    static void rejectsPartiallyPopulatedDeadlines() {
        getBusinessHours();
        Case partialCase = newCase('High');
        partialCase.Response_Deadline__c = Datetime.newInstanceGMT(2026, 3, 16, 12, 0, 0);

        try {
            Database.insert(partialCase, AccessLevel.SYSTEM_MODE);
            System.assert(false, 'Expected record-triggered initialization to reject partial deadlines.');
        } catch (DmlException exceptionValue) {
            System.assert(exceptionValue.getMessage().contains('only one SLA deadline'));
        }
    }

    private static BusinessHours getBusinessHours() {
        List<BusinessHours> matchingHours = [
            SELECT Id, Name, IsActive, TimeZoneSidKey
            FROM BusinessHours
            WHERE Name = :BUSINESS_HOURS_NAME
            LIMIT 2
        ];
        Id businessHoursId = CaseSlaInitializationAction.getBusinessHoursId(matchingHours);
        System.assertEquals('Europe/Berlin', matchingHours[0].TimeZoneSidKey);
        System.assertEquals(true, matchingHours[0].IsActive);
        System.assertEquals(matchingHours[0].Id, businessHoursId);
        return matchingHours[0];
    }

    private static Case newCase(String priority) {
        return new Case(
            Subject = 'SLA calculation test',
            Status = 'New',
            Origin = 'Phone',
            Priority = priority
        );
    }

    private static void assertCalculatedDuration(
        Id businessHoursId,
        Datetime startTime,
        String priority,
        Integer responseHours,
        Integer resolutionHours
    ) {
        SlaDeadlineCalculator.Deadlines deadlines = SlaDeadlineCalculator.calculate(
            startTime,
            priority,
            businessHoursId
        );
        assertBusinessHoursDuration(businessHoursId, startTime, deadlines.responseDeadline, responseHours);
        assertBusinessHoursDuration(
            businessHoursId,
            startTime,
            deadlines.resolutionDeadline,
            resolutionHours
        );
    }

    private static void assertCaseDeadlines(
        Case caseRecord,
        Id businessHoursId,
        Datetime startTime,
        Integer responseHours,
        Integer resolutionHours
    ) {
        System.assertNotEquals(null, caseRecord);
        System.assertEquals('On Track', caseRecord.SLA_Status__c);
        assertBusinessHoursDuration(
            businessHoursId,
            startTime,
            caseRecord.Response_Deadline__c,
            responseHours
        );
        assertBusinessHoursDuration(
            businessHoursId,
            startTime,
            caseRecord.Resolution_Deadline__c,
            resolutionHours
        );
    }

    private static void assertBusinessHoursDuration(
        Id businessHoursId,
        Datetime startTime,
        Datetime deadline,
        Integer expectedHours
    ) {
        Long expectedMilliseconds = expectedHours * 60 * 60 * 1000;
        System.assertEquals(
            expectedMilliseconds,
            BusinessHours.diff(businessHoursId, startTime, deadline)
        );
        Datetime expectedDeadline = BusinessHours.add(businessHoursId, startTime, expectedMilliseconds);
        if (startTime.second() > 0 && BusinessHours.isWithin(businessHoursId, startTime)) {
            expectedDeadline = expectedDeadline.addSeconds(startTime.second());
        }
        System.assertEquals(expectedDeadline, deadline);
    }

    private static void assertPriorityFailure(
        Datetime startTime,
        String priority,
        Id businessHoursId,
        String expectedMessage
    ) {
        try {
            SlaDeadlineCalculator.calculate(startTime, priority, businessHoursId);
            System.assert(false, 'Expected invalid priority to fail.');
        } catch (SlaDeadlineCalculator.CalculationException exceptionValue) {
            System.assert(exceptionValue.getMessage().contains(expectedMessage));
        }
    }
}
