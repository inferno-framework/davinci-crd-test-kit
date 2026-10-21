require_relative '../../cross_suite/hook_request_resource_extraction'
require_relative 'hook_request_data_access'

module DaVinciCRDTestKit
  # CRD v2.0.1: reads the resources named in the hook context, and follows the references at a fixed
  # set of paths within them, so that the CRD client's FHIR access is exercised and recorded.
  module V201HookRequestDataGathering
    include HookRequestDataAccess

    REFERENCES_TO_READ_BY_RESOURCE_TYPE = {
      Appointment: [
        'basedOn',
        'participant.actor'
      ],
      CommunicationRequest: [
        'requester',
        'sender',
        'recipient'
      ],
      DeviceRequest: [
        'requester',
        'performer'
      ],
      MedicationRequest: [
        'requester',
        'performer',
        'medicationReference',
        'dispenseRequest.performer'
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

      gather_data_for_request(order_dispatch_to_read, [request_body.dig('context', 'task')].compact)
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

    # Precondition: at most one level of nesting in the path
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

    def analyzed_resources
      @analyzed_resources ||= {}
    end

    def prefetched_resources
      @prefetched_resources ||= {}.tap do |resource_hash|
        HookRequestResourceExtraction.each_prefetch_resource(request_body['prefetch']) do |resource|
          next unless resource_has_required_details?(resource)

          resource_hash["#{resource['resourceType']}/#{resource['id']}"] = resource
        end
      end
    end

    def resource_has_required_details?(resource)
      resource.is_a?(Hash) && resource['resourceType'].present? && resource['id'].present?
    end
  end
end
