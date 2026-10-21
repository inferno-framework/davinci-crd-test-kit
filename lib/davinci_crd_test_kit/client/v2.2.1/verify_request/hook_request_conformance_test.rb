require_relative '../../../cross_suite/requests_logical_model_validation'
require_relative '../../tagged_request_load_helper'
require_relative '../../multi_request_message_helper'
require_relative '../client_urls'

module DaVinciCRDTestKit
  module V221
    class HookRequestConformanceTest < Inferno::Test
      include RequestsLogicalModelValidation
      include DaVinciCRDTestKit::TaggedRequestLoadHelper
      include DaVinciCRDTestKit::MultiRequestMessageHelper

      id :crd_v221_hook_request_conformance
      title 'Hook requests have the correct structure and contents'
      description %(
        During this test, Inferno will check each request body against the structural and content
        requirements for the invoked hook. This includes checking that each property of the
        `davinci-crd.configuration` extension, when present, is one of the configuration options
        advertised by the invoked Inferno service and has the type defined for that option.
      )

      output :url, :smart_auth_info

      verifies_requirements 'cds-hooks_3.0.0-ballot@3', 'cds-hooks_3.0.0-ballot@214', 'cds-hooks_3.0.0-ballot@222',
                            'cds-hooks_3.0.0-ballot@223', 'cds-hooks_3.0.0-ballot@224',
                            'hl7.fhir.us.davinci-crd_2.2.1@dev-12', 'hl7.fhir.us.davinci-crd_2.2.1@found-20',
                            'hl7.fhir.us.davinci-crd_2.2.1@found-36-A',
                            'hl7.fhir.us.davinci-crd_2.2.1@hook-20', 'hl7.fhir.us.davinci-crd_2.2.1@hook-21'

      SERVICE_FILENAMES = {
        complete: 'cds-services-v221.json',
        subset: 'cds-services-prefetch-subset-v221.json'
      }.freeze

      # the JSON values that each configuration option type defined by CRD may take
      CONFIGURATION_TYPE_CHECKS = {
        'boolean' => ->(value) { [true, false].include?(value) },
        'integer' => ->(value) { value.is_a?(Integer) },
        'string' => ->(value) { value.is_a?(String) }
      }.freeze

      def advertised_configuration_options(request, hook)
        target = request.url.to_s.include?(PREFETCH_SUBSET_PREFIX) ? :subset : :complete
        @advertised_configuration_options ||= {}
        @advertised_configuration_options[[target, hook]] ||=
          JSON.parse(File.read(File.join(__dir__, '..', SERVICE_FILENAMES[target])))['services']
            .find { |service| service['hook'] == hook }
            &.dig('extension', 'davinci-crd.configuration-options')
      end

      # The logical model checks that the configuration is an object holding primitive values, but
      # not which properties the invoked service advertised or the type each one was given.
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
        if option.nil?
          add_request_message('error',
                              "`davinci-crd.configuration` property `#{code}` is not a configuration option " \
                              'advertised by the invoked service (advertised: ' \
                              "#{options.map { |advertised| "`#{advertised['code']}`" }.join(', ')}).",
                              request_index)
          return
        end

        type_check = CONFIGURATION_TYPE_CHECKS[option['type']]
        return if type_check.nil? || type_check.call(value)

        add_request_message('error',
                            "`davinci-crd.configuration` property `#{code}` must be a #{option['type']}, " \
                            "got #{value.to_json}.",
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
