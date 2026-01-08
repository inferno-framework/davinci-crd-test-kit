require_relative 'tags'

module DaVinciCRDTestKit
  # Make requests to client's FHIR server to use in building responses
  module GatherResponseGenerationData
    REFERENCES_TO_READ_BY_RESOURCE_TYPE = {
      Appointment: [
        'basedOn',
        'participant.actor'
      ],
      CommunicationRequest: [
        'requester',
        'sender'
      ],
      DeviceRequest: [
        'requester',
        'performer'
      ],
      MedicationRequest: [
        'requester',
        'performer',
        'medicationReference'
      ],
      NutritionOrder: [
        'orderer'
      ],
      ServiceRequest: [
        'requester',
        'performer',
        'locationReference'
      ],
      VisionPrescription: [
        'prescriber'
      ],
      Encounter: [
        'participant.individual',
        'location.location',
        'serviceProvider'
      ],
      PractitionerRole: [
        'practitioner',
        'organization',
        'location'
      ]
    }.freeze

    def gather_appointment_book_data
      appointment_book_to_read = []
      patient_id = request_body.dig('context', 'patientId')
      encounter_id = request_body.dig('context', 'encounterId')
      user_id = request_body.dig('context', 'userId')
      appointment_book_to_read << "Patient/#{patient_id}" if patient_id.present?
      appointment_book_to_read << "Encounter/#{encounter_id}" if encounter_id.present?
      appointment_book_to_read << user_id if user_id.present?

      appointment_book_to_analyze = extract_bundle_entries(request_body.dig('context', 'appointments'))

      gather_data_for_request(appointment_book_to_read, appointment_book_to_analyze)
    end

    def gather_encounter_start_data
      encounter_start_to_read = []
      patient_id = request_body.dig('context', 'patientId')
      encounter_id = request_body.dig('context', 'encounterId')
      user_id = request_body.dig('context', 'userId')
      encounter_start_to_read << "Patient/#{patient_id}" if patient_id.present?
      encounter_start_to_read << "Encounter/#{encounter_id}" if encounter_id.present?
      encounter_start_to_read << user_id if user_id.present?

      gather_data_for_request(encounter_start_to_read, [])
    end

    def gather_encounter_discharge_data
      encounter_discharge_to_read = []
      patient_id = request_body.dig('context', 'patientId')
      encounter_id = request_body.dig('context', 'encounterId')
      user_id = request_body.dig('context', 'userId')
      encounter_discharge_to_read << "Patient/#{patient_id}" if patient_id.present?
      encounter_discharge_to_read << "Encounter/#{encounter_id}" if encounter_id.present?
      encounter_discharge_to_read << user_id if user_id.present?

      gather_data_for_request(encounter_discharge_to_read, [])
    end

    def gather_order_select_data
      order_sign_to_read = []
      patient_id = request_body.dig('context', 'patientId')
      encounter_id = request_body.dig('context', 'encounterId')
      user_id = request_body.dig('context', 'userId')
      order_sign_to_read << "Patient/#{patient_id}" if patient_id.present?
      order_sign_to_read << "Encounter/#{encounter_id}" if encounter_id.present?
      order_sign_to_read << user_id if user_id.present?

      order_sign_to_analyze = extract_bundle_entries(request_body.dig('context', 'draftOrders')).select do |resource|
        request_body.dig('context', 'selections').include?("#{resource['resourceType']}/#{resource['id']}")
      end

      gather_data_for_request(order_sign_to_read, order_sign_to_analyze)
    end

    def gather_order_sign_data
      order_sign_to_read = []
      patient_id = request_body.dig('context', 'patientId')
      encounter_id = request_body.dig('context', 'encounterId')
      user_id = request_body.dig('context', 'userId')
      order_sign_to_read << "Patient/#{patient_id}" if patient_id.present?
      order_sign_to_read << "Encounter/#{encounter_id}" if encounter_id.present?
      order_sign_to_read << user_id if user_id.present?

      order_sign_to_analyze = extract_bundle_entries(request_body.dig('context', 'draftOrders'))

      gather_data_for_request(order_sign_to_read, order_sign_to_analyze)
    end

    def gather_order_dispatch_data
      order_dispatch_to_read = []
      patient_id = request_body.dig('context', 'patientId')
      order_id = request_body.dig('context', 'order')
      performer_id = request_body.dig('context', 'performer')
      order_dispatch_to_read << "Patient/#{patient_id}" if patient_id.present?
      order_dispatch_to_read << order_id if order_id.present?
      order_dispatch_to_read << performer_id if performer_id.present?

      gather_data_for_request(order_dispatch_to_read, [request_body.dig('context', 'task')])
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
      persist_query_request(response, [DATA_FETCH_TAG, request_body['hookInstance']])

      return nil unless response.status.to_s.starts_with?('2')

      JSON.parse(response.body)
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
      @request_coverage ||= query_for_coverages&.entry&.first&.resource
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
      persist_query_request(response, [DATA_FETCH_TAG, request_body['hookInstance']])

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
