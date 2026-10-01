module DaVinciCRDTestKit
  # Pulls the FHIR resources carried by a CDS Hooks request out of both places they can appear:
  # the hook `context` and the `prefetch`.
  module HookRequestResourceExtraction
    module_function

    def each_prefetch_resource(prefetch, &)
      return unless prefetch.is_a?(Hash)

      prefetch.each_value { |value| each_resource_within(value, &) }
    end

    def each_context_resource(context, &)
      return unless context.is_a?(Hash)

      context.each_value { |value| each_resource_within(value, &) }
    end

    def each_hook_request_resource(request_body, &)
      return unless request_body.is_a?(Hash)

      each_context_resource(request_body['context'], &)
      each_prefetch_resource(request_body['prefetch'], &)
    end

    def fhir_resources_by_type(requests)
      Array(requests).each_with_object({}) do |request, resources_by_type|
        request_body = parse_request_body(request)
        next if request_body.blank?

        each_hook_request_resource(request_body) do |raw_resource|
          resource = to_fhir_resource(raw_resource)
          next if resource.nil?

          (resources_by_type[resource.resourceType] ||= []) << resource
        end
      end
    end

    def resources_from_request(request)
      request_body = parse_request_body(request)
      return [] unless request_body.is_a?(Hash)

      context_resources(request_body) + prefetch_resources(request_body)
    end

    def context_resources(request_body)
      context = request_body['context']
      return [] unless context.is_a?(Hash)

      bundle_entry_resources(context_bundle(context['appointments'])) +
        bundle_entry_resources(context_bundle(context['draftOrders'])) +
        resources_from_value(context['fulfillmentTasks'])
    end

    def prefetch_resources(request_body)
      prefetch = request_body['prefetch']
      return [] unless prefetch.is_a?(Hash)

      prefetch.values.flat_map { |value| resources_from_value(value) }
    end

    def resources_from_value(value)
      case value
      when Array then value.flat_map { |entry| resources_from_value(entry) }
      when Hash then resources_from_hash(value)
      else []
      end
    end

    def resources_from_hash(contents)
      return [] if contents['resourceType'].blank?

      resource = to_fhir_resource(contents)
      return [] if resource.blank?
      return bundle_entry_resources(resource) if resource.is_a?(FHIR::Bundle)

      [resource]
    end

    def bundle_entry_resources(bundle)
      return [] unless bundle.is_a?(FHIR::Bundle)

      bundle.entry.filter_map { |entry| entry&.resource.presence }
    end

    # An absent context field is ordinary, so it is skipped before parsing rather than being handed
    # to fhir_models, which logs a deserialization error for it.
    def context_bundle(contents)
      return unless contents.present?

      to_fhir_resource(contents)
    end

    def each_resource_within(value, &block)
      case value
      when Array then value.each { |element| each_resource_within(element, &block) }
      when Hash then each_resource_within_hash(value, &block)
      end
    end

    def each_resource_within_hash(value, &block)
      return if value['resourceType'].blank?
      return block.call(value) unless value['resourceType'] == 'Bundle'

      Array(value['entry']).each do |entry|
        each_resource_within(entry['resource'], &block) if entry.is_a?(Hash)
      end
    end

    def parse_request_body(request)
      JSON.parse(request.request_body.to_s)
    rescue JSON::ParserError
      nil
    end

    def to_fhir_resource(raw_resource)
      FHIR.from_contents(raw_resource.to_json)
    end
  end
end
