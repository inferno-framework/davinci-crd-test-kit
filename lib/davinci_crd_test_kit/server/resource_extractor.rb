module DaVinciCRDTestKit
  module ResourceExtractor
    def resources_from_request(request)
      request_body = JSON.parse(request.request_body)
      return [] unless request_body.is_a?(Hash)

      context_resources(request_body) + prefetch_resources(request_body)
    rescue JSON::ParserError
      []
    end

    def context_resources(request_body)
      context = request_body['context']
      return [] unless context.is_a?(Hash)

      bundle_entry_resources(parse_fhir_data(context['appointments'])) +
        bundle_entry_resources(parse_fhir_data(context['draftOrders'])) +
        resources_from_value(context['fulfillmentTasks'])
    end

    def prefetch_resources(request_body)
      prefetch = request_body['prefetch']
      return [] unless prefetch.is_a?(Hash)

      prefetch.values.flat_map { |value| resources_from_value(value) }
    end

    def resources_from_value(value)
      case value
      when Array
        value.flat_map { |entry| resources_from_value(entry) }
      when Hash
        resources_from_hash(value)
      else
        []
      end
    end

    def resources_from_hash(contents)
      return [] unless contents['resourceType'].present?

      fhir_data = parse_fhir_data(contents)
      return [] unless fhir_data.present?

      return bundle_entry_resources(fhir_data) if fhir_data.is_a?(FHIR::Bundle)

      [fhir_data]
    end

    def bundle_entry_resources(bundle)
      return [] unless bundle.is_a?(FHIR::Bundle)

      bundle.entry.filter_map do |entry|
        next unless entry&.resource.present?

        entry.resource
      end
    end

    def parse_fhir_data(contents)
      return unless contents.present?

      FHIR.from_contents(contents.to_json)
    rescue StandardError
      nil
    end
  end
end
