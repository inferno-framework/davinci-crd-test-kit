# Controlling Responses from Inferno's Simulated CRD Service

During the CRD Client tests, provider systems are asked to demonstrate
that they can handle conformant cards and system actions retured by CRD Payer Services
and allow users to see and take actions based on these returned details.
However, provider systems are not expected to be able to handle all conformant
responses because details within them, such as specific orders or terminologies
in use, may not be configured within the provider system. To allow testers to
demonstrate the capabilities of their systems without the need to perform
Inferno-specific configuration, Inferno provides testers with the option to specify
the responses to hook invocations made against Inferno during a testing session.

Because this configuration can be complex, Inferno also provides an option for it to
mock simple responses so that testers can get started more easily.

## Mocked Responses

Inferno can generate (mostly) static versions of [each of the cards and system actions specified
by the CRD IG](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html). When no custom response
template is provided in the test inputs for a hook group, then Inferno will mock an example of each
card type selected in the "Response types to return..." input. In addition to the logic described
below, all returned cards get a unique `uuid` and their summary is prefixed with the invoked hook.

- **[External Reference](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#external-reference)**: 
  Inferno's [static external reference card](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/card_responses/external_reference.json)
  provides a link to the CRD IG's [External Reference definition](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#external-reference).
- **[Instructions](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#instructions)**: Inferno's [static instructions card](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/card_responses/instructions.json)
  provides generic instructions. It is always included in a mocked response if no other cards or system
  actions would be returned.
- **[Coverage Information](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#coverage-information)**:
  Inferno will build a system action to add a [`coverage-information` extension](https://hl7.org/fhir/us/davinci-crd/STU2/StructureDefinition-ext-coverage-information.html)
  to each order associated with the hook invocation. The target coverage must either be provided
  as a prefetched resource or found via a query for active coverages for the patient at the time of
  the invocation using the FHIR server access details found in the hook request. If no coverage can
  be found, then this response type will not be included in Inferno's response. If returned, the
  extension will indicate that the order is "covered" (in [`covered`](https://hl7.org/fhir/us/davinci-crd/STU2/StructureDefinition-ext-coverage-information-definitions.html#key_Extension.extension:covered)),
  that no prior auth is necessary ("no-auth" in [`pa-needed`](https://hl7.org/fhir/us/davinci-crd/STU2/StructureDefinition-ext-coverage-information-definitions.html#key_Extension.extension:pa-needed))
  with the current [`date`](https://hl7.org/fhir/us/davinci-crd/STU2/StructureDefinition-ext-coverage-information-definitions.html#key_Extension.extension:date)
  and a random [`coverage-assertion-id](https://hl7.org/fhir/us/davinci-crd/STU2/StructureDefinition-ext-coverage-information-definitions.html#key_Extension.extension:coverage-assertion-id)
  indicated. No other sub-extensions of the [`coverage-information` extension](https://hl7.org/fhir/us/davinci-crd/STU2/StructureDefinition-ext-coverage-information.html) will be populated. The target
  order resources for each hook include:
  - *appointment-book*: each Appoinment in `context.appointments`.
  - *encounter-start* and *encounter-discharge*: the Encounter refered to by `context.encounterId` 
    which must either be provided as a prefetched resource or found via a read for the indicated
    Encounter at the time of the invocation using the FHIR server access details found in the hook request.
  - *order-sign* and *order-select*: each entry in `context.draftOrders`.
  - *order-dispatch*: the resource refered to by `context.order` which must either be provided as a
    prefetched resource or found via a read for the indicated resource at the time of the invocation
    using the FHIR server access details found in the hook request.
- **[Propose Alternate Request](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#propose-alternate-request)**:
  Inferno's [propose alternate request card template](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/card_responses/propose_alternate_request.json)
  is only available on the `order-sign`, `order-select`, and `order-dispatch` hooks. It provides a
  suggestion for the system to delete one of the indicated orders and recreate it. The selected order
  will either be the first order in `context.draftOrders` for the `order-sign`, `order-select` hooks
  or the order referenced by `context.order` for the `order-dispatch` hook, in which case it
  must either be provided as a prefetched resource or found via a read for the indicated resource
  at the time of the invocation using the FHIR server access details found in the hook request.
- **[Identify Companion/Prerequisite Orders](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#identify-additional-orders-as-companionsprerequisites-for-current-order)**:
  Inferno's [companion/prerequisite card template](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/card_responses/propose_alternate_request.json)
  is only available on the `order-sign`, `order-select`, and `order-dispatch` hooks.
  It provides a suggestion for the system to create a ServiceRequest for a monthly physical assessment
  for the next three months. The ServiceRequest will be updated to reference the hook request's patient
  (`context.patientId`), the hook requests user (`context.userId`) as the requester, and an `authoredOn`
  date of the current date.
companions_prerequisites
- **[Request Form Completion](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#request-form-completion)**:
  Inferno's [request form completion card template](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/card_responses/request_form_completion.json)
  provides suggestions for the system to create a cancer Questionnaire resource and
  an associated Task resource to track its completion. The Task resource in the template will be
  updated to be [`for`](https://hl7.org/fhir/us/davinci-crd/STU2/StructureDefinition-profile-taskquestionnaire-definitions.html#key_Task.for)
  the patient referenced in the hook invocation (`context.patientId`) and have the current date
  for [`authoredOn`](https://hl7.org/fhir/us/davinci-crd/STU2/StructureDefinition-profile-taskquestionnaire-definitions.html#key_Task.authoredOn).
- **[Create or Update Coverage Information](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#create-or-update-coverage-information)**:
  Inferno's [create or update card template](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/card_responses/create_update_coverage_information.json)
  provides suggestions for the system to either update the existing coverage if one was found (provided via prefetch or retrieved via query) or create one otherwise. If updating the existing coverage, it will
  change the [`period`](https://hl7.org/fhir/us/davinci-crd/STU2/StructureDefinition-profile-coverage-definitions.html#key_Coverage.period)
  to run from the current date to 1 month in the future. If creating a new coverage, it will create
  a draft self-pay coverage for the patient indicated in the hook request (`context.patientId`).
- **[Launch SMART Application](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#launch-smart-application)**:
  Inferno's [static launch SMART application card](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/card_responses/launch_smart_app.json)
  points to the launch url for the CRD Client test suite. 

## Tester-directed Custom Responses

To better support the demonstration and testing of the full range CRD client capabilities,
Inferno provides a mechanism for testers to specify how Inferno will respond to hook
invocations made by their system. Inferno will use the hook request to select and complete
cards and actions from a template hook response provided by the tester. 

At a high level testers will provide a CDS Hook response with a partially specified set of cards
and system actions. Those cards and actions can include
- Within cards and actions, an extension containing a FHIRPath expression that selects requests
  for which the card should be returned.
- Within actions, an extension containing a FHIRPath expression that selects resources to use
  as a target for the action.
- Within CDS Hooks response fields and FHIR elements, tokens containing a FHIRPath expression
  to be executed against the request that select a value to include in the response.

When a hook request is received, Inferno will evaluate the FHIRPath expressions in the tokens and
extensions and use the results to create a response. Testers are responsible for making sure that these
responses will be conformant, and if a returned response is not conformant the tests will fail.

### Template Configuration Details

#### Cards

Cards can be found in the top-level `cards` field. Testers are responsible for providing all
[required content](https://cds-hooks.hl7.org/2.0/#card-attributes), including the
`summary`, `indicator`, and `source` fields. If the `uuid` field is populated, Inferno will
replace it with a random uuid each time it is returned so that it will always be unique. The
same is true for the `suggestion.uuid` field. The following configuration options are
available to control which cards are returned for a given request and their content:
- The [`com.inferno.inclusionCriteria` extension](#cominfernoinclusioncriteria-extension) can
  be included to limit the requests for which the card is included in the response. 
- [Expression tokens](#expression-tokens) can appear in any descendant field or FHIR element to
  make the value dependent on content in the request.

#### Actions

Actions can be found both within the top-level `systemActions` field and nested within `suggestions`
found on cards. The same field requirements, configuration options, instantiation logic
apply in both cases.

Testers must populate the `type` and `description` fields of each action and may provide
details in the `resource` or `resourceId` field depending on the `type`. Data in the
`resource` field does not have to be a complete and valid resource as long as the
[`com.inferno.resourceSelectionCriteria` extension](#cominfernoresourceselectioncriteria-extension)
is defined. In that case, the contents of the `resource` field will be merged into the selected
resource(s) when instantiating the action.

The same configuration options and logic apply in both cases:
- The [`com.inferno.inclusionCriteria` extension](#cominfernoinclusioncriteria-extension) can
  be included to limit the requests for which the action is included in the response. 
- The [`com.inferno.resourceSelectionCriteria` extension](#cominfernoresourceselectioncriteria-extension)
  can be included to specify target resources to use when building the action, which may cause
  multiple copies to be included in a response.
- [Expression tokens](#expression-tokens) can appear in any descendant field or FHIR element to
  make the value dependent on content in the request.

#### `com.inferno.inclusionCriteria` Extension

When defined on a card or action, this extension controls when the entity will be present in the
response to a request. The extension value will either be a FHIRPath expression or the literal
string `default`. Specifics for each type of value:
- *No value*: If the extension is not present or has an empty value, then the entity is always
  included in the response.
- *FHIRPath expression*: If that expression evaluates to a non-empty collection when executed
  against the hook request, then the entity will be included in the response. Otherwise, the
  entity is not included in the response.
- *`default`*: The specifics depend of whether the entity is a card or action:
  - **Card**: If no other cards are included in the response, then this card will be included.
  - **Action**: If there is no [`com.inferno.resourceSelectionCriteria` extension](#cominfernoresourceselectioncriteria-extension) and no other actions are (yet) included in the
    response, then this card will be included. If there is a [`com.inferno.resourceSelectionCriteria` extension](#cominfernoresourceselectioncriteria-extension), then the action will be
    instantiated against any selected resource for which no action in this list has yet been
    instantiated.

This can be used, for example, to only include a card when the hook has been triggered
on a certain type of order:

```json
{ "cards": [
  {
    "summary": "MedicationRequest Instructions",
    ...,
    "extension": {
      "com.inferno.inclusionCriteria": "context.draftOrders.entry.resource.ofType(MedicationRequest)"
    }
  }
]}
```

Notes:
- This extension will be removed from the card or action before Inferno returns it to the requesting client.

#### `com.inferno.resourceSelectionCriteria` Extension

When defined on an action, this extension controls how many copies of the action will be included
in the response and the target resource for each. The extension value will be a FHIRPath expression.
For each resource returned in the collection when the expression is evluated against the hook request,
a copy of the action will be included in the response. How the target resource is used in
instantiating the action depends on the `type`:
- `delete`: the target resource will be used as the reference in the action's `resourceId` field
  (`<resourceType>/<id>`)
- `create` or `update`: the contents of the target resource will be used as the base for
  the `resource` field. If the action template has contents in the `resource` field, then
  those elements will be merged into the target resource. When performing the merge,
  - All `resource.extension` entries defined in the action template will be added to the target
    resource's `extension` list.
  - All other top-level elements defined directly under `resource` the action template will be be
    added at the top-level to the target resource, completely replacing any existing content
    in that element in the target resource.

This can be used, for example, to add a coverage-information extension to each of the resources
in the `context.draftOrders` field of an `order-sign` request:

```json
{ "cards": [],
  "systemActions": [
    {
      "type": "update",
      "description": "Add the coverage-information extension",
      "resource": {
        "extension": [
          {
            "url": "http://hl7.org/fhir/us/davinci-crd/StructureDefinition/ext-coverage-information",
            "extension": [
              {
                "url": "covered",
                "valueCode": "covered"
              },
              ...
            ]
          }
        ]
      },
      "extension": {
        "com.inferno.resourceSelectionCriteria": "context.draftOrders.entry.resource"
      }
    }
  ]
}
```

Notes:
- If the evaluation of the expression in a `com.inferno.resourceSelectionCriteria` extension
  returns no resource, then no copies of the action will be included, even if the
  expression in the `com.inferno.inclusionCriteria` extension directs the action to be included.
- the `com.inferno.resourceSelectionCriteria` can be used with or without the 
  `com.inferno.inclusionCriteria` extension and vice versa. Here are some example use
  case for each combination:
  - *`com.inferno.inclusionCriteria` extension only*: Include a suggestion with a `create` action for
    a static resource when a ServiceRequest with a specific code is included in the hook request.
  - *`com.inferno.resourceSelectionCriteria` extension only*: always add a coverage-information
    extension to each draftOrder.
  - *Both `com.inferno.inclusionCriteria` and `com.inferno.resourceSelectionCriteria` extensions*:
    For a specific patient only (inclusion criteria), add a suggestion to modify all MedicationRequest
    resources for a specific medication to use a generic version of that medication (resource selection
    criteria).
- This extension will be removed from the action before Inferno returns it to the requesting client.

#### Expression Tokens

Expression tokens for dynamic content indicated by a FHIRPath expression surrounded by double curly braces
(`{{<FHIRPath expression}}`) within fields and sub-fields of the action. The indicated FHIRPath
expression will be evaluated against the hook request and the result used to replace the token.

These can be used, for example, to make sure that resources in the returned response reference
the patient the hook was invoked for using `{{context.patientId}})`.

Notes:
- Entries within the returned collection that are not data types (lists or objects) will be ignored.
- If multiple entries (not including ignored and nil entries) are returned, then the results will
  be turned into a comma-delimited list for use in replacing the token.
- While the syntax follows CDS Hooks prefetch tokens, Inferno allows full FHIRPath expressions
  instead of the limited set that CDS Hooks allows.

#### `coverage-information` Defaulting

System actions that add the `coverage-information` extension to resources are a response type
for which CRD requires client support. To help testers specify this card type, Inferno will
populate the following `coverage-information` sub-extensions when not found in
`coverage-information` extensions within the response template:
- `coverage` sub-extension: Inferno will add a reference to the target Patient's coverage, as
  identified as the first coverage made available via prefetch or returned in response to
  a query for active coverages.
- `date` sub-extension: Inferno will add the current date (UTC)
- `coverage-assertion-id` sub-extension: Inferno will add a random 32-bit hex value.

Notes:
- Inferno will not override a value provided for a sub-extension that would be defaulted. Thus,
  Expression tokens can be included to provide a specific request-dependent value that is
  different from Inferno's default.

### FHIRPath Evaluation Limitations

The configurability of responses relies heavily on FHIRPath and is therefore limited by the
FHIRPath language and the parts of it that are implemented by Inferno's FHIRPath evaluation
engine. Inferno currently uses the FHIRPath engine built into the official HL7 FHIR validator
to evaluate FHIRPath expressions on FHIR resources. For CDS Hook request fields, Inferno implements
a small subset of FHIRPath to bridge to the point in those requests that contain FHIR resources.

Inferno's FHIRPath evaluation for CDS Hook requests provides the most limitations. Thes
- The [FHIRPath expression](https://hl7.org/fhirpath/N1/index.html#expressions) must be
  a path with function calls. The use of literals and operators (e.g. the union operator
  `<exp 1> | <exp 2>`) is not currently supported.
- The first segment of the path must be a field of the CDS Hook request. The expression cannot start with a `%` context variable or a resource type, or a function.
- The only function allowed on non-FHIR paths is `where(<field> = <value>)`, where `<field>`
  must be a single label without any concatenation (`.` characters).

Note that once the path reaches a FHIR resource, then other features are supported, such as
- the `ofType` function, e.g., `context.draftOrders.entry.resource.ofType(ServiceRequest)`
- more complex where functions, e.g., `context.draftOrders.entry.resource.ofType(ServiceRequest).where(code.coding.code = '12345')`

Inferno's use of the HL7 FHIR Validator's FHIRPath engine comes with some restrictions as well.
- The engine is not configured to resolve profiles or value sets. It has the base FHIR R4
  definions loaded, so functions like `ofType` will work, but types defined in IGs or elsewhere
  cannot be used.
- The FHIRPath engine may not implement the entire [FHIRPath specication](https://hl7.org/fhirpath/N1/index.html).

The Inferno team is open to adding support for additional FHIRPath functional. Please submit a
[github issue](https://github.com/inferno-framework/davinci-crd-test-kit/issues) with details
of your use case and the additional features that you believe are necessary.

### Complete Example

The following example illustrates the type of scenarios that can be setup using the custom response
templates. The details below include the template as well as sample requests and their responses.

#### Payer Business Logic Description

This scenario considers two patients, with ids `pat015` and `888`, each with different coverages
at the simulated payer. Both patients require prior authorization for an MRI with additional
information requested via DTR. Patient A has a limited formulary such that a request for
prescription-strength Advil will be denied and a [card proposing](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#propose-alternate-request) an equivalent generic medication.

#### Template

```json
{
  "cards": [
    {
      "summary": "Propose Alternative Generic Medication",
      "detail": "The patient's coverage limits access to name-brand medications. Consider this generic alternative.",
      "indicator": "info",
      "source": {
        "label": "Inferno",
        "url": "https://inferno.healthit.gov/",
        "topic": {
          "system": "http://hl7.org/fhir/us/davinci-crd/CodeSystem/temp",
          "code": "coverage-info",
          "display": "Coverage Information"
        }
      },
      "selectionBehavior": "any",
      "suggestions": [
        {
          "label": "Replace Advil order with generic Ibuprofen",
          "actions": [
            {
              "type": "delete",
              "description": "Delete the proposed Advil order",
              "extension": {
                "com.inferno.resourceSelectionCriteria": "context.draftOrders.entry.resource.ofType(MedicationRequest).where(subject.reference = 'Patient/pat015' and medication.coding.code = 'codeForAdvil')"
              }
            },
            {
              "type": "create",
              "description": "Create the generic Ibuprofen order",
              "resource": {
                "resourceType": "MedicationRequest",
                "subject": {
                  "reference": "Patient/{{context.patientId}}"
                },
                "status": "draft",
                "medicationCodeableConcept": {
                  "coding": [
                    {
                      "code": "codeForGenericIbuprofen"
                    }
                  ]
                }
              }
            }
          ]
        }
      ],
      "extension": {
        "com.inferno.inclusionCriteria": "context.draftOrders.entry.resource.ofType(MedicationRequest).where(subject.reference = 'Patient/pat015' and medication.coding.code = 'codeForAdvil').exists()"
      }
    }
  ],
  "systemActions": [
    {
      "type": "update",
      "description": "This order is covered",
      "resource": {
        "extension": [
          {
            "url": "http://hl7.org/fhir/us/davinci-crd/StructureDefinition/ext-coverage-information",
            "extension": [
              {
                "url": "covered",
                "valueCode": "covered"
              },
              {
                "url": "pa-needed",
                "valueCode": "no-auth"
              }
            ]
          }
        ]
      },
      "extension": {
        "com.inferno.inclusionCriteria": "default",
        "com.inferno.resourceSelectionCriteria": "context.draftOrders.entry.resource"
      }
    },
    {
      "type": "update",
      "description": "This order is not covered",
      "resource": {
        "extension": [
          {
            "url": "http://hl7.org/fhir/us/davinci-crd/StructureDefinition/ext-coverage-information",
            "extension": [
              {
                "url": "covered",
                "valueCode": "not-covered"
              }
            ]
          }
        ]
      },
      "extension": {
        "com.inferno.resourceSelectionCriteria": "context.draftOrders.entry.resource.ofType(MedicationRequest).where(subject.reference = 'Patient/pat015' and medication.coding.code = 'codeForAdvil')"
      }
    },{
      "type": "update",
      "description": "This order requires prior authorization",
      "resource": {
        "extension": [
          {
            "url": "http://hl7.org/fhir/us/davinci-crd/StructureDefinition/ext-coverage-information",
            "extension": [
              {
                "url": "covered",
                "valueCode": "conditional"
              },
              {
                "url": "pa-needed",
                "valueCode": "auth-needed"
              },
              {
                "url": "doc-needed",
                "valueCode": "clinical"
              },
              {
                "url": "questionnaire",
                "valueCanonical": "http://questionnaire.example.com/pa"
              }
            ]
          }
        ]
      },
      "extension": {
        "com.inferno.resourceSelectionCriteria": "context.draftOrders.entry.resource.ofType(ServiceRequest).where(code.coding.code = 'codeForMRI')"
      }
    }
  ]
}
```

#### Orders for Patient `pat015`

##### Request

Includes orders for
- a hospital bed device
- Prescription-strength Advil
- an MRI

```json
{
  "hookInstance": "d1577c69-dfbe-44ad-ba6d-3e05e953b2ea",
  "fhirServer": "https://inferno.healthit.gov/reference-server/r4",
  "hook": "order-sign",
  "fhirAuthorization": {
    "access_token": "SAMPLE_TOKEN",
    "token_type": "Bearer",
    "expires_in": 300,
    "scope": "patient/Patient.read patient/Observation.read",
    "subject": "cds-service4"
  },
  "context": {
    "userId": "Practitioner/pra1234",
    "patientId": "pat015",
    "encounterId": "enc-pat014",
    "draftOrders": {
      "resourceType": "Bundle",
      "entry": [
        {
          "resource": {
            "resourceType": "DeviceRequest",
            "id": "devreq-015-e0250",
            "meta": {
              "versionId": "1",
              "lastUpdated": "2024-05-08T09:47:16.992-04:00",
              "source": "#Odh5ejWjud85tvNJ",
              "profile": [
                "http://hl7.org/fhir/us/davinci-crd/R4/StructureDefinition/profile-devicerequest-r4"
              ]
            },
            "identifier": [
              {
                "type": {
                  "coding": [
                    {
                      "system": "http://terminology.hl7.org/CodeSystem/v2-0203",
                      "code": "PLAC"
                    }
                  ]
                },
                "value": "f105372f-bbef-442c-ad7a-708fee7f8c93"
              }
            ],
            "status": "draft",
            "intent": "original-order",
            "codeCodeableConcept": {
              "coding": [
                {
                  "system": "https://bluebutton.cms.gov/resources/codesystem/hcpcs",
                  "code": "E0250",
                  "display": "Hospital bed fixed height with any type of side rails, mattress"
                }
              ]
            },
            "subject": {
              "reference": "Patient/pat015"
            },
            "authoredOn": "2023-01-01T00:00:00Z",
            "requester": {
              "reference": "Practitioner/pra-hfairchild"
            },
            "performer": {
              "reference": "Practitioner/pra1234"
            },
            "insurance": [
              {
                "reference": "Coverage/cov015"
              }
            ]
          }
        },
        {
          "resource": {
            "resourceType": "MedicationRequest",
            "id": "MedicationRequest-advil",
            "status": "draft",
            "intent": "order",
            "medicationCodeableConcept": {
              "coding": [
                {
                  "code": "codeForAdvil",
                  "display": "Prescription Strength Advil"
                }
              ]
            },
            "subject": {
              "reference": "Patient/pat015"
            }
          }
        },
        {
          "resource": {
            "resourceType": "ServiceRequest",
            "id": "ServiceRequest-015-mri",
            "status": "draft",
            "intent": "order",
            "code": {
              "coding": [
                {
                  "code": "codeForMRI",
                  "display": "MRI"
                }
              ]
            },
            "subject": {
              "reference": "Patient/pat015"
            },
            "requester": {
              "reference": "Practitioner/pra-hfairchild"
            }
          }
        }
      ]
    }
  }
}
```

##### Custom Response

The response contains:
- a [propose alternative card](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#propose-alternate-request)
  to replace the order for Advil with one for generic Ibuprofen (type, code, patient matched the inclusion criteria) using delete (existing Advil order selected and its id populated in the `resourceId` field) and create (static, always included) actions.
- 3 system responses indicating whether each of the three orders is covered:
  - a hospital bed device: covered (from the default `systemAction` entry)
  - Prescription-strength Advil: not covered (type, code, patient matched the inclusion criteria)
  - an MRI: prior auth required (type and code matched the inclusion criteria)

```json
{
  "cards": [
    {
      "summary": "Propose Alternative Generic Medication",
      "detail": "The patient's coverage limits access to name-brand medications. Consider this generic alternative.",
      "indicator": "info",
      "source": {
        "label": "Inferno",
        "url": "https://inferno.healthit.gov/",
        "topic": {
          "system": "http://hl7.org/fhir/us/davinci-crd/CodeSystem/temp",
          "code": "coverage-info",
          "display": "Coverage Information"
        }
      },
      "selectionBehavior": "any",
      "suggestions": [
        {
          "label": "Replace Advil order with generic Ibuprofen",
          "actions": [
            {
              "type": "delete",
              "description": "Delete the proposed Advil order",
              "resourceId": "MedicationRequest/MedicationRequest-advil"
            },
            {
              "type": "create",
              "description": "Create the generic Ibuprofen order",
              "resource": {
                "resourceType": "MedicationRequest",
                "subject": {
                  "reference": "Patient/pat015"
                },
                "status": "draft",
                "medicationCodeableConcept": {
                  "coding": [
                    {
                      "code": "codeForGenericIbuprofen"
                    }
                  ]
                }
              }
            }
          ]
        }
      ]
    }
  ],
  "systemActions": [
    {
      "type": "update",
      "description": "This order is not covered",
      "resource": {
        "resourceType": "MedicationRequest",
        "id": "MedicationRequest-advil",
        "status": "draft",
        "intent": "order",
        "medicationCodeableConcept": {
          "coding": [
            {
              "code": "codeForAdvil",
              "display": "Prescription Strength Advil"
            }
          ]
        },
        "subject": {
          "reference": "Patient/pat015"
        },
        "extension": [
          {
            "url": "http://hl7.org/fhir/us/davinci-crd/StructureDefinition/ext-coverage-information",
            "extension": [
              {
                "url": "covered",
                "valueCode": "not-covered"
              },
              {
                "url": "coverage",
                "valueReference": {
                  "reference": "Coverage/cov015"
                }
              },
              {
                "url": "date",
                "valueDate": "2025-12-30"
              },
              {
                "url": "coverage-assertion-id",
                "valueString": "b7a3bceafb17ebba207efa65b9e466fdd2f50f6df9d59a45544d7c130e2dacd4"
              }
            ]
          }
        ]
      }
    },
    {
      "type": "update",
      "description": "This order requires prior authorization",
      "resource": {
        "resourceType": "ServiceRequest",
        "id": "ServiceRequest-015-mri",
        "status": "draft",
        "intent": "order",
        "code": {
          "coding": [
            {
              "code": "codeForMRI",
              "display": "MRI"
            }
          ]
        },
        "subject": {
          "reference": "Patient/pat015"
        },
        "requester": {
          "reference": "Practitioner/pra-hfairchild"
        },
        "extension": [
          {
            "url": "http://hl7.org/fhir/us/davinci-crd/StructureDefinition/ext-coverage-information",
            "extension": [
              {
                "url": "covered",
                "valueCode": "conditional"
              },
              {
                "url": "pa-needed",
                "valueCode": "auth-needed"
              },
              {
                "url": "doc-needed",
                "valueCode": "clinical"
              },
              {
                "url": "questionnaire",
                "valueCanonical": "http://questionnaire.example.com/pa"
              },
              {
                "url": "coverage",
                "valueReference": {
                  "reference": "Coverage/cov015"
                }
              },
              {
                "url": "date",
                "valueDate": "2025-12-30"
              },
              {
                "url": "coverage-assertion-id",
                "valueString": "ee1ccb46909f3bd21041e1ed1b9df18f7419894298f1bec909e0e998293b332e"
              }
            ]
          }
        ]
      }
    },
    {
      "type": "update",
      "description": "This order is covered",
      "resource": {
        "resourceType": "DeviceRequest",
        "id": "devreq-015-e0250",
        "meta": {
          "versionId": "1",
          "lastUpdated": "2024-05-08T09:47:16.992-04:00",
          "source": "#Odh5ejWjud85tvNJ",
          "profile": [
            "http://hl7.org/fhir/us/davinci-crd/R4/StructureDefinition/profile-devicerequest-r4"
          ]
        },
        "identifier": [
          {
            "type": {
              "coding": [
                {
                  "system": "http://terminology.hl7.org/CodeSystem/v2-0203",
                  "code": "PLAC"
                }
              ]
            },
            "value": "f105372f-bbef-442c-ad7a-708fee7f8c93"
          }
        ],
        "status": "draft",
        "intent": "original-order",
        "codeCodeableConcept": {
          "coding": [
            {
              "system": "https://bluebutton.cms.gov/resources/codesystem/hcpcs",
              "code": "E0250",
              "display": "Hospital bed fixed height with any type of side rails, mattress"
            }
          ]
        },
        "subject": {
          "reference": "Patient/pat015"
        },
        "authoredOn": "2023-01-01T00:00:00Z",
        "requester": {
          "reference": "Practitioner/pra-hfairchild"
        },
        "performer": {
          "reference": "Practitioner/pra1234"
        },
        "insurance": [
          {
            "reference": "Coverage/cov015"
          }
        ],
        "extension": [
          {
            "url": "http://hl7.org/fhir/us/davinci-crd/StructureDefinition/ext-coverage-information",
            "extension": [
              {
                "url": "covered",
                "valueCode": "covered"
              },
              {
                "url": "pa-needed",
                "valueCode": "no-auth"
              },
              {
                "url": "coverage",
                "valueReference": {
                  "reference": "Coverage/cov015"
                }
              },
              {
                "url": "date",
                "valueDate": "2025-12-30"
              },
              {
                "url": "coverage-assertion-id",
                "valueString": "c0fe5f6c5a53dddd8fe01e905d2aa8a14641a577d1e90d303c0b052a17c92086"
              }
            ]
          }
        ]
      }
    }
  ]
}
```

#### Orders for Patient `888`

##### Request

Includes orders for
- a hospital bed device
- Prescription-strength Advil
- an MRI

```json
{
  "hookInstance": "d1577c69-dfbe-44ad-ba6d-3e05e953b2ea",
  "fhirServer": "https://inferno.healthit.gov/reference-server/r4",
  "hook": "order-sign",
  "fhirAuthorization": {
    "access_token": "SAMPLE_TOKEN",
    "token_type": "Bearer",
    "expires_in": 300,
    "scope": "patient/Patient.read patient/Observation.read",
    "subject": "cds-service4"
  },
  "context": {
    "userId": "Practitioner/c4bb-Practitioner",
    "patientId": "888",
    "draftOrders": {
      "resourceType": "Bundle",
      "entry": [
        {
          "resource": {
            "resourceType": "DeviceRequest",
            "id": "devreq-888-e0250",
            "meta": {
              "versionId": "1",
              "lastUpdated": "2024-05-08T09:47:16.992-04:00",
              "source": "#Odh5ejWjud85tvNJ",
              "profile": [
                "http://hl7.org/fhir/us/davinci-crd/R4/StructureDefinition/profile-devicerequest-r4"
              ]
            },
            "identifier": [
              {
                "type": {
                  "coding": [
                    {
                      "system": "http://terminology.hl7.org/CodeSystem/v2-0203",
                      "code": "PLAC"
                    }
                  ]
                },
                "value": "f105372f-bbef-442c-ad7a-708fee7f8c93"
              }
            ],
            "status": "draft",
            "intent": "original-order",
            "codeCodeableConcept": {
              "coding": [
                {
                  "system": "https://bluebutton.cms.gov/resources/codesystem/hcpcs",
                  "code": "E0250",
                  "display": "Hospital bed fixed height with any type of side rails, mattress"
                }
              ]
            },
            "subject": {
              "reference": "Patient/888"
            },
            "authoredOn": "2023-01-01T00:00:00Z",
            "requester": {
              "reference": "Practitioner/c4bb-Practitioner"
            },
            "performer": {
              "reference": "Practitioner/c4bb-Practitioner"
            },
            "insurance": [
              {
                "reference": "Coverage/c4bb-Coverage"
              }
            ]
          }
        },
        {
          "resource": {
            "resourceType": "MedicationRequest",
            "id": "MedicationRequest-888-advil",
            "status": "draft",
            "intent": "order",
            "medicationCodeableConcept": {
              "coding": [
                {
                  "code": "codeForAdvil",
                  "display": "Prescription Strength Advil"
                }
              ]
            },
            "subject": {
              "reference": "Patient/888"
            }
          }
        },
        {
          "resource": {
            "resourceType": "ServiceRequest",
            "id": "ServiceRequest-888-mri",
            "status": "draft",
            "intent": "order",
            "code": {
              "coding": [
                {
                  "code": "codeForMRI",
                  "display": "MRI"
                }
              ]
            },
            "subject": {
              "reference": "Patient/888"
            },
            "requester": {
              "reference": "Practitioner/pra-hfairchild"
            }
          }
        }
      ]
    }
  }
}
```

##### Custom Response

The response contains:
- 3 system responses indicating whether each of the three orders is covered:
  - a hospital bed device: covered (from the default `systemAction` entry)
  - Prescription-strength Advil: covered (from the default `systemAction` entry)
  - an MRI: prior auth required (type and code matched the inclusion criteria)

```json
{
  "cards": [],
  "systemActions": [
    {
      "type": "update",
      "description": "This order requires prior authorization",
      "resource": {
        "resourceType": "ServiceRequest",
        "id": "ServiceRequest-888-mri",
        "status": "draft",
        "intent": "order",
        "code": {
          "coding": [
            {
              "code": "codeForMRI",
              "display": "MRI"
            }
          ]
        },
        "subject": {
          "reference": "Patient/888"
        },
        "requester": {
          "reference": "Practitioner/pra-hfairchild"
        },
        "extension": [
          {
            "url": "http://hl7.org/fhir/us/davinci-crd/StructureDefinition/ext-coverage-information",
            "extension": [
              {
                "url": "covered",
                "valueCode": "conditional"
              },
              {
                "url": "pa-needed",
                "valueCode": "auth-needed"
              },
              {
                "url": "doc-needed",
                "valueCode": "clinical"
              },
              {
                "url": "questionnaire",
                "valueCanonical": "http://questionnaire.example.com/pa"
              },
              {
                "url": "coverage",
                "valueReference": {
                  "reference": "Coverage/c4bb-Coverage"
                }
              },
              {
                "url": "date",
                "valueDate": "2025-12-30"
              },
              {
                "url": "coverage-assertion-id",
                "valueString": "40ddea494f4d660b859b7856cd3e9d40672a412cd917e55a356817e2c916ae1f"
              }
            ]
          }
        ]
      }
    },
    {
      "type": "update",
      "description": "This order is covered",
      "resource": {
        "resourceType": "DeviceRequest",
        "id": "devreq-888-e0250",
        "meta": {
          "versionId": "1",
          "lastUpdated": "2024-05-08T09:47:16.992-04:00",
          "source": "#Odh5ejWjud85tvNJ",
          "profile": [
            "http://hl7.org/fhir/us/davinci-crd/R4/StructureDefinition/profile-devicerequest-r4"
          ]
        },
        "identifier": [
          {
            "type": {
              "coding": [
                {
                  "system": "http://terminology.hl7.org/CodeSystem/v2-0203",
                  "code": "PLAC"
                }
              ]
            },
            "value": "f105372f-bbef-442c-ad7a-708fee7f8c93"
          }
        ],
        "status": "draft",
        "intent": "original-order",
        "codeCodeableConcept": {
          "coding": [
            {
              "system": "https://bluebutton.cms.gov/resources/codesystem/hcpcs",
              "code": "E0250",
              "display": "Hospital bed fixed height with any type of side rails, mattress"
            }
          ]
        },
        "subject": {
          "reference": "Patient/888"
        },
        "authoredOn": "2023-01-01T00:00:00Z",
        "requester": {
          "reference": "Practitioner/c4bb-Practitioner"
        },
        "performer": {
          "reference": "Practitioner/c4bb-Practitioner"
        },
        "insurance": [
          {
            "reference": "Coverage/c4bb-Coverage"
          }
        ],
        "extension": [
          {
            "url": "http://hl7.org/fhir/us/davinci-crd/StructureDefinition/ext-coverage-information",
            "extension": [
              {
                "url": "covered",
                "valueCode": "covered"
              },
              {
                "url": "pa-needed",
                "valueCode": "no-auth"
              },
              {
                "url": "coverage",
                "valueReference": {
                  "reference": "Coverage/c4bb-Coverage"
                }
              },
              {
                "url": "date",
                "valueDate": "2025-12-30"
              },
              {
                "url": "coverage-assertion-id",
                "valueString": "16f16557a66561e9d5528992bd60c21af5779e4c6d1d7fcbc730a2b776753d88"
              }
            ]
          }
        ]
      }
    },
    {
      "type": "update",
      "description": "This order is covered",
      "resource": {
        "resourceType": "MedicationRequest",
        "id": "MedicationRequest-888-advil",
        "status": "draft",
        "intent": "order",
        "medicationCodeableConcept": {
          "coding": [
            {
              "code": "codeForAdvil",
              "display": "Prescription Strength Advil"
            }
          ]
        },
        "subject": {
          "reference": "Patient/888"
        },
        "extension": [
          {
            "url": "http://hl7.org/fhir/us/davinci-crd/StructureDefinition/ext-coverage-information",
            "extension": [
              {
                "url": "covered",
                "valueCode": "covered"
              },
              {
                "url": "pa-needed",
                "valueCode": "no-auth"
              },
              {
                "url": "coverage",
                "valueReference": {
                  "reference": "Coverage/c4bb-Coverage"
                }
              },
              {
                "url": "date",
                "valueDate": "2025-12-30"
              },
              {
                "url": "coverage-assertion-id",
                "valueString": "e584f8a00b6bcdfed2953db3c631d6ed228f8ad6fac48d04fd3e02ab90d73d6f"
              }
            ]
          }
        ]
      }
    }
  ]
}
```

