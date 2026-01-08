require_relative '../tags'

module DaVinciCRDTestKit
  class HookRequestFetchedDataTest < Inferno::Test
    id :crd_hook_request_fetched_data
    title 'Required data was accessible during the hook request'
    description %(
      Clients must make a set of data related to the request available to the CRD Server via either prefetch
      as a part of the hook invocation or via FHIR API during server processing of the hook call. According
      to the IG, the minimal data set includes:
      - Patient
      - Relevant Coverage
      - Authoring Practitioner
      - Authoring Organization
      - Requested performing Practitioner (if specified)
      - Requested performing Organization (if specified)
      - Requested Location (if specified)
      - Associated Medication (if any)
      - Associated Device (if any)

      When it receives a hook invocation, Inferno analyzes the hook request to determine what resources it
      needs access to and requests those that are not provided as a part of the prefetched data. All data
      is requested via the read interaction except for Coverages which requires a search interaction.

      This test checks that those requests were successful, demonstrating that the system can provide access
      to this required information.
    )
    verifies_requirements 'hl7.fhir.us.davinci-crd_2.0.1@43'

    def hook_name
      config.options[:hook_name]
    end

    def crd_test_group
      config.options[:crd_test_group]
    end

    def tags_to_load
      crd_test_group.present? ? [hook_name, crd_test_group] : [hook_name]
    end

    def no_error_validation(message)
      assert messages.none? { |msg| msg[:type] == 'error' }, message
    end

    run do
      hook_requests = load_tagged_requests(*tags_to_load)

      hook_requests.each do |hook_request|
        request_body = JSON.parse(hook_request.request_body)
        hook_instance = request_body['hookInstance']

        failed_data_fetches =
          load_tagged_requests(hook_instance, DATA_FETCH_TAG).reject { |fetch| fetch.status.to_s.starts_with?('2') }

        next unless failed_data_fetches.present?

        server = "#{request_body['fhirServer'].chomp('/')}/"
        failed_data_fetches.each do |request|
          reference = request.url.starts_with?(server) ? request.url[server.length..] : request.url
          if reference.starts_with?('Coverage')
            add_message(:error,
                        "Failed to perform Coverage search `#{reference}` for hook instance `#{hook_instance}`.")
          else
            add_message(:error, "Failed to read reference `#{reference}` for hook instance `#{hook_instance}`.")
          end
        end
      end

      no_error_validation('Inferno could not fetch some required data during the hook invocations.')
    end
  end
end
