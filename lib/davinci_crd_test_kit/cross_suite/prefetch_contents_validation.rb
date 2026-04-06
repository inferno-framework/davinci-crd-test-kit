require_relative 'replace_tokens'

module DaVinciCRDTestKit
  module PrefetchContentsValidation
    include ReplaceTokens

    def request_number
      if @request_number.blank?
        ''
      else
        "Request #{@request_number}: "
      end
    end

    def prefetched_data?(requests)
      requests.any? do |request|
        JSON.parse(request.request_body)['prefetch']&.keys.present?
      end
    end

    def check_prefetch_data_against_query(hook_request, advertized_prefetch_queries)
      request_body = JSON.parse(hook_request.request_body)
      request_body['prefetch']&.each do |key, value|
        next unless advertized_prefetch_queries[key].present?

        instantiated_query = replace_tokens_in_string(advertized_prefetch_queries[key], request_body)

        queried_resource_list = query_for_data(instantiated_query)
        prefetched_resource_list = prefetched_data_to_resource_list(value)

        next if prefetched_data_equals_queried_data?(prefetched_resource_list, queried_resource_list)

        add_message('error', "#{request_number}Prefetched data `#{key}` was different than " \
                             "data returned from requested query `#{instantiated_query}`.")
      end
    end

    def query_for_data(prefetch_query)
      is_search = prefetch_query.include?('?')

      split_query = is_search ? prefetch_query.split('?') : prefetch_query.split('/')
      resource_type = split_query.first

      query_result =
        if is_search
          fhir_search(resource_type, params: Rack::Utils.parse_nested_query(split_query.last))
        else
          fhir_read(resource_type, split_query.last)
        end

      return [] unless query_result.status.to_s.starts_with?('2')
      return [] unless query_result.resource.present?

      if is_search
        fetch_all_bundled_resources(resource_type:, bundle: query_result.resource)
      else
        [query_result.resource]
      end
    end

    def prefetched_data_equals_queried_data?(prefetched_data, queried_data)
      prefetched_id_list = prefetched_data.map { |resource| "#{resource.resourceType}/#{resource.id}" }.sort
      queried_id_list = queried_data.map { |resource| "#{resource.resourceType}/#{resource.id}" }.sort

      prefetched_id_list == queried_id_list
    end

    def prefetched_data_to_resource_list(prefetched_data)
      return [] unless prefetched_data.present?

      fhir_data = FHIR.from_contents(prefetched_data.to_json)
      if fhir_data.is_a?(FHIR::Bundle)
        fhir_data.entry.map(&:resource)
      else
        [fhir_data]
      end
    end
  end
end
