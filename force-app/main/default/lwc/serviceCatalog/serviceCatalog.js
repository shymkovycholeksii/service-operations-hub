import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { encodeDefaultFieldValues } from 'lightning/pageReferenceUtils';
import { gql, graphql } from 'lightning/uiGraphQLApi';

const SERVICE_CATALOG_QUERY = gql`
    query ActiveServices {
        uiapi {
            query {
                Service__c(
                    first: 2000
                    where: { Active__c: { eq: true } }
                    orderBy: { Name: { order: ASC } }
                ) {
                    edges {
                        node {
                            Id
                            Name {
                                value
                            }
                            Category__c {
                                value
                            }
                            Description__c {
                                value
                            }
                            Active__c {
                                value
                            }
                        }
                    }
                }
            }
        }
    }
`;

export default class ServiceCatalog extends NavigationMixin(LightningElement) {
    services = [];
    errorMessage;
    hasLoaded = false;

    @wire(graphql, { query: SERVICE_CATALOG_QUERY })
    wiredServices({ data, errors }) {
        if (errors?.length) {
            this.services = [];
            this.errorMessage = errors.map((error) => error.message).join(' ');
            this.hasLoaded = true;
            return;
        }

        if (data) {
            const edges = data.uiapi.query.Service__c.edges ?? [];
            this.services = edges.map(({ node }) => {
                const category = node.Category__c?.value;
                const description = node.Description__c?.value;
                return {
                    id: node.Id,
                    name: node.Name.value,
                    status: node.Active__c.value ? 'Active' : 'Inactive',
                    category,
                    hasCategory: Boolean(category),
                    description,
                    hasDescription: Boolean(description)
                };
            });
            this.errorMessage = undefined;
            this.hasLoaded = true;
        }
    }

    get isLoading() {
        return !this.hasLoaded;
    }

    get showError() {
        return Boolean(this.errorMessage);
    }

    get hasServices() {
        return this.services.length > 0;
    }

    handleNavigate(event) {
        const recordId = event.currentTarget.dataset.recordId;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId,
                objectApiName: 'Service__c',
                actionName: 'view'
            }
        });
    }

    handleCreateRequest(event) {
        const serviceId = event.currentTarget.dataset.recordId;
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Case',
                actionName: 'new'
            },
            state: {
                defaultFieldValues: encodeDefaultFieldValues({
                    Service__c: serviceId
                })
            }
        });
    }
}
