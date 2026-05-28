require_relative 'profiles_and_resource_types'

module DaVinciCRDTestKit
  module LogicalModelsOverrideHelper
    # -------------------------------------------------------------------------
    # Clean up messages returned from logical model validation
    # -------------------------------------------------------------------------

    def reject_resource_issues(issues)
      issues.reject do |issue|
        issue.location&.match?(%r{/\*[A-Za-z]+/}) || # looking for /*<resourceType>/
          issue.message&.match(/.resource: Unable to find a match for the specified profile among choices/)
      end
    end

    # -------------------------------------------------------------------------
    # Check resource conformance outside the logical models
    # -------------------------------------------------------------------------

    def check_resource_conformance_to_coverage_profile(resource_hash, error_prefix, ig_semver)
      check_resource_type_and_validate(resource_hash, error_prefix, ig_semver, FHIR::Coverage)
    end

    def check_resource_conformance_to_questionnaire_task_profile(resource_hash, error_prefix, ig_semver)
      check_resource_type_and_validate(resource_hash, error_prefix, ig_semver, FHIR::Task)
    end

    def check_resource_conformance_to_order_or_encounter_profile(resource_hash, request_body, error_prefix, ig_semver)
      check_order_like_resource_conformance(resource_hash, request_body, error_prefix, ig_semver,
                                            allowed_types: ProfilesAndResourceTypes::ORDER_OR_ENCOUNTER_RESOURCE_CLASSES,
                                            disallowed_message: 'is not allowed as a target ' \
                                                                'for a coverage-information action')
    end

    def check_resource_conformance_to_order_profile(resource_hash, request_body, error_prefix, ig_semver)
      check_order_like_resource_conformance(resource_hash, request_body, error_prefix, ig_semver,
                                            allowed_types: ProfilesAndResourceTypes::ORDER_RESOURCE_CLASSES,
                                            disallowed_message: 'is not allowed for CRD orders')
    end

    # -------------------------------------------------------------------------
    # Resource conformance helpers
    # -------------------------------------------------------------------------

    def parse_action_resource(resource_hash, error_prefix)
      resource = FHIR.from_contents(resource_hash.to_json)
      unless resource.present?
        add_message('error', "#{error_prefix}resource is not FHIR.")
        return
      end
      yield resource
    end

    def check_resource_type_and_validate(resource_hash, error_prefix, ig_semver, expected_class)
      parse_action_resource(resource_hash, error_prefix) do |resource|
        if resource.is_a?(expected_class)
          resource_is_valid?(resource:, profile_url: structure_definition_map(ig_semver)[resource.resourceType],
                             message_prefix: error_prefix)
        else
          add_message('error', "#{error_prefix}found resource type '#{resource.resourceType}' " \
                               "expected '#{expected_class.name.split('::').last}'.")
        end
      end
    end

    def check_order_like_resource_conformance(resource_hash, request_body, error_prefix, ig_semver,
                                              allowed_types:, disallowed_message:)
      parse_action_resource(resource_hash, error_prefix) do |resource|
        case resource
        when FHIR::Appointment
          check_appointment_conformance(resource, request_body, error_prefix, ig_semver)
        when *allowed_types
          resource_is_valid?(resource:, profile_url: structure_definition_map(ig_semver)[resource.resourceType],
                             message_prefix: error_prefix)
        else
          add_message('error', "#{error_prefix}resource type '#{resource.resourceType}' #{disallowed_message}.")
        end
      end
    end

    # -------------------------------------------------------------------------
    # Appointment conformance (requires extra help to decide profile and check profile-based slicing)
    # -------------------------------------------------------------------------

    def check_appointment_conformance(appointment, request_body, error_prefix, ig_semver)
      target_appointment_profile =
        if appointment.basedOn.present?
          'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-appointment-with-order'
        else
          'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-appointment-no-order'
        end

      validation_issues = []
      resource_is_valid?(resource: appointment, profile_url: "#{target_appointment_profile}|#{ig_semver}",
                         add_messages_to_runnable: false, validator_response_details: validation_issues)

      manually_check_appointment_validation_errors(validation_issues, appointment, request_body)
        .each do |issue|
          add_message(issue.severity, "#{error_prefix}#{issue.message}")
        end
    end

    def manually_check_appointment_validation_errors(validation_issues, appointment, request_body)
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
    # Local/Relative reference helpers
    # -------------------------------------------------------------------------

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
              "one of the allowed resource types (#{allowed_resource_types.join(', ')})"
            end

          add_message('error',
                      "#{error_prefix} local reference resourceType '#{resource_type}' " \
                      "is not #{allowed_types_error_suffix}.")
          is_local_reference = false
        end
        unless id.match(/\A[A-Za-z0-9\-.]{1,64}\z/)
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
  end
end
