require 'tls_test_kit'
require_relative 'crd_options'
require_relative 'client_tests/client_fhir_api_read_test'
require_relative 'client_tests/client_fhir_api_search_test'
require_relative 'client_tests/client_fhir_api_create_test'
require_relative 'client_tests/client_fhir_api_update_test'
require_relative 'client_tests/client_fhir_api_validation_test'
require 'smart_app_launch/smart_stu1_suite'
require 'smart_app_launch/smart_stu2_suite'

module DaVinciCRDTestKit
  class ClientFHIRAPIGroup < Inferno::TestGroup
    title 'FHIR API'
    description <<~DESCRIPTION
      Systems wishing to conform to the [CRD Client](https://hl7.org/fhir/us/davinci-crd/STU2/CapabilityStatement-crd-client.html)
      role are responsible for returning data requested by the CRD Server needed to provide decision support. The Da
      Vinci CRD Client FHIR API Test Group contains tests that test the ['server' capabilities](https://hl7.org/fhir/us/davinci-crd/CapabilityStatement-crd-client.html#resourcesSummary1)
      of the CRD Client and ensures that the CRD Client can respond to CRD Server queriers. These 'server' capabilities
      are based on [US Core](https://hl7.org/fhir/us/core/STU3.1.1/). This test kit does not test the base US Core
      capabilities. In addition to the U.S. Core expectations, the CRD Client SHALL support all 'SHOULD' `read` and
      `search` capabilities listed for resources referenced in supported hooks and order types if it does not support
      returning the associated resources as part of CDS Hooks pre-fetch. The CRD Client SHALL also support `update`
      functionality for all resources listed where the client allows invoking hooks based on the resource.

      This test group contains two main groups of tests:
      * SMART App Launch Authorization: A group of tests that perform FHIR API authorization using [SMART on FHIR](https://hl7.org/fhir/smart-app-launch/index.html)
      EHR Launch Sequence
      * CRD FHIR RESTful Capabilities: A group of tests that test each CRD resource profile and ensure the CRD client
      supports the appropriate FHIR operations required on each resource
    DESCRIPTION
    id :crd_client_fhir_api

    input :url,
          title: 'FHIR Endpoint',
          description: 'URL of the CRD FHIR server'

    group do
      title 'Authorization'
      description %(
        Perform an EHR [SMART App Launch](https://www.hl7.org/fhir/smart-app-launch/) to Authorize the client FHIR
        server with Inferno so that Inferno may access resources on the FHIR server in order to perform the FHIR RESTful
        Capabilities tests.
      )
      verifies_requirements 'hl7.fhir.us.davinci-crd_2.0.1@64', 'hl7.fhir.us.davinci-crd_2.0.1@65',
                            'hl7.fhir.us.davinci-crd_2.0.1@66', 'hl7.fhir.us.davinci-crd_2.0.1@89'

      config(
        inputs: {
          smart_auth_info: {
            name: :smart_auth_info,
            title: 'EHR Launch Credentials',
            options: {
              mode: 'auth',
              components: [
                Inferno::DSL::AuthInfo.default_auth_type_component_without_backend_services
              ]
            }
          }
        },
        outputs: {
          smart_auth_info: { name: :smart_auth_info }
        }
      )

      group from: :smart_discovery do
        required_suite_options CRDOptions::SMART_1_REQUIREMENT
        run_as_group

        test from: :tls_version_test do
          title 'CRD FHIR Server is secured by transport layer security'
          description <<~DESCRIPTION
            Under [Privacy, Security, and Safety](https://hl7.org/fhir/us/davinci-crd/STU2/security.html),
            the CRD Implementation Guide imposes the following rule about TLS:

            As per the [CDS Hook specification](https://cds-hooks.hl7.org/2.0/#security-and-safety),
            communications between CRD Clients and CRD Servers SHALL
            use TLS. Mutual TLS is not required by this specification but is permitted. CRD Servers and
            CRD Clients SHOULD enforce a minimum version and other TLS configuration requirements based
            on HRex rules for PHI exchange.

            This test verifies that the FHIR server is using TLS 1.2 or higher.
          DESCRIPTION
          id :crd_server_tls_version_stu1

          config(
            options: { minimum_allowed_version: OpenSSL::SSL::TLS1_2_VERSION }
          )
        end
      end

      group from: :smart_ehr_launch,
            required_suite_options: CRDOptions::SMART_1_REQUIREMENT,
            run_as_group: true

      group from: :smart_discovery_stu2 do
        required_suite_options CRDOptions::SMART_2_REQUIREMENT
        run_as_group

        test from: :tls_version_test do
          title 'CRD FHIR Server is secured by transport layer security'
          description <<~DESCRIPTION
            Under [Privacy, Security, and Safety](https://hl7.org/fhir/us/davinci-crd/STU2/security.html),
            the CRD Implementation Guide imposes the following rule about TLS:

            As per the [CDS Hook specification](https://cds-hooks.hl7.org/2.0/#security-and-safety),
            communications between CRD Clients and CRD Servers SHALL
            use TLS. Mutual TLS is not required by this specification but is permitted. CRD Servers and
            CRD Clients SHOULD enforce a minimum version and other TLS configuration requirements based
            on HRex rules for PHI exchange.

            This test verifies that the FHIR server is using TLS 1.2 or higher.
          DESCRIPTION
          id :crd_server_tls_version_stu2

          config(
            options: { minimum_allowed_version: OpenSSL::SSL::TLS1_2_VERSION }
          )
        end
      end

      group from: :smart_ehr_launch_stu2,
            required_suite_options: CRDOptions::SMART_2_REQUIREMENT,
            run_as_group: true

      group from: :smart_openid_connect do
        run_as_group
        optional
        config(
          inputs: {
            id_token: { name: :ehr_id_token }
          }
        )
      end

      group from: :smart_token_refresh do
        run_as_group
        optional
        config(
          inputs: {
            received_scopes: { name: :ehr_received_scopes }
          }
        )
      end
    end

    group do
      title 'FHIR RESTful Capabilities'
      description %(
        This test group contains groups of tests for each CRD resource profile and ensures the [CRD Client](https://hl7.org/fhir/us/davinci-crd/STU2/CapabilityStatement-crd-client.html)
        supports the appropriate FHIR operations required on each resource. For each resource, Inferno will perform the
        required FHIR operations, and then it will validate any resources that are returned as a result of
        these FHIR operations.

        The resources that are a part of the CRD IG configuration include:
          * [Appointment](https://hl7.org/fhir/us/davinci-crd/STU2/CapabilityStatement-crd-client.html#Appointment1-1)
          * [CommunicationRequest](https://hl7.org/fhir/us/davinci-crd/STU2/CapabilityStatement-crd-client.html#CommunicationRequest1-2)
          * [Coverage](https://hl7.org/fhir/us/davinci-crd/STU2/CapabilityStatement-crd-client.html#Coverage1-3)
          * [Device](https://hl7.org/fhir/us/davinci-crd/STU2/CapabilityStatement-crd-client.html#Device1-4)
          * [DeviceRequest](https://hl7.org/fhir/us/davinci-crd/STU2/CapabilityStatement-crd-client.html#DeviceRequest1-5)
          * [Encounter](https://hl7.org/fhir/us/davinci-crd/STU2/CapabilityStatement-crd-client.html#Encounter1-6)
          * [Patient](https://hl7.org/fhir/us/davinci-crd/STU2/CapabilityStatement-crd-client.html#Patient1-7)
          * [Practitioner](https://hl7.org/fhir/us/davinci-crd/STU2/CapabilityStatement-crd-client.html#Practitioner1-8)
          * [PractitionerRole](https://hl7.org/fhir/us/davinci-crd/STU2/CapabilityStatement-crd-client.html#PractitionerRole1-9)
          * [Location](https://hl7.org/fhir/us/davinci-crd/STU2/CapabilityStatement-crd-client.html#Location1-10)
          * [MedicationRequest](https://hl7.org/fhir/us/davinci-crd/STU2/CapabilityStatement-crd-client.html#MedicationRequest1-11)
          * [NutritionOrder](https://hl7.org/fhir/us/davinci-crd/STU2/CapabilityStatement-crd-client.html#NutritionOrder1-12)
          * [Organization](https://hl7.org/fhir/us/davinci-crd/STU2/CapabilityStatement-crd-client.html#Organization1-13)
          * [ServiceRequest](https://hl7.org/fhir/us/davinci-crd/STU2/CapabilityStatement-crd-client.html#ServiceRequest1-14)
          * [ClaimResponse](https://hl7.org/fhir/us/davinci-crd/STU2/CapabilityStatement-crd-client.html#ClaimResponse1-15)
          * [Task](https://hl7.org/fhir/us/davinci-crd/STU2/CapabilityStatement-crd-client.html#Task1-16)
          * [VisionPrescription](https://hl7.org/fhir/us/davinci-crd/STU2/CapabilityStatement-crd-client.html#VisionPrescription1-17)
      )
      input :url
      input :smart_auth_info,
            type: :auth_info,
            title: 'OAuth Credentials',
            options: { mode: 'access' },
            optional: true

      fhir_client do
        url :url
        auth_info :smart_auth_info
      end

      group do
        title 'Appointment'
        description %(
          Verify the CRD client can perform the required FHIR interactions on the Appointment resource, and
          validate any returned resources against the [CRD Appointment profile](https://hl7.org/fhir/us/davinci-crd/STU2/StructureDefinition-profile-appointment.html)

          Required Appointment resource FHIR interactions:
            * SHOULD support `update`

          Resource Conformance: SHOULD
        )
        optional

        test from: :crd_client_fhir_api_update_test,
             optional: true,
             config: {
               options: { resource_type: 'Appointment' },
               inputs: {
                 update_resources: {
                   name: :appointment_update_resources,
                   title: 'Appointment Resources'
                 }
               }
             }
      end

      group do
        title 'CommunicationRequest'
        description %(
          Verify the CRD client can perform the required FHIR interactions on the CommunicationRequest resource, and
          validate any returned resources against the [CRD CommunicationRequest profile](https://hl7.org/fhir/us/davinci-crd/STU2/StructureDefinition-profile-communicationrequest.html)

          Required CommunicationRequest resource FHIR interactions:
            * SHOULD support `update`

          Resource Conformance: SHOULD
        )
        optional
        verifies_requirements 'hl7.fhir.us.davinci-crd_2.0.1@150'

        test from: :crd_client_fhir_api_update_test,
             optional: true,
             config: {
               options: { resource_type: 'CommunicationRequest' },
               inputs: {
                 update_resources: {
                   name: :communication_request_update_resources,
                   title: 'CommunicationRequest Resources'
                 }
               }
             }
      end

      group do
        title 'Coverage'
        description %(
          Verify the CRD client can perform the required FHIR interactions on the Coverage resource, and
          validate any returned resources against the [CRD Coverage profile](https://hl7.org/fhir/us/davinci-crd/STU2/StructureDefinition-profile-coverage.html)

          Required Coverage resource FHIR interactions:
            * SHALL support search by [`patient`](http://hl7.org/fhir/R4/coverage.html#search)
            * SHALL support search by [`status`](http://hl7.org/fhir/R4/coverage.html#search)

          Resource Conformance: SHALL
        )

        test from: :crd_client_fhir_api_search_test,
             id: :crd_client_coverage_patient_search_test,
             title: 'Search by patient',
             config: {
               options: { resource_type: 'Coverage', search_type: 'patient' },
               inputs: { search_param_values: {
                 name: :patient_ids,
                 title: 'Patient IDs',
                 description: 'Comma separated list of Patient IDs that in sum contain all MUST SUPPORT elements'
               } }
             }

        test from: :crd_client_fhir_api_search_test,
             id: :crd_client_coverage_status_search_test,
             title: 'Search by status',
             config: {
               options: { resource_type: 'Coverage', search_type: 'status' },
               inputs: { search_param_values: {
                 name: :patient_ids
               } }
             }

        test from: :crd_client_fhir_api_validation_test,
             config: {
               options: { resource_type: 'Coverage' }
             }
      end

      group do
        title 'Device'
        description %(
          Verify the CRD client can perform the required FHIR interactions on the Device resource, and
          validate any returned resources against the [CRD Device profile](https://hl7.org/fhir/us/davinci-crd/STU2/StructureDefinition-profile-device.html)

          Required Device resource FHIR interactions:
            * SHOULD support `read`

          Resource Conformance: SHOULD
        )
        optional

        test from: :crd_client_fhir_api_read_test,
             optional: true,
             config: {
               options: { resource_type: 'Device' },
               inputs: {
                 resource_ids: {
                   name: :device_ids,
                   title: 'Device IDs',
                   description: 'Comma separated list of Device IDs that in sum contain all MUST SUPPORT elements'
                 }
               }
             }

        test from: :crd_client_fhir_api_validation_test,
             config: {
               options: { resource_type: 'Device' }
             }
      end

      group do
        title 'DeviceRequest'
        description %(
          Verify the CRD client can perform the required FHIR interactions on the DeviceRequest resource, and
          validate any returned resources against the [CRD DeviceRequest profile](https://hl7.org/fhir/us/davinci-crd/STU2/StructureDefinition-profile-devicerequest.html)

          Required DeviceRequest resource FHIR interactions:
            * SHOULD support `update`

          Resource Conformance: SHOULD
        )
        optional
        verifies_requirements 'hl7.fhir.us.davinci-crd_2.0.1@150'

        test from: :crd_client_fhir_api_update_test,
             optional: true,
             config: {
               options: { resource_type: 'DeviceRequest' },
               inputs: {
                 update_resources: {
                   name: :device_request_update_resources,
                   title: 'DeviceRequest Resources'
                 }
               }
             }
      end

      group do
        title 'Encounter'
        description %(
          Verify the CRD client can perform the required FHIR interactions on the Encounter resource, and
          validate any returned resources against the [CRD Encounter profile](https://hl7.org/fhir/us/davinci-crd/STU2/StructureDefinition-profile-encounter.html)

          Required Encounter resource FHIR interactions:
            * SHOULD support `update`
            * SHALL support search by [`_id`](http://hl7.org/fhir/R4/encounter.html#search)
            * SHALL support search by [`organization`](http://hl7.org/fhir/R4/encounter.html#search) and
            performing an `_include` on Location

          Resource Conformance: SHALL
        )

        test from: :crd_client_fhir_api_update_test,
             optional: true,
             config: {
               options: { resource_type: 'Encounter' },
               inputs: {
                 update_resources: {
                   name: :encounter_update_resources,
                   title: 'Encounter Resources'
                 }
               }
             }

        test from: :crd_client_fhir_api_search_test,
             id: :crd_client_encounter_id_search_test,
             title: 'Search by _id',
             config: {
               options: { resource_type: 'Encounter', search_type: '_id' },
               inputs: { search_param_values: {
                 name: :encounter_ids,
                 title: 'Encounter IDs',
                 description: 'Comma separated list of Encounter IDs that in sum contain all MUST SUPPORT elements'
               } }
             }

        test from: :crd_client_fhir_api_search_test,
             id: :crd_client_encounter_organization_search_test,
             title: 'Search by organization',
             config: {
               options: { resource_type: 'Encounter', search_type: 'organization' },
               inputs: { search_param_values: {
                 name: :organization_ids,
                 title: 'Organization IDs',
                 description: 'Comma separated list of Organization IDs that in sum contain all MUST SUPPORT elements'
               } }
             }

        test from: :crd_client_fhir_api_search_test,
             id: :crd_client_encounter_location_include_test,
             title: 'Search by _id and _include location',
             config: {
               options: { resource_type: 'Encounter', search_type: 'location_include' },
               inputs: { search_param_values: {
                 name: :encounter_ids,
                 title: 'Encounter IDs',
                 description: 'Comma separated list of Encounter IDs that in sum contain all MUST SUPPORT elements'
               } }
             }

        test from: :crd_client_fhir_api_validation_test,
             config: {
               options: { resource_type: 'Encounter' }
             }
      end

      group do
        title 'Patient'
        description %(
          Verify the CRD client can perform the required FHIR interactions on the Patient resource, and
          validate any returned resources against the [CRD Patient profile](https://hl7.org/fhir/us/davinci-crd/STU2/StructureDefinition-profile-patient.html)

          Required Patient resource FHIR interactions:
            * SHOULD support `read`

          Resource Conformance: SHOULD
        )
        optional

        test from: :crd_client_fhir_api_read_test,
             optional: true,
             config: {
               options: { resource_type: 'Patient' },
               inputs: {
                 resource_ids: {
                   name: :patient_ids,
                   title: 'Patient IDs',
                   description: 'Comma separated list of Patient IDs that in sum contain all MUST SUPPORT elements'
                 }
               }
             }

        test from: :crd_client_fhir_api_validation_test,
             config: {
               options: { resource_type: 'Patient' }
             }
      end

      group do
        title 'Practitioner'
        description %(
          Verify the CRD client can perform the required FHIR interactions on the Practitioner resource, and
          validate any returned resources against the [CRD Practitioner profile](https://hl7.org/fhir/us/davinci-crd/STU2/StructureDefinition-profile-practitioner.html)

          Required Practitioner resource FHIR interactions:
            * SHOULD support `read`

          Resource Conformance: SHOULD
        )
        optional

        test from: :crd_client_fhir_api_read_test,
             optional: true,
             config: {
               options: { resource_type: 'Practitioner' },
               inputs: {
                 resource_ids: {
                   name: :practitioner_ids,
                   title: 'Practitioner IDs',
                   description: 'Comma separated list of Practitioner IDs that in sum contain all MUST SUPPORT elements'
                 }
               }
             }

        test from: :crd_client_fhir_api_validation_test,
             config: {
               options: { resource_type: 'Practitioner' }
             }
      end

      group do
        title 'PractitionerRole'
        description %(
          Verify the CRD client can perform the required FHIR interactions on the PractitionerRole resource, and
          validate any returned resources against the [US Core PractitionerRole profile](https://hl7.org/fhir/us/core/STU3.1.1/StructureDefinition-us-core-practitionerrole.html)

          Required PractitionerRole resource FHIR interactions:
            * SHALL support search by [`_id`](http://hl7.org/fhir/R4/practitionerrole.html#search)
            * SHALL support search by [`organization`](http://hl7.org/fhir/R4/practitionerrole.html#search) and
              performing an `_include` on Organization
            * SHALL support search by [`practitioner`](http://hl7.org/fhir/R4/practitionerrole.html#search) and
              performing an `_include` on Practitioner

          Resource Conformance: SHALL
        )

        test from: :crd_client_fhir_api_search_test,
             id: :crd_client_practitioner_role_id_search_test,
             title: 'Search by _id',
             config: {
               options: { resource_type: 'PractitionerRole', search_type: '_id' },
               inputs: { search_param_values: {
                 name: :practitioner_role_ids,
                 title: 'PractitionerRole IDs',
                 description: 'Comma separated list of Practitioner IDs that in sum contain all MUST SUPPORT elements'
               } }
             }

        test from: :crd_client_fhir_api_search_test,
             id: :crd_client_practitioner_role_organization_search_test,
             title: 'Search by organization',
             config: {
               options: { resource_type: 'PractitionerRole', search_type: 'organization' },
               inputs: { search_param_values: {
                 name: :organization_ids,
                 title: 'Organization IDs',
                 description: 'Comma separated list of Organization IDs that in sum contain all MUST SUPPORT elements'
               } }
             }

        test from: :crd_client_fhir_api_search_test,
             id: :crd_client_practitioner_role_practitioner_search_test,
             title: 'Search by practitioner',
             config: {
               options: { resource_type: 'PractitionerRole', search_type: 'practitioner' },
               inputs: { search_param_values: {
                 name: :practitioner_ids,
                 title: 'Practitioner IDs',
                 description: 'Comma separated list of Practitioner IDs that in sum contain all MUST SUPPORT elements'
               } }
             }

        test from: :crd_client_fhir_api_search_test,
             id: :crd_client_practitioner_role_organization_include_test,
             title: 'Search by _id and _include organization',
             config: {
               options: { resource_type: 'PractitionerRole', search_type: 'organization_include' },
               inputs: { search_param_values: {
                 name: :practitioner_role_ids,
                 title: 'PractitionerRole IDs',
                 description: %(
                  Comma separated list of PractitionerRole IDs that in sum contain all MUST SUPPORT elements
                )
               } }
             }

        test from: :crd_client_fhir_api_search_test,
             id: :crd_client_practitioner_role_practitioner_include_test,
             title: 'Search by _id and _include practitioner',
             config: {
               options: { resource_type: 'PractitionerRole', search_type: 'practitioner_include' },
               inputs: { search_param_values: {
                 name: :practitioner_role_ids,
                 title: 'PractitionerRole IDs',
                 description: %(
                  Comma separated list of PractitionerRole IDs that in sum contain all MUST SUPPORT elements
                )
               } }
             }

        test from: :crd_client_fhir_api_validation_test,
             config: {
               options: { resource_type: 'PractitionerRole' }
             }
      end

      group do
        title 'Location'
        description %(
          Verify the CRD client can perform the required FHIR interactions on the Location resource, and
          validate any returned resources against the [CRD Location profile](https://hl7.org/fhir/us/davinci-crd/STU2/StructureDefinition-profile-location.html)

          Required Location resource FHIR interactions:
            * SHOULD support `read`

          Resource Conformance: SHOULD
        )
        optional

        test from: :crd_client_fhir_api_read_test,
             optional: true,
             config: {
               options: { resource_type: 'Location' },
               inputs: {
                 resource_ids: {
                   name: :location_ids,
                   title: 'Location IDs',
                   description: 'Comma separated list of Location IDs that in sum contain all MUST SUPPORT elements'
                 }
               }
             }

        test from: :crd_client_fhir_api_validation_test,
             config: {
               options: { resource_type: 'Location' }
             }
      end

      group do
        title 'MedicationRequest'
        description %(
          Verify the CRD client can perform the required FHIR interactions on the MedicationRequest resource, and
          validate any returned resources against the [CRD MedicationRequest profile](https://hl7.org/fhir/us/davinci-crd/STU2/StructureDefinition-profile-medicationrequest.html)

          Required MedicationRequest resource FHIR interactions:
            * SHOULD support `update`

          Resource Conformance: SHOULD
        )
        optional
        verifies_requirements 'hl7.fhir.us.davinci-crd_2.0.1@150'

        test from: :crd_client_fhir_api_update_test,
             optional: true,
             config: {
               options: { resource_type: 'MedicationRequest' },
               inputs: {
                 update_resources: {
                   name: :medication_request_update_resources,
                   title: 'MedicationRequest Resources'
                 }
               }
             }
      end

      group do
        title 'NutritionOrder'
        description %(
          Verify the CRD client can perform the required FHIR interactions on the NutritionOrder resource, and
          validate any returned resources against the [CRD NutritionOrder profile](https://hl7.org/fhir/us/davinci-crd/STU2/StructureDefinition-profile-nutritionorder.html)

          Required NutritionOrder resource FHIR interactions:
            * SHOULD support `update`

          Resource Conformance: SHOULD
        )
        optional
        verifies_requirements 'hl7.fhir.us.davinci-crd_2.0.1@150'

        test from: :crd_client_fhir_api_update_test,
             optional: true,
             config: {
               options: { resource_type: 'NutritionOrder' },
               inputs: {
                 update_resources: {
                   name: :nutrition_order_update_resources,
                   title: 'NutritionOrder Resources'
                 }
               }
             }
      end

      group do
        title 'Organization'
        description %(
          Verify the CRD client can perform the required FHIR interactions on the Organization resource, and
          validate any returned resources against the [CRD Organization profile](https://hl7.org/fhir/us/davinci-crd/STU2/StructureDefinition-profile-organization.html)

          Required Organization resource FHIR interactions:
            * SHOULD support `read`

          Resource Conformance: SHOULD
        )
        optional

        test from: :crd_client_fhir_api_read_test,
             optional: true,
             config: {
               options: { resource_type: 'Organization' },
               inputs: {
                 resource_ids: {
                   name: :organization_ids,
                   title: 'Organization IDs',
                   description: 'Comma separated list of Organization IDs that in sum contain all MUST SUPPORT elements'
                 }
               }
             }

        test from: :crd_client_fhir_api_validation_test,
             config: {
               options: { resource_type: 'Organization' }
             }
      end

      group do
        title 'ServiceRequest'
        description %(
          Verify the CRD client can perform the required FHIR interactions on the ServiceRequest resource, and
          validate any returned resources against the [CRD ServiceRequest profile](https://hl7.org/fhir/us/davinci-crd/STU2/StructureDefinition-profile-servicerequest.html)

          Required ServiceRequest resource FHIR interactions:
            * SHOULD support `update`

          Resource Conformance: SHOULD
        )
        optional
        verifies_requirements 'hl7.fhir.us.davinci-crd_2.0.1@150'

        test from: :crd_client_fhir_api_update_test,
             optional: true,
             config: {
               options: { resource_type: 'ServiceRequest' },
               inputs: {
                 update_resources: {
                   name: :service_request_update_resources,
                   title: 'ServiceRequest Resources'
                 }
               }
             }
      end

      group do
        title 'ClaimResponse'
        description %(
          Verify the CRD client can perform the required FHIR interactions on the ClaimResponse resource, and
          validate any returned resources against the [CRD ClaimResponse profile](https://hl7.org/fhir/us/davinci-hrex/STU1/StructureDefinition-hrex-claimresponse.html)

          Required ClaimResponse resource FHIR interactions:
            * SHOULD support `create`

          Resource Conformance: SHOULD
        )
        optional

        test from: :crd_client_fhir_api_create_test,
             optional: true,
             config: {
               options: { resource_type: 'ClaimResponse' },
               inputs: {
                 create_resources: {
                   name: :claim_response_create_resources,
                   title: 'ClaimResponse Resources'
                 }
               }
             }
      end

      group do
        title 'Task'
        description %(
          Verify the CRD client can perform the required FHIR interactions on the Task resource, and
          validate any returned resources against the [CRD Task profile](https://hl7.org/fhir/us/davinci-crd/STU2/StructureDefinition-profile-taskquestionnaire.html)

          Required Task resource FHIR interactions:
            * SHOULD support `create`

          Resource Conformance: SHOULD
        )
        optional

        test from: :crd_client_fhir_api_create_test,
             optional: true,
             config: {
               options: { resource_type: 'Task' },
               inputs: {
                 create_resources: {
                   name: :task_create_resources,
                   title: 'Task Resources'
                 }
               }
             }
      end

      group do
        title 'VisionPrescription'
        description %(
          Verify the CRD client can perform the required FHIR interactions on the VisionPrescription resource, and
          validate any returned resources against the [CRD VisionPrescription profile](https://hl7.org/fhir/us/davinci-crd/STU2/StructureDefinition-profile-visionprescription.html)

          Required VisionPrescription resource FHIR interactions:
            * SHOULD support `update`

          Resource Conformance: SHOULD
        )
        optional
        verifies_requirements 'hl7.fhir.us.davinci-crd_2.0.1@150'

        test from: :crd_client_fhir_api_update_test,
             optional: true,
             config: {
               options: { resource_type: 'VisionPrescription' },
               inputs: {
                 update_resources: {
                   name: :vision_prescription_update_resources,
                   title: 'VisionPrescription Resources'
                 }
               }
             }
      end
    end
  end
end
