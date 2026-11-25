import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';
import { refreshGraphQL, gql, graphql } from 'lightning/uiGraphQLApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import CASE_OBJECT from '@salesforce/schema/Case';
import CASE_NUMBER_FIELD from '@salesforce/schema/Case.CaseNumber';
import CREATED_DATE_FIELD from '@salesforce/schema/Case.CreatedDate';
import DESCRIPTION_FIELD from '@salesforce/schema/Case.Description';
import PRIORITY_FIELD from '@salesforce/schema/Case.Priority';
import RESOLUTION_DEADLINE_FIELD from '@salesforce/schema/Case.Resolution_Deadline__c';
import RESOLUTION_NOTES_FIELD from '@salesforce/schema/Case.Resolution_Notes__c';
import RESPONSE_DEADLINE_FIELD from '@salesforce/schema/Case.Response_Deadline__c';
import SERVICE_FIELD from '@salesforce/schema/Case.Service__c';
import SLA_STATUS_FIELD from '@salesforce/schema/Case.SLA_Status__c';
import STATUS_FIELD from '@salesforce/schema/Case.Status';
import SUBJECT_FIELD from '@salesforce/schema/Case.Subject';

const CASE_QUERY = gql`
    query CaseManagementWorkspaceCases {
        uiapi {
            query {
                Case(first: 2000, orderBy: { CreatedDate: { order: DESC } }) {
                    edges {
                        node {
                            Id
                            CaseNumber {
                                value
                            }
                            Subject {
                                value
                            }
                            Status {
                                value
                            }
                            Priority {
                                value
                            }
                            Service__r {
                                Name {
                                    value
                                }
                            }
                            CreatedDate {
                                value
                            }
                            Response_Deadline__c {
                                value
                            }
                            Resolution_Deadline__c {
                                value
                            }
                            SLA_Status__c {
                                value
                            }
                        }
                    }
                }
            }
        }
    }
`;

const COLUMNS = [
    { label: 'Case Number', fieldName: 'caseNumber', type: 'text', initialWidth: 110 },
    { label: 'Subject', fieldName: 'subject', type: 'text', wrapText: true },
    { label: 'Status', fieldName: 'status', type: 'text', initialWidth: 105 },
    { label: 'Priority', fieldName: 'priority', type: 'text', initialWidth: 95 },
    { label: 'Related Service', fieldName: 'serviceName', type: 'text', wrapText: true },
    {
        label: 'Created Date',
        fieldName: 'createdDate',
        type: 'date',
        typeAttributes: {
            year: 'numeric',
            month: 'short',
            day: '2-digit',
            hour: '2-digit',
            minute: '2-digit'
        },
        initialWidth: 170
    },
    {
        label: 'Response Deadline',
        fieldName: 'responseDeadline',
        type: 'date',
        typeAttributes: {
            year: 'numeric',
            month: 'short',
            day: '2-digit',
            hour: '2-digit',
            minute: '2-digit'
        },
        initialWidth: 170
    },
    {
        label: 'Resolution Deadline',
        fieldName: 'resolutionDeadline',
        type: 'date',
        typeAttributes: {
            year: 'numeric',
            month: 'short',
            day: '2-digit',
            hour: '2-digit',
            minute: '2-digit'
        },
        initialWidth: 175
    },
    { label: 'SLA Status', fieldName: 'slaStatus', type: 'text', initialWidth: 120 }
];

const ALL_STATUS_OPTION = { label: 'All statuses', value: '' };
const ALL_PRIORITY_OPTION = { label: 'All priorities', value: '' };
const ALL_SLA_STATUS_OPTION = { label: 'All SLA statuses', value: '' };

export default class CaseManagementWorkspace extends NavigationMixin(LightningElement) {
    caseObject = CASE_OBJECT;
    caseNumberField = CASE_NUMBER_FIELD;
    subjectField = SUBJECT_FIELD;
    descriptionField = DESCRIPTION_FIELD;
    statusField = STATUS_FIELD;
    priorityField = PRIORITY_FIELD;
    serviceField = SERVICE_FIELD;
    responseDeadlineField = RESPONSE_DEADLINE_FIELD;
    resolutionDeadlineField = RESOLUTION_DEADLINE_FIELD;
    slaStatusField = SLA_STATUS_FIELD;
    resolutionNotesField = RESOLUTION_NOTES_FIELD;

    columns = COLUMNS;
    cases = [];
    statusOptions = [ALL_STATUS_OPTION];
    priorityOptions = [ALL_PRIORITY_OPTION];
    slaStatusOptions = [ALL_SLA_STATUS_OPTION];
    metadataErrors = {};
    queryErrorMessage;
    refreshErrorMessage;
    saveErrorMessage;
    statusFilter = '';
    priorityFilter = '';
    slaStatusFilter = '';
    selectedCaseId;
    selectedCaseNumber;
    defaultRecordTypeId;
    hasLoadedCases = false;
    wiredCasesResult;

    @wire(getObjectInfo, { objectApiName: CASE_OBJECT })
    wiredObjectInfo({ data, error }) {
        if (data) {
            this.defaultRecordTypeId = data.defaultRecordTypeId;
            this.clearMetadataError('objectInfo');
        } else if (error) {
            this.setMetadataError('objectInfo', 'Case metadata', error);
        }
    }

    @wire(getPicklistValues, {
        recordTypeId: '$defaultRecordTypeId',
        fieldApiName: STATUS_FIELD
    })
    wiredStatusValues({ data, error }) {
        this.setPicklistOptions('statusOptions', ALL_STATUS_OPTION, 'Status', data, error);
    }

    @wire(getPicklistValues, {
        recordTypeId: '$defaultRecordTypeId',
        fieldApiName: PRIORITY_FIELD
    })
    wiredPriorityValues({ data, error }) {
        this.setPicklistOptions(
            'priorityOptions',
            ALL_PRIORITY_OPTION,
            'Priority',
            data,
            error
        );
    }

    @wire(getPicklistValues, {
        recordTypeId: '$defaultRecordTypeId',
        fieldApiName: SLA_STATUS_FIELD
    })
    wiredSlaStatusValues({ data, error }) {
        this.setPicklistOptions(
            'slaStatusOptions',
            ALL_SLA_STATUS_OPTION,
            'SLA Status',
            data,
            error
        );
    }

    @wire(graphql, { query: CASE_QUERY })
    wiredCases(result) {
        this.wiredCasesResult = result;
        const { data, errors } = result;

        if (errors?.length) {
            this.cases = [];
            this.queryErrorMessage = errors.map((error) => error.message).join(' ');
            this.hasLoadedCases = true;
            return;
        }

        if (data) {
            const edges = data.uiapi.query.Case.edges ?? [];
            this.cases = edges.map(({ node }) => ({
                id: node.Id,
                caseNumber: node.CaseNumber?.value ?? '',
                subject: node.Subject?.value ?? '',
                status: node.Status?.value ?? '',
                priority: node.Priority?.value ?? '',
                serviceName: node.Service__r?.Name?.value ?? '',
                createdDate: node.CreatedDate?.value ?? null,
                responseDeadline: node.Response_Deadline__c?.value ?? null,
                resolutionDeadline: node.Resolution_Deadline__c?.value ?? null,
                slaStatus: node.SLA_Status__c?.value ?? ''
            }));
            this.queryErrorMessage = undefined;
            this.hasLoadedCases = true;
        }
    }

    get isLoading() {
        return !this.hasLoadedCases && !this.queryErrorMessage;
    }

    get metadataErrorMessage() {
        return Object.values(this.metadataErrors).join(' ');
    }

    get filteredCases() {
        return this.cases.filter(
            (caseRecord) =>
                (!this.statusFilter || caseRecord.status === this.statusFilter) &&
                (!this.priorityFilter || caseRecord.priority === this.priorityFilter) &&
                (!this.slaStatusFilter || caseRecord.slaStatus === this.slaStatusFilter)
        );
    }

    get hasCases() {
        return this.filteredCases.length > 0;
    }

    get selectedRows() {
        return this.selectedCaseId ? [this.selectedCaseId] : [];
    }

    get detailTitle() {
        return this.selectedCaseNumber
            ? `Case ${this.selectedCaseNumber}`
            : 'Case Details';
    }

    setPicklistOptions(propertyName, allOption, label, data, error) {
        const errorKey = propertyName;
        if (error) {
            this.setMetadataError(errorKey, label, error);
            return;
        }
        if (data) {
            this[propertyName] = [
                allOption,
                ...data.values.map(({ label: optionLabel, value }) => ({
                    label: optionLabel,
                    value
                }))
            ];
            this.clearMetadataError(errorKey);
        }
    }

    setMetadataError(key, label, error) {
        this.metadataErrors = {
            ...this.metadataErrors,
            [key]: `${label}: ${this.getErrorMessage(error)}`
        };
    }

    clearMetadataError(key) {
        if (this.metadataErrors[key]) {
            const updatedErrors = { ...this.metadataErrors };
            delete updatedErrors[key];
            this.metadataErrors = updatedErrors;
        }
    }

    getErrorMessage(error) {
        if (Array.isArray(error?.body)) {
            return error.body.map(({ message }) => message).join(', ');
        }
        return error?.body?.message || error?.message || 'Salesforce returned an unknown error.';
    }

    handleStatusFilterChange(event) {
        this.statusFilter = event.detail.value;
        this.clearSelection();
    }

    handlePriorityFilterChange(event) {
        this.priorityFilter = event.detail.value;
        this.clearSelection();
    }

    handleSlaStatusFilterChange(event) {
        this.slaStatusFilter = event.detail.value;
        this.clearSelection();
    }

    handleRowSelection(event) {
        const [selectedCase] = event.detail.selectedRows;
        this.selectedCaseId = selectedCase?.id;
        this.selectedCaseNumber = selectedCase?.caseNumber;
        this.saveErrorMessage = undefined;
        this.refreshErrorMessage = undefined;
    }

    clearSelection() {
        this.selectedCaseId = undefined;
        this.selectedCaseNumber = undefined;
        this.saveErrorMessage = undefined;
        this.refreshErrorMessage = undefined;
    }

    handleOpenCase() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.selectedCaseId,
                objectApiName: 'Case',
                actionName: 'view'
            }
        });
    }

    handleSaveSuccess() {
        this.saveErrorMessage = undefined;
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Case updated',
                message: 'Your changes were saved.',
                variant: 'success'
            })
        );
        refreshGraphQL(this.wiredCasesResult).catch((error) => {
            this.refreshErrorMessage = this.getErrorMessage(error);
        });
    }

    handleSaveError(event) {
        this.saveErrorMessage =
            event.detail?.message || 'Salesforce could not save the Case changes.';
    }
}
