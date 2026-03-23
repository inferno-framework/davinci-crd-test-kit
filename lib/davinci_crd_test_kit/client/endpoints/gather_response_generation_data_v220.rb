require_relative '../../cross_suite/tags'
require_relative '../../cross_suite/fhirpath_on_cds_request'
require_relative '../../cross_suite/replace_tokens'

module DaVinciCRDTestKit
  # Make requests to client's FHIR server to use in building responses
  module GatherResponseGenerationDataV220
    def gather_data
      add_prefetched_data_to_fetched_resources
      gather_each_prefetch_template
    end

    # -------------------------------------------------------------------------
    # fetched resources (from prefetch or additional requests)
    # -------------------------------------------------------------------------
    def fetched_resources
      @fetched_resources ||= {}
    end

    # Error handling: if no resourceType or id, skip
    # verification that everything has one will be handled elsewhere
    def add_prefetched_data_to_fetched_resources
      request_body['prefetch'].each_value do |prefetch_resource|
        next unless prefetch_resource['resourceType'].present?

        if prefetch_resouce['resourceType'] == 'Bundle'
          add_bundle_instances_to_fetched_resource(prefetch_resource)
        else
          add_instance_to_fetched_resource(prefetch_resource)
        end
      end
    end

    def add_bundle_instances_to_fetched_resource(bundle)
      bundle.entry.each do |entry|
        next unless entry.dig('resource', 'resourceType').present?

        add_instance_to_fetched_resource(entry['resource'])
      end
    end

    def add_instance_to_fetched_resource(resource_instance)
      return unless resource_instance['id'].present?

      key = "#{resource_instance['resourceType']}/#{resource_instance['id']}"
      return if fetched_resources.key?(key)

      fetched_resources[key] = resource_instance
    end

    # -------------------------------------------------------------------------
    # gather data using prefetch templates
    # -------------------------------------------------------------------------
    def hook_prefetch_templates
      @hook_prefetch_templates ||=
        JSON.parse(File.read(File.join(__dir__, '..', 'v2.2.0', 'cds-services-v220.json'))).find do |service|
          service['hook'] == request_body['hook']
        end['prefetch']
    end

    def gather_each_prefetch_template
      hook_request_for_gathering = request_body.dup
      hook_request_for_gathering['prefetch'] = {}

      hook_prefetch_templates.each do |prefetch_key, prefetch_request|
        instantiated_request = replace_tokens_in_string(prefetch_request, hook_request_for_gathering)
        request_results = build_request_results(instantiated_request)
        hook_request_for_gathering['prefetch'][prefetch_key] = request_results
      end
    end

    def build_request_results(request_string)
      if request_string.include?('?')
        if id_search?(request_string)
        else
        end
      elsif fetched_resources.key?(request_string)
        fetched_resources(request_string)
      else
        fetch_reference(normalize_reference(request_string))
      end
    end

    def id_search?(request_string)
      resource_type = request_string.split('?').first
      request_string.starts_with?("#{resource_type}?_id=")
    end

    # turn absolute references into relative if
    # for the fhir server indicated in the request
    def normalize_reference(reference)
      server = "#{request_body['fhirServer']&.chomp('/')}/"

      if request_body['fhirServer'].present? && reference.starts_with?(server)
        reference[server.length..]
      else
        reference
      end
    end

    def fetch_reference(reference)
      response = execute_request(reference)
      persist_query_request(response, [DATA_FETCH_TAG, hook_instance_tag])

      return nil unless response.status.to_s.starts_with?('2')

      JSON.parse(response.body)
    end

    # -------------------------------------------------------------------------
    # fhirpath for prefetch tokens
    # -------------------------------------------------------------------------
    include FhirpathOnCDSRequest

    def resolve(reference)
      reference = reference.reference if reference.is_a?(FHIR::Reference)
      reference = reference['reference'] if reference.is_a?(Hash)
      absolute_reference = if reference.starts_with?('http')
                             if fhir_server.present? && reference.starts_with?(fhir_server)
                               reference = reference.gsub(fhir_server, '')
                               false
                             else
                               true
                             end
                           else
                             false
                           end

      if absolute_reference
        # direct read, save request, add fetched resource to the map
      else
        relative_reference = reference.split('/')[1..2].join('/')
        if fetched_resources.key?(relative_reference)
          fetched_resources[relative_reference]
        elsif fhir_server.present?
          # read against the fhir server with the bearer token, save request, add fetched resource to the map
        end
      end
    end

    # --------------------

    def hook_instance_tag
      @hook_instance_tag ||= "#{HOOK_INSTANCE_TAG_PREFIX}#{request_body['hookInstance']}"
    end

    def extract_bundle_entries(bundle)
      return [] unless bundle.present? && bundle.is_a?(Hash) && bundle['entry'].is_a?(Array)

      bundle['entry'].map do |entry|
        next unless entry.is_a?(Hash) && entry['resource'].is_a?(Hash)

        entry['resource']
      end.compact
    end

    def gather_data_for_request(to_read_list, to_analyze_list)
      to_analyze_list.each do |resource|
        next unless resource.present?

        find_references_to_read(resource, to_read_list)
        analyzed_resources["#{resource['resourceType']}/#{resource['id']}"] = resource
      end

      read_and_analyze(to_read_list.pop, to_read_list) until to_read_list.empty?
    end

    def read_and_analyze(reference, to_read_list)
      normalized_reference = normalize_reference(reference)
      return if analyzed_resources.key?(normalized_reference)

      resource =
        if prefetched_resources.key?(normalized_reference)
          prefetched_resources[normalized_reference]
        else
          fetch_reference(normalized_reference)
        end
      analyzed_resources[normalized_reference] = resource
      return unless resource.present?

      find_references_to_read(resource, to_read_list)
    end

    def find_references_to_read(resource, to_read_list)
      references_to_read = REFERENCES_TO_READ_BY_RESOURCE_TYPE[resource['resourceType']&.to_sym]
      return [] unless references_to_read.present?

      references_to_read.each do |target_path|
        get_literal_reference_values(resource, target_path).each do |reference|
          to_read_list << reference unless to_read_list.include?(reference)
        end
      end
    end

    def get_literal_reference_values(resource, path)
      if path.include?('.')
        first_element, path = path.split('.')
        resource = resource[first_element]
      end

      reference_objects =
        case resource
        when Hash
          [resource[path]].flatten
        when Array
          resource.map { |entry| entry[path] }
        else
          []
        end

      reference_objects.map { |entry| entry['reference'] if entry.present? }.compact
    end

    def request_coverage
      @request_coverage ||= find_coverage_for_request
    end

    def find_coverage_for_request
      resource =
        if request_body.dig('prefetch', 'coverage').present?
          FHIR.from_contents(request_body.dig('prefetch', 'coverage').to_json)
        else
          query_for_coverages
        end

      return unless resource.is_a?(FHIR::Bundle)

      resource.entry&.first&.resource
    end

    def fhir_server_connection
      @fhir_server_connection ||=
        if request_body['fhirServer'].present? &&
           request_body['fhirAuthorization'].present? &&
           request_body['fhirAuthorization']['access_token'].present?
          Faraday.new(url: request_body['fhirServer'], request: { open_timeout: 10 },
                      headers: data_request_headers)
        end
    end

    def data_request_headers
      @data_request_headers ||=
        { 'Authorization' => "Bearer #{request_body['fhirAuthorization']['access_token']}" }
    end

    def execute_request(query)
      fhir_server_connection.get(query)
    rescue Faraday::Error => e
      # Warning: This is a hack. If there is an error with the request such that we never get a response, we have
      #          no clean way to persist that information for the Inferno test to check later. The solution here
      #          is to persist the request anyway with a status of nil, using the error message as response body
      Faraday::Response.new(response_body: e.message, url: fhir_server_connection.url_prefix.to_s)
    end

    def persist_query_request(response, tags)
      inferno_request_headers = data_request_headers.map { |name, value| { name:, value: } }
      inferno_response_headers = response.headers&.map { |name, value| { name:, value: } }
      requests_repo.create(
        verb: 'GET',
        url: response.env.url.to_s,
        direction: 'outgoing',
        status: response.status,
        request_body: response.env.request_body,
        response_body: response.env.response_body,
        test_session_id: test_run.test_session_id,
        result_id: result.id,
        request_headers: inferno_request_headers,
        response_headers: inferno_response_headers,
        tags:
      )
    end

    def query_for_coverages
      query = "Coverage?patient=#{request_body.dig('context', 'patientId')}&status=active"
      response = execute_request(query)

      persist_query_request(response, [DATA_FETCH_TAG, hook_instance_tag])
      return nil unless response.status.to_s.starts_with?('2')

      FHIR.from_contents(response.body)
    end

    def analyzed_resources
      @analyzed_resources ||= {}
    end

    def prefetched_resources
      @prefetched_resources ||=
        if request_body['prefetch'].blank? || !request_body['prefetch'].is_a?(Hash)
          {}
        else
          request_body['prefetch'].values.each_with_object({}) do |prefetched_resource, resource_hash|
            next unless prefetched_resource.is_a?(Hash)

            add_prefetch_resource_to_resource_hash(prefetched_resource, resource_hash)
          end
        end
    end

    def add_prefetch_resource_to_resource_hash(prefetched_resource, resource_hash)
      if prefetched_resource['resourceType'] == 'Bundle'
        prefetched_resource['entry']&.each do |entry|
          next unless entry_has_required_details?(entry)

          one_resource = entry['resource']
          key = "#{one_resource['resourceType']}/#{one_resource['id']}"
          resource_hash[key] = one_resource
        end
      elsif resource_has_required_details?(prefetched_resource)

        key = "#{prefetched_resource['resourceType']}/#{prefetched_resource['id']}"
        resource_hash[key] = prefetched_resource
      end
    end

    def entry_has_required_details?(entry)
      entry.present? &&
        entry.is_a?(Hash) &&
        entry['resource'].present? &&
        resource_has_required_details?(entry['resource'])
    end

    def resource_has_required_details?(resource)
      resource.is_a?(Hash) && resource['resourceType'].present? && resource['id'].present?
    end
  end
end
