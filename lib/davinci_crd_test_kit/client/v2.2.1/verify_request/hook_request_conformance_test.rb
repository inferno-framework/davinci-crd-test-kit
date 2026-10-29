require_relative '../../../cross_suite/requests_logical_model_validation'
require_relative '../../tagged_request_load_helper'
require_relative '../../multi_request_message_helper'
require_relative '../client_urls'
require_relative '../../endpoints/cds_services_discovery_handler'

module DaVinciCRDTestKit
  module V221
    class HookRequestConformanceTest < Inferno::Test
      include RequestsLogicalModelValidation
      include DaVinciCRDTestKit::TaggedRequestLoadHelper
      include DaVinciCRDTestKit::MultiRequestMessageHelper
      include ClientURLs

      id :crd_v221_hook_request_conformance
      title 'Hook requests have the correct structure and content'
      description %(
        During this test, Inferno will verify that hook request bodies meet
        structural and content requirements by checking that they conform to the [CRD CDSHooks Request](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/StructureDefinition-CRDHooksRequest.html)
        logical model. Extensions not defined by CRD are allowed.
      )

      output :url, :smart_auth_info

      verifies_requirements 'cds-hooks_3.0.0-ballot@3', 'cds-hooks_3.0.0-ballot@53', 'cds-hooks_3.0.0-ballot@214',
                            'cds-hooks_3.0.0-ballot@222', 'cds-hooks_3.0.0-ballot@223', 'cds-hooks_3.0.0-ballot@224',
                            'hl7.fhir.us.davinci-crd_2.2.1@dev-12', 'hl7.fhir.us.davinci-crd_2.2.1@found-20',
                            'hl7.fhir.us.davinci-crd_2.2.1@found-36-A',
                            'hl7.fhir.us.davinci-crd_2.2.1@hook-20', 'hl7.fhir.us.davinci-crd_2.2.1@hook-21'

      # the JSON values that each configuration option type defined by CRD may take
      CONFIGURATION_TYPE_CHECKS = {
        'boolean' => ->(value) { [true, false].include?(value) },
        'integer' => ->(value) { value.is_a?(Integer) },
        'string' => ->(value) { value.is_a?(String) }
      }.freeze

      def advertised_configuration_options(request, hook)
        services = JSON.parse(
          CDSServicesDiscoveryHandler.cds_services('v2.2.1', prefetch_subset: prefetch_target(request) == :subset)
        )['services']
        services.find { |service| service['hook'] == hook }&.dig('extension', 'davinci-crd.configuration-options')
      end

      # The logical model checks that the configuration is an object holding primitive values, but
      # not the type each advertised option was given.
      def check_configuration_extension(request, request_body, request_index)
        extension = request_body['extension']
        return unless extension.is_a?(Hash) && extension['davinci-crd.configuration'].is_a?(Hash)

        options = advertised_configuration_options(request, request_body['hook'])
        return if options.nil?

        extension['davinci-crd.configuration'].each do |code, value|
          check_configuration_option(options, code, value, request_index)
        end
      end

      def check_configuration_option(options, code, value, request_index)
        option = options.find { |advertised| advertised['code'] == code }
        # CRD clients may send configuration the service does not support, and the service ignores it
        if option.nil?
          add_request_message('info',
                              "`davinci-crd.configuration` property `#{code}` is not a configuration option " \
                              'advertised by the invoked service (advertised: ' \
                              "#{options.map { |advertised| "`#{advertised['code']}`" }.join(', ')}), " \
                              'so it was ignored.',
                              request_index)
          return
        end

        type_check = CONFIGURATION_TYPE_CHECKS[option['type']]
        return if type_check.nil? || type_check.call(value)

        article = option['type'].match?(/\A[aeiou]/i) ? 'an' : 'a'
        add_request_message('error',
                            "`davinci-crd.configuration` property `#{code}` must be #{article} #{option['type']}, " \
                            "got #{value.class} value #{value.to_json}.",
                            request_index)
      end

      run do
        hook_requests = load_interaction_group_requests

        skip_if hook_requests.blank?, "No #{hook_name} hook requests received."

        hook_requests.each_with_index do |request, request_index|
          request_body = parse_json_request_entity(request.request_body, 'Request body', request_index)
          next unless request_body.present?

          validate_request_against_logical_model(request_body, request_index, '2.2.1')
          check_configuration_extension(request, request_body, request_index)

          output url: request_body['fhirServer'] if request_body['fhirServer'].present?
          if request_body.dig('fhirAuthorization', 'access_token').present?
            output smart_auth_info: { access_token: request_body['fhirAuthorization']['access_token'] }.to_json
          end
        end

        assert_no_error_messages("#{requests_with_errors_prefix}Non-conformant hook request. See Messages for details.")
      end
    end
  end
end
