public with sharing class SlaDeadlineCalculator {
    public class CalculationException extends Exception {}

    public class Deadlines {
        public Datetime responseDeadline { get; private set; }
        public Datetime resolutionDeadline { get; private set; }

        private Deadlines(Datetime responseDeadline, Datetime resolutionDeadline) {
            this.responseDeadline = responseDeadline;
            this.resolutionDeadline = resolutionDeadline;
        }
    }

    public static Deadlines calculate(Datetime startTime, String priority, Id businessHoursId) {
        if (startTime == null) {
            throw new CalculationException('Case CreatedDate is required to calculate SLA deadlines.');
        }
        if (businessHoursId == null) {
            throw new CalculationException('An active SOH Business Hours record is required.');
        }
        if (String.isBlank(priority)) {
            throw new CalculationException('Case Priority is required to calculate SLA deadlines.');
        }

        Integer responseHours;
        Integer resolutionHours;
        if (priority == 'High') {
            responseHours = 1;
            resolutionHours = 4;
        } else if (priority == 'Medium') {
            responseHours = 4;
            resolutionHours = 8;
        } else if (priority == 'Low') {
            responseHours = 8;
            resolutionHours = 24;
        } else {
            throw new CalculationException('Unsupported Case Priority "' + priority + '". Expected High, Medium, or Low.');
        }

        Long responseMilliseconds = responseHours * 60 * 60 * 1000;
        Long resolutionMilliseconds = resolutionHours * 60 * 60 * 1000;
        Datetime responseDeadline = BusinessHours.add(businessHoursId, startTime, responseMilliseconds);
        Datetime resolutionDeadline = BusinessHours.add(businessHoursId, startTime, resolutionMilliseconds);

        if (responseDeadline == null || resolutionDeadline == null) {
            throw new CalculationException('Business Hours could not calculate one or more SLA deadlines.');
        }

        if (startTime.second() > 0 && BusinessHours.isWithin(businessHoursId, startTime)) {
            // BusinessHours.add drops the start's seconds when the start is in business hours.
            responseDeadline = responseDeadline.addSeconds(startTime.second());
            resolutionDeadline = resolutionDeadline.addSeconds(startTime.second());
        }

        return new Deadlines(responseDeadline, resolutionDeadline);
    }
}
