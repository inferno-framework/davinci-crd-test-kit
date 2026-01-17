require 'tls_test_kit'
require 'us_core_test_kit'
require_relative 'crd_options'
require_relative 'client_tests/client_fhir_api_read_test'
require_relative 'client_tests/client_fhir_api_search_test'
require_relative 'client_tests/client_fhir_api_create_test'
require_relative 'client_tests/client_fhir_api_update_test'
require_relative 'client_tests/client_fhir_api_validation_test'
require_relative 'client_tests/client_fhir_api_encounter_location_search_test'
require_relative 'client_tests/client_fhir_api_practitioner_role_group'
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
      are based on [US Core](https://hl7.org/fhir/us/core/STU3.1.1/). This test suite confirms support
      for US Core STU 3.1.1 server requirements, plus additional search, create, and update functionality
      specified by CRD.

      This test group contains three main groups of tests:
      * **SMART App Launch Authorization**: Tests that perform FHIR API authorization using [SMART on FHIR](https://hl7.org/fhir/smart-app-launch/index.html)
      EHR Launch Sequence
      * **US Core FHIR API**: Tests that verify that the client can expose data as a US Core server as required by the US Core STU 3.1.1 IG.
      * **CRD FHIR API Create and Update Capabilities**: Tests that check for support of FHIR update and create interactions
        on resource types that the CRD Client need to make updates to based on systemActions or card suggestions.
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
                            'hl7.fhir.us.davinci-crd_2.0.1@66', 'hl7.fhir.us.davinci-crd_2.0.1@89',
                            'hl7.fhir.us.davinci-crd_2.0.1@92'

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

    group from: :'us_core_v311-us_core_v311_fhir_api' do
      description %(
        This test group verifies that the CRD Client can respond to queries as required by the
        US Core 3.1.1 Server Capability Statement, plus several additional queries required
        by the CRD Client Capability Statement, including
        - Encounter: the `location` and `_include=Encounter:location` search parameters.
        - PractitionerRole: the `_id`, `organization`, `_include=PractitionerRole:organization`,
          and `_include=PractitionerRole:practition` search parameters.

        Notes: these tests od not look for crd-specific data and so only verify conformance against
        US Core profiles. The hook tests take the CRD-specific profiles into account.
      )
      group from: :crd_client_fhir_api_practitioner_role
      reorder :crd_client_fhir_api_practitioner_role, 27

      encounter_group = groups.find { |group| group.title.include?('Encounter') }
      encounter_group.description.gsub!('* date + patient',
                                        "* date + patient\n" \
                                        "* location (additional CRD requirement)\n" \
                                        '* _id + _include=Encounter:location (additional CRD requirement)')
      encounter_group.test(from: :crd_client_fhir_api_encounter_location_search)
      encounter_group.reorder(:crd_client_fhir_api_encounter_location_search, 8)

      encounter_group.test from: :crd_client_fhir_api_search_test,
                           id: :crd_client_fhir_api_encounter_location_include_search,
                           title: 'Search by _id and _include location',
                           config: {
                             options: { resource_type: 'Encounter', target_search_param: 'location_include' },
                             inputs: { search_param_values: { name: :encounter_id_with_location } }
                           }
      encounter_group.reorder(:crd_client_fhir_api_encounter_location_include_search, 9)
    end

    group do
      title 'CRD FHIR API Create and Update Capabilities'
      description %(
        This test group contains a test for each CRD resource profile that [CRD Client](https://hl7.org/fhir/us/davinci-crd/STU2/CapabilityStatement-crd-client.html)
        may need to create or update based on cards that users decide to act on.

        The resources that support the create or update interaction include:
          * [Appointment](https://hl7.org/fhir/us/davinci-crd/STU2/CapabilityStatement-crd-client.html#Appointment1-1)
            update
          * [ClaimResponse](https://hl7.org/fhir/us/davinci-crd/STU2/CapabilityStatement-crd-client.html#ClaimResponse1-15)
            create
          * [CommunicationRequest](https://hl7.org/fhir/us/davinci-crd/STU2/CapabilityStatement-crd-client.html#CommunicationRequest1-2)
            update
          * [DeviceRequest](https://hl7.org/fhir/us/davinci-crd/STU2/CapabilityStatement-crd-client.html#DeviceRequest1-5)
            update
          * [Encounter](https://hl7.org/fhir/us/davinci-crd/STU2/CapabilityStatement-crd-client.html#Encounter1-6)
            update
          * [MedicationRequest](https://hl7.org/fhir/us/davinci-crd/STU2/CapabilityStatement-crd-client.html#MedicationRequest1-11)
            update
          * [NutritionOrder](https://hl7.org/fhir/us/davinci-crd/STU2/CapabilityStatement-crd-client.html#NutritionOrder1-12)
            update
          * [ServiceRequest](https://hl7.org/fhir/us/davinci-crd/STU2/CapabilityStatement-crd-client.html#ServiceRequest1-14)
            update
          * [Task](https://hl7.org/fhir/us/davinci-crd/STU2/CapabilityStatement-crd-client.html#Task1-16)
            update
          * [VisionPrescription](https://hl7.org/fhir/us/davinci-crd/STU2/CapabilityStatement-crd-client.html#VisionPrescription1-17)
            update
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

      test from: :crd_client_fhir_api_update_test,
           id: :crd_client_fhir_api_appointment_update_test,
           title: 'Appointment Update',
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

      test from: :crd_client_fhir_api_create_test,
           id: :crd_client_fhir_api_claim_response_create_test,
           title: 'ClaimResponse Create',
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

      test from: :crd_client_fhir_api_update_test,
           id: :crd_client_fhir_api_communication_request_update_test,
           title: 'CommunicationRequest Update',
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

      test from: :crd_client_fhir_api_update_test,
           id: :crd_client_fhir_api_device_request_update_test,
           title: 'DeviceRequest Update',
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

      test from: :crd_client_fhir_api_update_test,
           id: :crd_client_fhir_api_encounter_update_test,
           title: 'Encounter Update',
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

      test from: :crd_client_fhir_api_update_test,
           id: :crd_client_fhir_api_medication_request_update_test,
           title: 'MedicationRequest Update',
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

      test from: :crd_client_fhir_api_update_test,
           id: :crd_client_fhir_api_nutrition_order_update_test,
           title: 'NutritionOrder Update',
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

      test from: :crd_client_fhir_api_update_test,
           id: :crd_client_fhir_api_service_request_update_test,
           title: 'ServiceRequest Update',
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

      test from: :crd_client_fhir_api_create_test,
           id: :crd_client_fhir_api_task_create_test,
           title: 'Task Create',
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

      test from: :crd_client_fhir_api_update_test,
           id: :crd_client_fhir_api_vision_prescription_update_test,
           title: 'VisionPrescription Update',
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
