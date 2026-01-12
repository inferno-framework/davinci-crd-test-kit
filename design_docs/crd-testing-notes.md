# Client Testing

* Make discovery endpoint with services
  * Require Auth for discovery request. This can be used to link discovery
    request to a particular session. I'm not sure whether that is useful,
    though.
  * Include prefetch queries **RULE REQUIRED**
  * Include configuration options **OPTIONAL**
  * Hook Types
    * appointment-book **RULE REQUIRED**
    * encounter-start **RULE REQUIRED**
    * encounter-discharge **RULE REQUIRED**
    * order-dispatch **RULE REQUIRED**
    * order-select **RULE REQUIRED**
    * order-sign **RULE REQUIRED**
* Receive incoming hook request
  * Verify jwt in Auth header
  * Verify required fields
    * hook
    * hookInstance
    * context
  * Verify optional fields
    * fhirServer
    * fhirAuthorization
    * prefetch
  * Verify context
    * appointment-book **RULE REQUIRED**
      * userId **REQUIRED**
      * patientId **REQUIRED**
      * encounterId
      * appointments **REQUIRED**
    * encounter-start **RULE REQUIRED**
      * userId **REQUIRED**
      * patientId **REQUIRED**
      * encounterId **REQUIRED**
    * encounter-discharge **RULE REQUIRED**
      * userId **REQUIRED**
      * patientId **REQUIRED**
      * encounterId **REQUIRED**
    * order-dispatch **RULE REQUIRED**
      * patientId **REQUIRED**
      * dispatchedOrders **REQUIRED**
      * performer **REQUIRED**
      * fulfillmentTasks
    * order-select **RULE REQUIRED**
      * userId **REQUIRED**
      * patientId **REQUIRED**
      * encounterId
      * selections **REQUIRED**
      * draftOrders **REQUIRED**
    * order-sign **RULE REQUIRED**
      * userId **REQUIRED**
      * patientId **REQUIRED**
      * encounterId
      * draftOrders **REQUIRED**
  * Make FHIR requests
    * Lifetime of token received via hook request is very limited, so it is not
      suitable for extensive FHIR API testing.
    * Fetch context resources
  * Verify prefetch
  * Return cards
    * Card Types
      * External link **Required**
      * Instructions **Required**
      * Coverage information systemAction **Required**
        * REQUIREMENT OUTSIDE OF SCOPE - "If a CRD client submits a claim
          related to an order for which it has received a coverage-information
          extension for the coverage type associated with the claim, that claim
          SHALL include the coverage-assertion-id and, if applicable, the
          satisfied-pa-id in the X12 837 K3 segment."
        * CRD clients and services SHALL support the new CDS Hooks system action
          functionality to cause annotations to automatically be stored on the
          relevant request, appointment, etc. without any user intervention. In
          this case, the discrete information propagated into the order
          extension SHALL be available to the user for viewing.
      * Propose alternate request
        * Multiple alternatives can be proposed by providing multiple
          suggestions.
      * Identify additional orders as companions/prerequisites for curret order
      * Request form completion
        * Instead of using a card, CRD services MAY opt to use a `systemAction`
          instead. CRD clients supporting this card type SHALL support either
          approach.
      * Create or update coverage information
        * Instead of using a card, CRD services MAY opt to use a systemAction
          instead. CRD clients supporting this card type SHALL support either
          approach.
      * Launch SMART application **RULE REQUIRED**
        * Use card to perform an EHR Launch of Inferno and perform comprehensive
          FHIR API tests.
  * MS: NOT TESTABLE - "if the client maintains the data element and surfaces it
    to users, then it SHALL be exposed in their FHIR interface when the data
    exists and privacy constraints permit"
  * IS THIS TESTABLE? - "When a Coverage Information card type indicating that
    additional clinical documentation is needed and the CRD client supports DTR,
    CRD Clients SHALL ensure that clinical users have an opportunity to launch
    the DTR app as part of the current workflow."

# Server Testing
* Make discovery request
  * Verify that services for required hook types are present
  * Verify that services cover any other required capabilities
* Make hook requests
  * Allow user to define a collection of requests which will cover all required
    capabilities
  * Hook Types
    * appointment-book **RULE REQUIRED**
    * encounter-start **RULE REQUIRED**
    * encounter-discharge **RULE REQUIRED**
    * order-dispatch **RULE REQUIRED**
    * order-select **RULE REQUIRED**
    * order-sign **RULE REQUIRED**
  * Card Types
    * External link **Required**
      * SHALL have at least one `Card.link`
      * `Link.type` SHALL have a type of `absolute`
    * Instructions **Required**
    * Coverage information systemAction **Required**
      *  If multiple extension repetitions are present, all repetitions
         referencing differing insurance (coverage-information.coverage) SHALL
         have distinct coverage-assertion-ids and satisfied-pa-ids (if present).
       * Where multiple repetions apply to the same coverage, they SHALL have
         the same coverage-assertion-ids and satisfied-pa-ids (if present).
       * When using this response type, the proposed order or appointment being
         updated SHALL comply with the following profiles:
         * profile-appointment 	
         * profile-devicerequest 	
         * profile-medicationrequest 	
         * profile-nutritionorder 	
         * profile-servicerequest 	
         * profile-visionprescription
    * Propose alternate request
      * When using this response type, the proposed orders (and any associated
        resources) SHALL comply with the following profiles:
        * profile-device 	
        * profile-devicerequest 	
        * profile-encounter† 	
        * us-core-medication
        * profile-medicationrequest 	
        * profile-nutritionorder 	
        * profile-servicerequest 	
        * profile-visionprescription 	
    * Identify additional orders as companions/prerequisites for current order
      * When using this response type, the proposed orders (and any associated
        resources) SHALL comply with the following profiles:
        * profile-communicationrequest 	
        * profile-device 	
        * profile-devicerequest 	
        * us-core-medication
        * profile-medicationrequest 	
        * profile-nutritionorder 	
        * profile-servicerequest 	
        * profile-visionprescription
    * Request form completion
      * This suggestion will always include a “create” action for the Task.
      * The Task will point to the questionnaire to be completed using a
        `Task.input` element with a `Task.input.type.text` of “questionnaire”
        and the canonical URL for the questionnaire in
        `Task.input.valueCanonical`.
      * Additional `Task.input` elements will provide information about how the
        completed questionnaire is to be submitted to the payer with a service
        endpoint if required.
      * The Task.code will always include the CRD-specific
        `complete-questionnaire` code.
      * The reason for completion will be conveyed in `Task.reasonCode`.
      * Instead of using a card, CRD services MAY opt to use a systemAction
        instead.
      * When using this response type, the proposed orders (and any associated
        resources) SHALL comply with the following profiles:
        * profile-taskquestionnaire
    * Create or update coverage information
      * Instead of using a card, CRD services MAY opt to use a systemAction
        instead.
      * This response will contain a single suggestion. The primary action will
        either be a suggestion to “update” an existing Coverage instance (if the
        CRD Client already has one) or to “create” a new Coverage instance if
        the CRD Server is aware of Coverage that the CRD Client is not. In
        addition, the suggestion could include updates on all relevant Request
        resources to add or remove links to Coverage instances, reflecting which
        Coverages are relevant to which types of requests.
    * Launch SMART application **RULE REQUIRED**
      * Use card to perform an EHR Launch of Inferno and perform FHIR API
        tests.
      * the `Link.type` will be “smart” instead of “absolute”. The
        Link.appContext will typically also be present.
  * MS: NOT TESTABLE - "the server SHALL leverage mustSupport elements as
    available and appropriate to provide decision support"
