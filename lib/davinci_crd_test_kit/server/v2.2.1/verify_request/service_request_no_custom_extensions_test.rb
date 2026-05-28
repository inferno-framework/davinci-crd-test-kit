require_relative '../../resource_extractor'
require_relative '../../server_hook_helper'

module DaVinciCRDTestKit
  module V221
    class ServiceRequestNoCustomExtensionsTest < Inferno::Test
      include DaVinciCRDTestKit::ResourceExtractor
      include DaVinciCRDTestKit::ServerHookHelper

      US_CORE_EXTENSION_URLS = [
        'http://hl7.org/fhir/us/core/StructureDefinition/us-core-birthsex',
        'http://hl7.org/fhir/us/core/StructureDefinition/us-core-direct',
        'http://hl7.org/fhir/us/core/StructureDefinition/us-core-ethnicity',
        'http://hl7.org/fhir/us/core/StructureDefinition/us-core-race',
        'http://hl7.org/fhir/us/core/StructureDefinition/uscdi-requirement',
        'http://hl7.org/fhir/us/core/StructureDefinition/us-core-extension-questionnaire-uri',
        'http://hl7.org/fhir/us/core/StructureDefinition/us-core-genderIdentity',
        'http://hl7.org/fhir/us/core/StructureDefinition/us-core-jurisdiction',
        'http://hl7.org/fhir/us/core/StructureDefinition/us-core-sex',
        'http://hl7.org/fhir/us/core/StructureDefinition/us-core-tribal-affiliation',
        'http://hl7.org/fhir/us/core/StructureDefinition/us-core-medication-adherence',
        'http://hl7.org/fhir/StructureDefinition/condition-assertedDate'
      ].freeze

      CRD_EXTENSION_URLS = [
        'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/ext-coverage-information',
        'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/ext-billing-options',
        'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/ext-request-category',
        'http://hl7.org/fhir/StructureDefinition/codeOptions',
        'http://hl7.org/fhir/StructureDefinition/alternate-reference',
        'http://hl7.org/fhir/5.0/StructureDefinition/extension-CommunicationRequest.payload.content',
        'http://hl7.org/fhir/5.0/StructureDefinition/extension-Task.requestedPeriod',
        'http://hl7.org/fhir/5.0/StructureDefinition/extension-Task.requestedPerformer',
        'http://hl7.org/fhir/5.0/StructureDefinition/extension-Task.performer',
        'http://hl7.org/fhir/StructureDefinition/request-doNotPerform',
        'http://hl7.org/fhir/5.0/StructureDefinition/extension-Task.input.value',
        'http://hl7.org/fhir/5.0/StructureDefinition/extension-Task.output.value',
        'http://hl7.org/fhir/5.0/StructureDefinition/extension-Task.statusReason'
      ].freeze

      HREX_EXTENSION_URLS = [
        'http://hl7.org/fhir/us/davinci-hrex/StructureDefinition/extension-CoverageDavinciWellknownLocation'
      ].freeze

      VALID_EXTENSION_URLS = (US_CORE_EXTENSION_URLS + CRD_EXTENSION_URLS + HREX_EXTENSION_URLS).freeze

      title 'Server does not require custom extensions'
      id :crd_v221_service_request_no_custom_extensions
      description %(
        This test verifies that the server is capable of responding to a client
        without the use of any custom extensions. It inspects each successful
        hook call, and if it finds one which doesn't use any extensions not
        defined by US Core, CRD, or HREX it passes.
      )

      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@conf-7',
                            'hl7.fhir.us.davinci-crd_2.2.1@hook-22'

      run do
        ALL_HOOK_TAGS.each do |tag|
          load_tagged_requests(tag)
        end

        skip_if requests.blank?, 'No requests were made in a previous test as expected.'

        successful_requests = requests.select { |request| request.status == 200 }

        skip_if successful_requests.empty?, 'All service requests were unsuccessful.'

        embedded_resources =
          successful_requests
            .map { |request| resources_from_request(request) }
            .reject(&:blank?)

        skip_if embedded_resources.blank?,
                'No embedded FHIR resources were found in successful hook requests.'

        request_with_no_custom_extensions =
          embedded_resources.any? { |resources| resources.all? { |resource| no_custom_extensions? resource } }

        pass_if request_with_no_custom_extensions

        custom_extensions_string =
          embedded_resources
            .flatten
            .flat_map { |resource| custom_extensions(resource) }
            .uniq
            .map { |extension| "\n- `#{extension}`" }
            .join

        skip 'No requests were made without custom extensions. The following custom extensions were found: ' \
             "#{custom_extensions_string}"
      end

      def no_custom_extensions?(resource)
        resource.each_element do |value, _metadata, path|
          next unless value.is_a? FHIR::Extension

          next if path.scan('extension').length > 1

          return false unless VALID_EXTENSION_URLS.include? value.url
        end

        true
      end

      def custom_extensions(resource)
        [].tap do |custom_extensions|
          resource.each_element do |value, _metadata, path|
            next unless value.is_a? FHIR::Extension

            next if path.scan('extension').length > 1

            custom_extensions << value.url unless VALID_EXTENSION_URLS.include? value.url
          end
        end
      end
    end
  end
end
