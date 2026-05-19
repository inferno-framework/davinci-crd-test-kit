module DaVinciCRDTestKit
  module RequestsLogicalModelValidation
    CRD_CDS_HOOK_REQUEST_MODEL_URL = 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/CRDHooksRequest'.freeze

    def validate_request_against_logical_model(request_body, request_index, ig_version)
      if ig_version == '2.2.1'
        check_logical_model_conformance_no_resource_checks(request_body, request_index, ig_version)

      else
        conforms_to_logical_model?(request_body, "#{CRD_CDS_HOOK_REQUEST_MODEL_URL}|#{ig_version}",
                                   message_prefix: "(Request #{request_index + 1}) ")
      end

      perform_version_specific_additional_verification(request_body, request_index, ig_version)
    end

    private

    # -------------------------------------------------------------------------
    # Additional Validation to cover areas not cheked by the logical models
    # -------------------------------------------------------------------------

    def perform_version_specific_additional_verification(request_body, request_index, ig_version)
      case ig_version
      when '2.2.1'
        perform_v221_additional_verification(request_body, request_index)
      end
    end

    def perform_v221_additional_verification(request_body, request_index)
      check_context_resources_for_ids(request_body, request_index)
      check_relative_references(request_body, request_index)
      check_context_resource_profiles(request_body, request_index, '2.2.1')
    end

    # -------------------------------------------------------------------------
    # Context resources profile check (not working in v2.2.1 logical models)
    # -------------------------------------------------------------------------

    def check_logical_model_conformance_no_resource_checks(request_body, request_index, ig_version)
      validation_issues = []
      conforms_to_logical_model?(request_body, "#{CRD_CDS_HOOK_REQUEST_MODEL_URL}|#{ig_version}",
                                 add_messages_to_runnable: false, validator_response_details: validation_issues)

      reject_resource_issues(validation_issues).each do |issue|
        add_message(issue.severity, "(Request #{request_index + 1}) #{issue.message}")
      end
    end

    def reject_resource_issues(issues)
      issues.reject do |issue|
        issue.filtered || issue.location&.match?(%r{/\*[A-Za-z]+/}) # looking for /*<resourceType>/
      end
    end

    def check_context_resource_profiles(request_body, request_index, ig_version)
      case request_body['hook']
      when 'order-sign', 'order-select'
        check_draft_orders_profiles(request_body, request_index, ig_version)
      when 'order-dispatch'
        request_body.dig('context', 'fulfillmentTasks')&.each_with_index do |task, index|
          resource = FHIR.from_contents(task.to_json)
          resource_is_valid?(resource:, profile_url: "http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-task-dispatch|#{ig_version}",
                             message_prefix: "(Request #{request_index + 1}) " \
                                             "context.fulfillmentTasks entry #{index + 1} - ")
        end
      when 'appointment-book'
        check_appointments_profiles(request_body, request_index, ig_version)
      end
    rescue JSON::ParserError
      nil # no resource to validate - error found elsewhere
    end

    def check_draft_orders_profiles(request_body, request_index, ig_version)
      resource = FHIR.from_contents(request_body.dig('context', 'draftOrders')&.to_json)
      resource_is_valid?(resource:, profile_url: "http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-bundle-request|#{ig_version}",
                         message_prefix: "(Request #{request_index + 1}) context.draftOrders - ")
    end

    # -------------------------------------------------------------------------
    # Appointment conformance (requires extra help to decide profile and check profile-based slicing)
    # -------------------------------------------------------------------------

    def check_appointments_profiles(request_body, request_index, ig_version)
      resource = FHIR.from_contents(request_body.dig('context', 'appointments')&.to_json)
      return unless resource.is_a?(FHIR::Bundle)

      check_bundle_non_entry_resource_conformance(resource,
                                                  "(Request #{request_index + 1}) context.appointments - ",
                                                  ig_version)

      resource.entry.each_with_index do |entry, entry_index|
        next unless entry.resource.present? # error caught on Bundle validation

        error_prefix = "(Request #{request_index + 1}) context.appointments entry #{entry_index + 1} - "
        check_appointment_conformance(entry.resource, request_body, error_prefix, ig_version)
      end
    end

    def check_bundle_non_entry_resource_conformance(bundle, error_prefix, ig_version)
      validation_issues = []
      resource_is_valid?(resource: bundle, profile_url: "http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-bundle-base|#{ig_version}",
                         add_messages_to_runnable: false, validator_response_details: validation_issues)

      reject_entry_resource_issues(validation_issues).each do |issue|
        add_message(issue.severity, "#{error_prefix}#{issue.message}")
      end
    end

    def reject_entry_resource_issues(issues)
      issues.reject do |issue|
        issue.filtered || issue.location&.match?(/\ABundle\.entry\[\d+\]\.resource/)
      end
    end

    def check_appointment_conformance(appointment, request_body, error_prefix, ig_version)
      target_appointment_profile =
        if appointment.basedOn.present?
          'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-appointment-with-order'
        else
          'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-appointment-no-order'
        end

      validation_issues = []
      resource_is_valid?(resource: appointment, profile_url: "#{target_appointment_profile}|#{ig_version}",
                         add_messages_to_runnable: false, validator_response_details: validation_issues)

      filter_and_manually_check_appointment_validation_errors(validation_issues, appointment, request_body)
        .each do |issue|
          add_message(issue.severity, "#{error_prefix}#{issue.message}")
        end
    end

    def filter_and_manually_check_appointment_validation_errors(validation_issues, appointment, request_body)
      @matched_participant_slice_indexes = []
      validation_issues.reverse.reject do |issue|
        issue.filtered ||
          resolved_participant_primary_performer_slice_issue?(issue, appointment) ||
          resolved_participant_patient_slice_issue?(issue, appointment, request_body) ||
          (
            # list reversed to hit these issues after the slice matching
            @matched_participant_slice_indexes.present? &&
            issue.message.match(/Appointment\.participant\[#{Regexp.union(@matched_participant_slice_indexes.map(&:to_s))}\]: This element does not match any known slice defined in the profile/) # rubocop:disable Layout/LineLength
          )
      end.reverse
    end

    def resolved_participant_primary_performer_slice_issue?(issue, appointment)
      return false unless issue.message.match(/Slice 'Appointment.participant:PrimaryPerformer': a matching slice is required, but not found/) # rubocop:disable Layout/LineLength

      appointment.participant.each_with_index.any? do |participant, index|
        # type + profile of the reference checked during prefetch checking
        match = participant.actor.present? &&
                participant.actor.reference.present? &&
                primary_performer_type?(participant.type)
        @matched_participant_slice_indexes << index if match
        match
      end
    end

    def primary_performer_type?(types)
      types&.any? do |type|
        type.coding&.any? do |coding|
          coding.code == 'PPRF' &&
            coding.system == 'http://terminology.hl7.org/CodeSystem/v3-ParticipationType'
        end
      end
    end

    # NOTE: for simplicity and to avoid duplication of checks, this looks for
    # a particular patient reference from the context.patientId,
    # the profile of which will be verified during prefetch profile checking
    def resolved_participant_patient_slice_issue?(issue, appointment, request_body)
      return false unless issue.message.match(/Slice 'Appointment.participant:Patient': a matching slice is required, but not found/) # rubocop:disable Layout/LineLength

      local_patient_ref = "Patient/#{request_body.dig('context', 'patientId')}"
      absolute_patient_ref = "#{request_body['fhirServer'].chomp('/')}/#{local_patient_ref}"
      appointment.participant.each_with_index.any? do |participant, index|
        match = [local_patient_ref, absolute_patient_ref].include?(participant.actor&.reference)
        @matched_participant_slice_indexes << index if match
        match
      end
    end

    # -------------------------------------------------------------------------
    # Context relative reference checks
    # -------------------------------------------------------------------------

    USER_ID_ALLOWED_RESOURCE_TYPES = [
      'Practitioner', 'PractitionerRole', 'Patient', 'RelatedPerson'
    ].freeze

    PERFORMER_ALLOWED_RESOURCE_TYPES = [
      'Practitioner', 'PractitionerRole'
    ].freeze

    ORDERS_ALLOWED_RESOURCE_TYPES = [
      'CommunicationRequest', 'DeviceRequest', 'MedicationRequest',
      'NutritionOrder', 'ServiceRequest', 'VisionPrescription'
    ].freeze

    # verify that context fields required to contain local references (resourceType/id)
    # do contain them and that the resourceType is in the list of expected types.
    def check_relative_references(request_body, request_index)
      # unless order-dispatch, check userId
      # if order-dispatch, check performer and dispatchedOrders list
      # if order-select, check selections

      if request_body['hook'] == 'order-dispatch'
        local_reference?(request_body['context']['performer'],
                         "(Request #{request_index + 1}) context.performer",
                         allowed_resource_types: PERFORMER_ALLOWED_RESOURCE_TYPES)
        request_body['context']['dispatchedOrders'].each_with_index do |order_reference, index|
          local_reference?(order_reference,
                           "(Request #{request_index + 1}) context.dispatchedOrders entry #{index + 1}",
                           allowed_resource_types: ORDERS_ALLOWED_RESOURCE_TYPES)
        end
      else
        local_reference?(request_body['context']['userId'],
                         "(Request #{request_index + 1}) context.userId",
                         allowed_resource_types: USER_ID_ALLOWED_RESOURCE_TYPES)
        if request_body['hook'] == 'order-select'
          request_body['context']['selections'].each_with_index do |order_reference, index|
            error_prefix = "(Request #{request_index + 1}) context.selections entry #{index + 1}"
            next unless local_reference?(order_reference,
                                         error_prefix,
                                         allowed_resource_types: ORDERS_ALLOWED_RESOURCE_TYPES)

            referenced_resource_present_in_bundle?(request_body['context']['draftOrders'], order_reference,
                                                   error_prefix, 'draftOrders')
          end
        end
      end
    end

    def local_reference?(value, error_prefix, allowed_resource_types: nil)
      is_local_reference = true
      local_reference_match = value.match(%r{^([A-Za-z]+)/(.+)$})
      if local_reference_match.present?
        resource_type = local_reference_match[1]
        id = local_reference_match[2]

        unless allowed_resource_type?(resource_type, allowed_resource_types)
          allowed_types_error_suffix =
            if allowed_resource_types.nil?
              'a valid FHIR resource type.'
            else
              "an one of the allowed resource types (#{allowed_resource_types.join(', ')})"
            end

          add_message('error',
                      "#{error_prefix} local reference resourceType '#{resource_type}' " \
                      "is not #{allowed_types_error_suffix}.")
          is_local_reference = false
        end
        unless id.match(/\A[A-Za-z0-9\-\.]{1,64}\z/)
          add_message('error',
                      "#{error_prefix} local reference id '#{id}' does not meet " \
                      '[FHIR id data type](https://hl7.org/fhir/R4/datatypes.html#id) requirements.')
          is_local_reference = false
        end
      else
        add_message('error', "#{error_prefix} expected a local reference, got '#{value}'.")
        is_local_reference = false
      end

      is_local_reference
    end

    def allowed_resource_type?(resource_type, allowed_resource_types)
      if allowed_resource_types.nil?
        FHIR::RESOURCES.include?(resource_type)
      else
        allowed_resource_types.include?(resource_type)
      end
    end

    def referenced_resource_present_in_bundle?(bundle, local_reference, error_prefix, bundle_location)
      unless bundle.present? && bundle['entry'].present?
        add_message('error',
                    "#{error_prefix} referenced resource '#{local_reference}' " \
                    "not found in the #{bundle_location} Bundle.")
        return false
      end

      target_resource_type, target_id = local_reference.split('/')
      found = bundle['entry'].any? do |entry|
        entry.dig('resource', 'resourceType') == target_resource_type && entry.dig('resource', 'id') == target_id
      end
      return true if found

      add_message('error',
                  "#{error_prefix} referenced resource '#{local_reference}' " \
                  "not found in the #{bundle_location} Bundle.")
      false
    end

    # -------------------------------------------------------------------------
    # Context resources include ids
    # -------------------------------------------------------------------------

    # logical models don't explicitly check for resource ids
    def check_context_resources_for_ids(request_body, request_index)
      hook_name = request_body['hook']
      context = request_body['context']
      return unless context.present?

      case hook_name
      when 'appointment-book'
        check_bundle_resources_for_ids(context['appointments'], request_index, 'appointments')
      when 'order-sign', 'order-select'
        check_bundle_resources_for_ids(context['draftOrders'], request_index, 'draftOrders')
      when 'order-dispatch'
        context['fulfillmentTasks']&.each_with_index do |task, index|
          check_resource_for_id(FHIR.from_contents(task.to_json), request_index, 'fulfillmentTasks', index)
        end
      end
    end

    def check_bundle_resources_for_ids(parsed_bundle, request_index, context_field_name)
      return unless parsed_bundle.present?

      bundle = FHIR.from_contents(parsed_bundle.to_json)
      return unless bundle.present?

      bundle.entry&.each_with_index do |entry, index|
        check_resource_for_id(entry.resource, request_index, context_field_name, index)
      end
    end

    def check_resource_for_id(resource, request_index, context_field_name, entry_index = nil)
      return if resource.present? && resource.id.present?

      message = "(Request #{request_index + 1}) " \
                'FHIR resources provided in the hook context must have an id, none found for ' \
                "`context.#{context_field_name}`#{" entry #{entry_index + 1}" if entry_index.present?}."
      add_message('error', message)
    end
  end
end
