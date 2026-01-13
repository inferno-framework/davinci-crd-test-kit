
# 5.1.3
* if the client maintains the data element and surfaces it to users, then it
  SHALL be exposed in their FHIR interface when the data exists and privacy
  constraints permit.

# 5.1.5
* all US Core profiles are deemed to be part of this IG and available for use in
  CRD communications.
  
# 5.6
* All CRD clients will need to be configured to support communicating to a
  particular CRD server.
  * **QUESTION:** What will be required for Inferno to be recognized as a CRD
    server?

# 5.8.1
* CRD clients supporting prefetch SHALL inspect the CDS Hooks Discovery Endpoint
  to determine exact prefetch key names and queries.

# 5.9
* SHALL support the SMART on FHIR interface
* SHALL allow launching of SMART apps from within their application
* SHALL be capable of providing the SMART app access to information it exposes
  to CRD Servers using the CDS Hooks interface
* In the specific case of order-based hooks, “What if” SHOULD use the Order Sign
  hook, but SHALL use the configuration option that prevents the return of an
  unsolicited determination and MAY use configuration options to prevent the
  return of other irrelevant types of cards (e.g. duplicate therapy, etc.)
  
# 5.10
* When CRD clients pass resources to a CRD as part of context, the resources
  SHALL have an id and that id SHALL be usable as a target for references
* SHALL retain logs of all CRD-related hook invocations and their responses for
  access in the event of a dispute
* Organizations SHALL have processes to ensure logs can be accessed by
  appropriate authorized users to help resolve discrepancies or issues in a
  timely manner.

# 6
* Implementers SHALL adhere to any security and privacy rules defined by:...
* communications between CRD Clients and CRD Servers SHALL use TLS.
* SHALL support running applications that adhere to the SMART on FHIR
  confidential app profile.
* SHALL ensure that the resource identifiers exposed over the CRD interface are
  distinct from and have no determinable relationship with any business
  identifiers associated with those records

# 7.5.1
* **If they support it:** CRD Clients SHALL convey configuration options when
  invoking the hook using the davinci-crd.configuration extension.

# 7.6
* **NOTE:** clients not required to support prefetch
* where a hook defines a context element that consists of a resource or
  collection of resources (e.g. order-select.draftOrders or
  order-sign.draftOrders), systems SHALL recognize context tokens of the form
  context.<context property>.<FHIR resource name>.id in prefetch queries.
* Those tokens SHALL evaluate to a comma-separated list of the identifiers of
  all resources of the specified type within that context key.
  
# 7.7.2
* the inclusion of the id element in ‘created’ resources and references in
  created and updated resources within multi-action suggestions SHALL be handled
  as per FHIR’s transaction processing rules
* Specifically, this means that if a FHIR Reference points to the resource type
  and identifier of a resource of another ‘create’ Action in the same
  Suggestion, then the reference to that resource SHALL be updated by the server
  to point to the identifier assigned by the client when performing the ‘create’
* CRD Clients SHALL perform ‘creates’ in an order that ensures that referenced
  resources are created prior to referencing resources

# 7.9
* Provider systems SHALL only invoke hooks on payer services where the patient
  record indicates active coverage with the payer associated with the service.
* where a patient has multiple active coverages that could be relevant to the
  current order/appointment/etc., CRD clients SHALL select from those coverages
  which is most likely to be primary and only solicit coverage information for
  that one payer
* If they invoke CRD on other payers, CRD clients SHALL ensure that card types
  that return coverage information are disabled for those ‘likely secondary’
  payers
* Where the patient has multiple active coverages that the CRD client deems
  appropriate to call the respective CRD servers for, the CRD client SHALL
  invoke all CRD server calls in parallel and display results simultaneously to
  ensure timely response to user action.

# 8
* CRD Clients conforming to this implementation guide SHALL support at least one
  of the hooks and (for order-centric hooks), at least one of the order resource
  types listed below

# 8.2, 8.5, 8.7
* CRD clients and servers SHALL, at minimum, support returning and processing
  the Coverage Information system action for all invocations of this hook.

# 9.1
* conformant CRD Clients SHALL support the External Reference, Instructions, and
  Coverage Information responses and SHOULD support the remaining types.
* When a Coverage Information card type indicating that additional clinical
  documentation is needed and the CRD client supports DTR, CRD Clients SHALL
  ensure that clinical users have an opportunity to launch the DTR app as part
  of the current workflow.
  
# 9.4
* CRD clients and services SHALL support the new CDS Hooks system action
  functionality to cause annotations to automatically be stored on the relevant
  request, appointment, etc. without any user intervention
* In this case, the discrete information propagated into the order extension
  SHALL be available to the user for viewing

# 9.7
* Instead of using a card, CRD services MAY opt to use a systemAction instead.
  CRD clients supporting this card type SHALL support either approach.

# 9.8
* Instead of using a card, CRD services MAY opt to use a systemAction instead.
  CRD clients supporting this card type SHALL support either approach

# 10.1
* Clients that perform such suppression of messages SHALL mitigate this
  potential for misinterpretation.
  
# 12.0.1
* For this implementation guide, Must Support means that CRD Clients must be
  capable of exposing the data to at least some CRD Servers.
  
# 12.1.1.1
* In addition to the U.S. core expectations, the CRD Client SHALL support all
  ‘SHOULD’ ‘read’ and ‘search’ capabilities listed below for resources
  referenced in supported hooks and order types if it does not support returning
  the associated resources as part of CDS Hooks pre-fetch.
* The CRD Client SHALL also support ‘update’ functionality for all resources
  listed below where the client allows invoking hooks based on the resource.

# 12.1.4.1.1
* CRD Clients SHALL use this profile to provide appointments context objects to
  CRD Servers when invoking the appointment-book hook as well as to resolve
  other references to Appointment resources.
  
# 12.1.5.1.1
* CRD Clients SHALL use this profile to resolve references to
  CommunicationRequest resources passed to CRD Servers (e.g. selections context
  references) and to populate draftOrders context objects when invoking the when
  invoking the following CDS Hooks:
  
# 12.1.6.1.1
* CRD Clients SHALL use this profile to resolve references to insurance Coverage
  resources passed to CRD Servers.

# 12.1.7.1.1
* CRD Clients SHALL use this profile to resolve references to Device resources
  passed to CRD Servers.
  
# 12.1.8.1.1
* CRD Clients SHALL use this profile to resolve references to DeviceRequest
  resources passed to CRD Servers (e.g. selections context references) and to
  populate draftOrders context objects when invoking the following CDS Hooks:

# 12.1.9.1.1
* CRD Clients SHALL use this profile to resolve references to Encounter
  resources passed to CRD Servers, including encounterId context references when
  invoking the following CDS Hooks:
  
etc.
