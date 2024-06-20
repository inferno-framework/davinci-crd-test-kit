require_relative '../client_hook_request_validation'

module DaVinciCRDTestKit
  class HookRequestValidPrefetchTest < Inferno::Test
    include ClientHookRequestValidation
    include URLs

    id :crd_hook_request_valid_prefetch
    title 'Hook contains valid prefetch response'
    description %(
      As stated in the [CDS hooks specification](https://cds-hooks.hl7.org/2.0#http-request), a CDS service request's
      `prefetch` field is an optional field that contains key/value pairs of FHIR queries that the service is requesting
      the CDS Client to perform and provide on each service call. The key is a string that describes the type of data
      being requested and the value is a string representing the FHIR query. See [Prefetch Template](https://cds-hooks.hl7.org/2.0#prefetch-template)
      for more information about how the `prefetch` formatting works.

      This test verifies that the incoming hook request's `prefetch` field is in a valid JSON format and validates each
      contained resource against its corresponding CRD resource profile. This test is optional and will be skipped if no
      `prefetch` field is contained in the hook request.
    )
    optional

    input :contexts, :prefetches

    def hook_name
      config.options[:hook_name]
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

    run do
      hook_contexts = json_parse(contexts)
      hook_prefetches = json_parse(prefetches)

      if hook_contexts && hook_prefetches
        skip_if(hook_prefetches.none? do |prefetch|
          prefetch_index = hook_prefetches.find_index(prefetch)
          prefetch.present? && hook_contexts[prefetch_index].present?
        end, "No #{hook_name} requests contained both the `context` and `prefetch` field.")

        hook_prefetches.each_with_index do |prefetch, index|
          @request_number = index + 1
          context = hook_contexts[index]

          info "#{request_number}Received hook request does not contain the `prefetch` field." if prefetch.blank?
          if context.blank?
            info %(#{request_number}Received hook request does not contain the `context` field
            which is needed to validate the `prefetch` field)
          end

          next if prefetch.blank? || context.blank?

          hook_request_prefetch_check(advertised_prefetch_fields, prefetch, context)
        end
      end
      no_error_validation('Prefetch is not valid.')
    end
  end
end
