
# 1.2
* for the purpose of CRD conformance, payers SHALL have a single endpoint
  (managed by themselves or a delegate) that can handle responding to all CRD
  service calls.

# 5.1.3
* the server SHALL leverage mustSupport elements as available and appropriate to
  provide decision support.

# 5.2
* CRD services SHALL return responses for all supported hooks and SHALL respond
  within the required duration 90% of the time...For most hooks, this target
  time is 5 seconds. It extends to 10 seconds for Appointment Book and for Order
  Dispatch and Order Sign hooks that are sent at least 24 hours after the last
  hook invocation for the same order(s) because there is no opportunity to cache
  data in those cases.
  
# 5.3
* CDS services SHALL ensure that the guidance returned with respect to coverage
  and prior authorizations (e.g. assertions that a service is covered, or prior
  authorization is not necessary) is as accurate as guidance that would be
  provided by other means (e.g. portals, phone calls).
  
# 5.5
* Payers and service providers SHALL ensure that CDS Hooks return only messages
  and information relevant and useful to the intended recipient.

# 5.8
* each payer will define the prefetch requests for their CRD Server based on the
  information they require to provide coverage requirements

# 5.8.3
* The queries use the defined search parameter names from the respective FHIR
  specification versions. If parties processing these queries have varied from
  these ‘standard’ search parameter names (as indicated by navigating their
  CapabilityStatements), the CRD Server will be responsible for translating the
  parameters into the CRD client’s local names. For example, if a particular CRD
  client’s CapabilityStatement indicates that the parameter name (that
  corresponds to HL7’s ‘encounter’ search criteria) is named ‘visit’ on the
  client’s server, the Service will have to construct its search URL
  accordingly.
* CRD Servers SHALL provide what coverage requirements they can based on the
  information available.

# 5.10
* SHALL retain logs of all CRD-related hook invocations and their responses for
  access in the event of a dispute
* All Card.suggestion elements SHALL populate the Suggestion.uuid element to aid
  in log reconciliation
* Organizations SHALL have processes to ensure logs can be accessed by
  appropriate authorized users to help resolve discrepancies or issues in a
  timely manner.

# 6
* Implementers SHALL adhere to any security and privacy rules defined by:...
* communications between CRD Clients and CRD Servers SHALL use TLS.
* SHALL use information received solely for coverage determination and decision
  support purposes 
* SHALL NOT retain data received over the CRD interfaces for any purpose other
  than audit or providing context for form completion using DTR.

# 7.5
* Each option SHALL include four mandatory elements...
* A default value SHALL also be provided to show users what to expect when an
  override is not specified.
* SHALL, at minimum, offer configuration options for each type of card they support
* payer services SHALL gracefully handle disallowed/nonsensical combinations
* Codes SHALL be valid JSON property names and SHALL come from the CRD Card
  Types list if an applicable type is in that list
* Codes, names, and descriptions SHALL be unique within a CDS Service definition

# 7.5.1
* CRD Servers SHALL behave in the manner prescribed by any supported
  configuration information received from the CRD Client.
* CRD Servers SHALL NOT require the inclusion of configuration information in a
  hook call
* the CRD Server SHALL ignore the unsupported configuration information.

# 7.7
* the payer service SHALL query to determine if the client has a copy of the
  Questionnaire before sending the request

# 7.8
* If a hook service is invoked on a collection of resources, all cards returned
  that are specific to only a subset of the resources passed as context SHALL
  disambiguate in the detail element which resources they’re associated with in
  a human-friendly way

# 8
* CRD Servers conforming to this implementation guide SHALL provide a service
  for all hooks and order resource types required of CRD clients by this
  implementation guide unless the server has determined that the hook will not
  be reasonably useful in determining coverage or documentation expectations for
  the types of coverage provided.
* If the CRD Server encounters an error when processing the request, the system
  SHALL return an appropriate error HTTP Response Code, starting with the digit
  “4” or “5”, indicating that there was an error.
* While any 4xx or 5xx response code could be raised, the CRD Server SHALL use
  the 400 and 422 codes in a manner consistent with the FHIR RESTful Create
  Action

# 8.1
* The ‘primary’ hooks are Appointment Book, Orders Sign, and Order Dispatch. CRD
  Servers SHALL, at minimum, return a Coverage Information system action for
  these hooks, even if the response indicates that further information is needed
  or that the level of detail provided is insufficient to determine coverage.
* The ‘secondary’ hooks are Orders Select, Encounter Start, and Encounter
  Discharge... If Coverage Information is returned for these hooks, it SHALL NOT
  include messages indicating a need for clinical or administrative information
* CRD Servers SHALL handle unrecognized context elements by ignoring them.

# 8.2, 8.5, 8.7
* CRD clients and servers SHALL, at minimum, support returning and processing
  the Coverage Information system action for all invocations of this hook.
  
# 9
* Card.source.topic SHALL be populated, and has an extensible binding to the
  ValueSet CRD Card Types.

# 9.1
* CRD Servers SHALL, at minimum, demonstrate an ability to return cards with the
  following type: Coverage, External Reference and Instructions card types (card
  type code documentation).
* CRD Servers that provide decision support for non-coverage/documentation areas
  SHALL check that the CRD client does not have the information within its store
  that would allow it to detect the issue itself.

# 9.2
* The card SHALL have at least one Card.link
* The Link.type SHALL have a type of “absolute”.

# 9.4
* In some cases, the answer might differ depending on factors such as in/out of
  network, when the service is delivered, etc. These qualifiers around when the
  coverage assertion is considered valid SHALL be included as part of the
  annotation.
* If a CRD client submits a claim related to an order for which it has received
  a coverage-information extension for the coverage type associated with the
  claim, that claim SHALL include the coverage-assertion-id and, if applicable,
  the satisfied-pa-id in the X12 837 K3 segment
* If multiple extension repetitions are present, all repetitions referencing
  differing insurance (coverage-information.coverage) SHALL have distinct
  coverage-assertion-ids and satisfied-pa-ids (if present)
* Where multiple repetions apply to the same coverage, they *SHALL have the same
  coverage-assertion-ids and satisfied-pa-ids (if present)
* payers SHALL NOT send a system action to update the order unless something is
  new
* When using this response type, the proposed order or appointment being updated
  SHALL comply with the following profiles: ...
* CRD clients and services SHALL support the new CDS Hooks system action
  functionality to cause annotations to automatically be stored on the relevant
  request, appointment, etc. without any user intervention

# 9.5
* When using this response type, the proposed orders (and any associated
  resources) SHALL comply with the following profiles
  
# 9.6
* When using this response type, the proposed orders (and any associated
  resources) SHALL comply with the following profiles:

# 9.7
* When using this response type, the proposed orders (and any associated
  resources) SHALL comply with the following profiles:

# 9.8
* This CRD capability SHALL NOT be used in situations where regulation dictates
  the use of the X12 functionality.
