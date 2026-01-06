require_relative '../prefetch_contents_validation'

module DaVinciCRDTestKit
  class HookRequestPrefetchEqualsQueriedTest < Inferno::Test
    include PrefetchContentsValidation

    id :crd_hook_request_prefetch_equals_queried
    title 'Prefetched data is equivalent to queried data'
    description %(
      This test verifies that each key present in the incoming hook request's `prefetch` field is equivalent to the
      data returned by a query to the fhir server using the parameterized prefetch template.

      The queries will be performed after the hook response has been returned.
    )
    verifies_requirements 'cds-hooks_2.0@45'

    input :client_fhir_server,
          optional: true
    input :client_access_token,
          optional: true
    input :override_access_token,
          title: 'Override Bearer Token',
          description: %(
            Optionally provide a bearer token to use in place of the one provided in the hook request.
            Use only if the bearer token in the request will not be valid even right after the hook
            request is made. If provided it must have the same scope as the bearer token provided
            in the hook request.
          ),
          optional: true

    fhir_client do
      url :client_fhir_server
      bearer_token access_token
    end

    def access_token
      override_access_token.present? ? override_access_token : client_access_token
    end

    def hook_name
      config.options[:hook_name]
    end

    def crd_test_group
      config.options[:crd_test_group]
    end

    def tags_to_load
      crd_test_group.present? ? [hook_name, crd_test_group] : [hook_name]
    end

    def cds_services_json
      JSON.parse(File.read(File.join(
                             __dir__, '..', 'routes', 'cds-services.json'
                           )))['services']
    end

    def advertised_prefetch_fields
      advertised_hook_service = cds_services_json.find { |service| service['hook'] == hook_name }
      advertised_hook_service['prefetch']
    end

    def no_error_validation(message)
      assert messages.none? { |msg| msg[:type] == 'error' }, message
    end

    run do
      hook_requests = load_tagged_requests(*tags_to_load)

      skip_if hook_requests.blank?, 'No Hook Requests to verify.'

      pass_if !prefetched_data?(hook_requests), 'No prefetched data provided.'

      skip_if client_fhir_server.blank?,
              'No FHIR server provided in the hook request to use to validate the prefetch data.'

      if override_access_token.present?
        add_message(:warning,
                    'Override access token provided. Ensure that it has the same scope as used when ' \
                    'prefetching data for the hook request.')
      end

      hook_requests.each_with_index do |request, index|
        @request_number = index + 1
        check_prefetch_data_against_query(request, advertised_prefetch_fields)
      end

      no_error_validation('Prefetched data does not match the requested queries.')

      pass 'Prefetched data matches the requested queries.'
    end
  end
end
