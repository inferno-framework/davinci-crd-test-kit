module DaVinciCRDTestKit
  module HookRequestFieldValidation
    def request_number
      if @request_number.blank?
        ''
      else
        "Request #{@request_number}: "
      end
    end

    def json_parse(json)
      JSON.parse(json)
    rescue JSON::ParserError
      add_message('error', "#{request_number}Invalid JSON.")
      false
    end

    def hook_required_fields
      {
        'hook' => String,
        'hookInstance' => String,
        'context' => Hash
      }
    end

    def fhir_authorization_required_fields
      {
        'access_token' => String,
        'token_type' => String,
        'expires_in' => Integer,
        'scope' => String,
        'subject' => String
      }
    end

    def hook_optional_fields
      {
        'fhirServer' => String,
        'fhirAuthorization' => Hash,
        'prefetch' => Hash
      }
    end

    def common_context_fields
      { 'userId' => String, 'patientId' => String }.freeze
    end

    def context_required_fields_by_hook
      {
        'appointment-book' => common_context_fields.merge('appointments' => Hash),
        'encounter-start' => common_context_fields.merge('encounterId' => String),
        'encounter-discharge' => common_context_fields.merge('encounterId' => String),
        'order-select' => common_context_fields.merge('selections' => Array, 'draftOrders' => Hash),
        'order-dispatch' => { 'patientId' => String, 'order' => String, 'performer' => String },
        'order-sign' => common_context_fields.merge('draftOrders' => Hash)
      }.freeze
    end

    def context_optional_fields_by_hook
      {
        'appointment-book' => { 'encounterId' => String },
        'order-select' => { 'encounterId' => String },
        'order-dispatch' => { 'task' => Hash },
        'order-sign' => { 'encounterId' => String }
      }.freeze
    end

    def optional_field_resource_types
      {
        'task' => 'Task'
      }
    end

    def context_user_types_by_hook
      shared_resources = ['Practitioner', 'PractitionerRole']
      {
        'appointment-book' => ['Patient', 'RelatedPerson'].concat(shared_resources),
        'encounter-start' => shared_resources,
        'encounter-discharge' => shared_resources,
        'order-select' => shared_resources,
        'order-sign' => shared_resources
      }.freeze
    end

    def structure_definition_map
      {
        'Practitioner' => 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-practitioner',
        'PractitionerRole' => 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-practitionerrole',
        'Patient' => 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-patient',
        'Encounter' => 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-encounter',
        'Appointment' => 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-appointment',
        'DeviceRequest' => 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-devicerequest',
        'MedicationRequest' => 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-medicationrequest',
        'NutritionOrder' => 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-nutritionorder',
        'ServiceRequest' => 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-servicerequest',
        'VisionPrescription' => 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-visionprescription',
        'Medication' => 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-medication',
        'Device' => 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-device',
        'CommunicationRequest' => 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-communicationrequest',
        'Task' => 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-taskquestionnaire',
        'Coverage' => 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-coverage',
        'Location' => 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-location',
        'Organization' => 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-organization'
      }.freeze
    end

    def hook_request_required_fields_check(request_body, hook_name)
      hook_required_fields.each do |field, type|
        if request_body[field].blank?
          add_message('error', "#{request_number}Hook request did not contain required field: `#{field}`")
          next
        end

        unless request_body[field].is_a?(type)
          add_message('error', "#{request_number}Hook request field #{field} is not of type #{type}")
          next
        end
      end

      if request_body['hook'] != hook_name
        add_message('error',
                    "#{request_number}The `hook` field should be #{hook_name}, but was #{request_body['hook']}")
        return
      end

      return unless request_body['fhirAuthorization'].present? && request_body['fhirServer'].blank?

      add_message('error', %(
                  #{request_number}Missing `fhirServer` field: If `fhirAuthorization` is provided, this field is
                  #REQUIRED.))
    end

    def fhir_auth_fields_valid?(fhir_authorization_required_fields, fhir_authorization)
      fhir_auth_valid = true
      fhir_authorization_required_fields.each do |field, type|
        if fhir_authorization[field].blank?
          add_message('error', "#{request_number}`fhirAuthorization` did not contain required field: `#{field}`")
          fhir_auth_valid = false
        end
        unless fhir_authorization[field].is_a?(type)
          add_message('error', "#{request_number}`fhirAuthorization` field #{field} is not of type #{type}")
          fhir_auth_valid = false
        end
      end
      fhir_auth_valid
    end

    def check_patient_scope_requirement(scopes, fhir_authorization)
      if scopes.any? { |scope| scope.start_with?('patient/') } &&
         !(fhir_authorization['patient'] && fhir_authorization['patient'].is_a?(String))
        info %(
           #{request_number}The `patient` field for request SHOULD be populated to identify the FHIR id of that
           patient when the granted SMART scopes include patient scopes)
      end
    end

    def hook_request_fhir_auth_check(request_body)
      if request_body['fhirAuthorization']

        fhir_authorization = request_body['fhirAuthorization']

        return unless fhir_auth_fields_valid?(fhir_authorization_required_fields, fhir_authorization)

        if fhir_authorization['token_type'] != 'Bearer'
          add_message('error', "#{request_number}`fhirAuthorization` `token_type` field is not set to 'Bearer'")
        end

        access_token = fhir_authorization['access_token']

        scopes = fhir_authorization['scope'].split

        check_patient_scope_requirement(scopes, fhir_authorization)
      end
      { fhir_server_uri: request_body['fhirServer'], fhir_access_token: access_token }
    end

    def hook_request_optional_fields_check(request_body)
      hook_optional_fields.each do |field, type|
        info "#{request_number}Hook request did not contain optional field: `#{field}`" if request_body[field].blank?

        if request_body[field] && !request_body[field].is_a?(type)
          add_message('error', "#{request_number}Hook request field #{field} is not of type #{type}")
        end
      end
      hook_request_fhir_auth_check(request_body)
    end

    def validate_presence_and_type(object, field_name, type, description = '')
      value = object[field_name]
      unless value
        error_msg = "#{description} does not contain required field `#{field_name}`: #{description} `#{object}`."
        add_message('error', error_msg)
        return
      end

      is_valid_type = type == 'URL' ? valid_url?(value) : value.is_a?(type)
      unless is_valid_type
        error_msg = type == 'URL' ? 'is not a valid URL' : "is not of type `#{type}`"
        add_message('error', "#{description} field `#{field_name}` #{error_msg}: #{description} `#{object}`.")
        return
      end

      return unless value.blank?

      error_msg = "#{description} field `#{field_name}` should not be an empty #{type}: #{description} `#{object}`."
      add_message('error', error_msg)
    end

    def hook_request_context_check(context, hook_name)
      required_fields = context_required_fields_by_hook[hook_name]
      required_fields.each do |field, type|
        validate_presence_and_type(context, field, type,
                                   "#{request_number}#{hook_name} request context")
      end
      context_validate_optional_fields(context, hook_name)
      hook_specific_context_check(context, hook_name)
    end

    def hook_specific_context_check(context, hook_name)
      case hook_name
      when 'appointment-book'
        appointment_book_context_check(context)
      when 'encounter-start', 'encounter-discharge'
        encounter_start_or_discharge_context_check(context, hook_name)
      when 'order-select', 'order-sign'
        order_select_or_sign_context_check(context, hook_name)
      when 'order-dispatch'
        order_dispatch_context_check(context)
      end
    end

    def hook_user_type_check(context, hook_name)
      supported_resource_types = context_user_types_by_hook[hook_name]
      resource_reference_check(context['userId'], 'userId', supported_resource_types:)
    end

    def resource_reference_check(reference, field_name, supported_resource_types: nil)
      return unless reference.is_a?(String) && valid_reference_format?(reference, field_name)

      resource_type, resource_id = reference.split('/')

      if supported_resource_types && !supported_resource_types.include?(resource_type)
        error_msg = "#{request_number}Unsupported resource type: `#{field_name}` type should be one " \
                    "of the following: #{supported_resource_types.to_sentence}, but " \
                    "received #{resource_type}."

        add_message('error', error_msg)
        return
      end

      query_and_validate_id_field(resource_type, resource_id) if client_test? && !field_name.include?('selections')
    end

    def valid_reference_format?(reference, field_name)
      resource_type, resource_id = reference.split('/')
      return true if resource_type.present? && resource_id.present?

      add_message('error', %(
        #{request_number}Invalid `#{field_name}` format. Expected `{resourceType}/{id}`,
        received `#{reference}`.
      ))
      false
    end

    def id_only_fields_check(hook_name, context, id_fields)
      id_fields.each do |field|
        resource_id = context[field]
        next unless resource_id.is_a?(String) && valid_id_format?(field, hook_name, resource_id)

        if client_test?
          resource_type = field.split(/(?=[A-Z])/).first.capitalize
          query_and_validate_id_field(resource_type, resource_id)
        end
      end
    end

    def valid_id_format?(field, hook_name, resource_id)
      if resource_id.include?('/')
        error_msg = %(
          #{request_number}`#{field}` in #{hook_name} context should be a plain ID, not a reference.
          Got: `#{resource_id}`.)
        add_message('error', error_msg)
        false
      end
      true
    end

    def bundle_entries_check(context, context_field_name, bundle, resource_types, status = nil)
      bundle.entry.each do |entry|
        resource_id = entry.resource.id
        next unless resource_id.blank?

        error_msg = 'Resource in the FHIR Bundle does not have an id'
        add_message('error', error_msg)
      end

      target_resources = bundle.entry.map(&:resource).select { |r| resource_types.include?(r.resourceType) }
      if target_resources.blank?
        error_msg = "#{request_number}`#{context_field_name}` bundle must contain at least one of the " \
                    "expected resource types: #{resource_types.to_sentence}. In Context `#{context}`"
        add_message('error', error_msg)
        return
      end

      status_check(context, context_field_name, status, target_resources)

      target_resources.each do |resource|
        resource_is_valid?(resource:, profile_url: structure_definition_map[resource.resourceType])
      end
    end

    def status_check(context, context_field_name, status, resources)
      return unless status && !resources.all? { |resource| resource.status == status }

      error_msg = "#{request_number}All #{resources.map(&:resourceType).uniq.to_sentence} resources in " \
                  "`#{context_field_name}` bundle must have a `#{status}` status. In Context `#{context}`"
      add_message('error', error_msg)
    end

    def parse_fhir_bundle_from_context(context_field_name, context)
      fhir_bundle = FHIR.from_contents(context[context_field_name].to_json)
      if fhir_bundle.blank?
        error_msg = "#{request_number}`#{context_field_name}` field is not a FHIR resource: " \
                    "`#{context[context_field_name]}`. In Context `#{context}`"
        add_message('error', error_msg)
        return
      end

      return fhir_bundle if fhir_bundle.is_a?(FHIR::Bundle)

      error_msg = "#{request_number}Wrong context resource type: Expected `Bundle`, got " \
                  "`#{fhir_bundle.resourceType}`. In Context `#{context}`"
      add_message('error', error_msg)
      nil
    end

    def context_selections_check(context, selections, order_refs, expected_resource_types)
      return unless selections.is_a?(Array)

      selections.each do |reference|
        resource_reference_check(reference, 'selections item', supported_resource_types: expected_resource_types)
        next if order_refs.include?(reference)

        error_msg = "#{request_number}`selections` field must reference FHIR resources in `draftOrders`. " \
                    "#{reference} is not in `draftOrders`. In Context `#{context}`"
        add_message('error', error_msg)
      end
    end

    def appointment_book_context_check(context)
      hook_user_type_check(context, 'appointment-book')
      id_only_fields_check('appointment-book', context, ['patientId'])

      appointment_bundle = parse_fhir_bundle_from_context('appointments', context)
      return if appointment_bundle.blank?

      expected_resource_types = ['Appointment']
      bundle_entries_check(context, 'appointments', appointment_bundle, expected_resource_types, 'proposed')
    end

    def encounter_start_or_discharge_context_check(context, hook_name)
      hook_user_type_check(context, hook_name)
      id_only_fields_check(hook_name, context, ['patientId', 'encounterId'])
    end

    def order_select_or_sign_context_check(context, hook_name)
      hook_user_type_check(context, hook_name)
      id_only_fields_check(hook_name, context, ['patientId'])

      draft_orders_bundle = parse_fhir_bundle_from_context('draftOrders', context)
      return if draft_orders_bundle.blank?

      expected_resource_types = [
        'DeviceRequest', 'MedicationRequest', 'NutritionOrder',
        'ServiceRequest', 'VisionPrescription'
      ]

      bundle_entries_check(context, 'draftOrders', draft_orders_bundle, expected_resource_types)

      return unless hook_name == 'order-select'

      order_refs = draft_orders_bundle.entry.map(&:resource).map do |resource|
        "#{resource.resourceType}/#{resource.id}"
      end
      context_selections_check(context, context['selections'], order_refs, expected_resource_types)
    end

    def order_dispatch_context_check(context)
      id_only_fields_check('order-dispatch', context, ['patientId'])
      order_supported_resource_type = [
        'DeviceRequest', 'MedicationRequest', 'NutritionOrder',
        'ServiceRequest', 'VisionPrescription'
      ]
      resource_reference_check(context['order'], 'order', supported_resource_types: order_supported_resource_type)
      resource_reference_check(context['performer'], 'performer')
    end

    def no_error_validation(message)
      assert messages.none? { |msg| msg[:type] == 'error' }, message
    end

    def valid_url?(url)
      uri = URI.parse(url)
      uri.host.present? && ['http', 'https'].include?(uri.scheme)
    rescue URI::InvalidURIError
      false
    end

    def query_and_validate_id_field(resource_type, resource_id)
      fhir_read(resource_type, resource_id)
      status = request.response[:status]
      unless status == 200
        add_message('error', "#{request_number}Unexpected response status: expected 200, but received #{status}")
        return
      end
      unless resource.resourceType == resource_type
        add_message('error', %(
          #{request_number}Unexpected resource type: Expected `#{resource_type}`. Got
          `#{resource.resourceType}`.
        ))
        return
      end
      unless resource.id == resource_id
        add_message('error', %(
          #{request_number}Requested resource with id #{resource_id}, received resource with id #{resource.id}
          ))
        return
      end

      profile_url = hook_name == 'order-dispatch' ? nil : structure_definition_map[resource_type]
      resource_is_valid?(profile_url:)
    end

    def context_validate_optional_fields(hook_context, hook_name)
      hook_optional_context_fields = context_optional_fields_by_hook[hook_name]
      return if hook_optional_context_fields.blank?

      hook_optional_context_fields.each do |field, type|
        validate_presence_and_type(hook_context, field, type, "#{hook_name} request context") if hook_context[field]
      end

      optional_field_keys = hook_optional_context_fields.keys
      if optional_field_keys.include?('encounterId') && hook_context['encounterId'].present?
        id_only_fields_check(hook_name, hook_context, ['encounterId'])
      end

      validate_hash_fields(hook_context, optional_field_keys)
    end

    def validate_hash_fields(hook_context, hook_optional_context_fields)
      hash_context_fields = hook_context.select do |field, value|
        value.is_a?(Hash) && hook_optional_context_fields.include?(field)
      end

      return if hash_context_fields.empty?

      hash_context_fields.each do |field, entry|
        resource_json = entry.to_json
        fhir_resource = FHIR.from_contents(resource_json)
        if fhir_resource.blank?
          add_message('error', "#{request_number}Field `#{field}` is not a FHIR resource.")
          next
        end
        resource_type = optional_field_resource_types[field]
        unless fhir_resource.resourceType == resource_type
          add_message('error', %(
            #{request_number}Field `#{field}` must be a `#{resource_type}`. Got
            `#{fhir_resource.resourceType}`.
          ))
          next
        end
        resource_is_valid?(resource: fhir_resource)
      end
    end

    def hook_request_prefetch_check(advertised_prefetch_fields, received_prefetch, received_context)
      received_prefetch.each do |received_prefetch_key, received_prefetch_hash|
        unless advertised_prefetch_fields.key?(received_prefetch_key)
          add_message('error', "#{request_number}Client sent non-requested Prefetch field `#{received_prefetch_key}`.")
          next
        end

        unless received_prefetch_hash.is_a?(Hash)
          add_message('error', "#{request_number}Prefetch field `#{received_prefetch_key}` is not of type `Hash`.")
          next
        end

        received_prefetch_resource = FHIR.from_contents(received_prefetch[received_prefetch_key].to_json)
        advertised_prefetch_template = advertised_prefetch_fields[received_prefetch_key]
        if advertised_prefetch_template.include?('?')
          advertised_prefetch_fhir_search = advertised_prefetch_template.gsub(/{|}/, '').split('?')
          advertised_prefetch_resource_type = advertised_prefetch_fhir_search.first

          if advertised_prefetch_resource_type == 'Coverage'
            advertised_coverage_query_params = Rack::Utils.parse_nested_query(advertised_prefetch_fhir_search.last)

            advertised_patient_token = advertised_coverage_query_params['patient']
            advertised_context_patient_id_key = advertised_patient_token.split('.').last
            received_context_patient_id = received_context[advertised_context_patient_id_key]

            advertised_status_param = advertised_coverage_query_params['status']

            validate_prefetch_coverages(received_prefetch_resource, received_prefetch_key, received_context_patient_id,
                                        advertised_status_param)
          end
        else
          advertised_prefetch_token = advertised_prefetch_template.gsub(/{|}/, '').split('/')
          advertised_context_id = advertised_prefetch_token.last.split('.').last

          if advertised_prefetch_token.length == 1
            received_context_reference = FHIR::Reference.new(reference: received_context[advertised_context_id])
            received_context_resource_type = received_context_reference.resource_type
            received_context_id = received_context_reference.reference_id
          else
            received_context_id = received_context[advertised_context_id]
            received_context_resource_type = advertised_prefetch_token.first
          end
          validate_prefetch_resource(received_prefetch_resource, received_prefetch_key,
                                     received_context_resource_type, received_context_id)
        end
      end
    end

    def validate_prefetch_coverages(received_resource, advertised_prefetch_key,
                                    received_context_patient_id, advertised_status)
      unless received_resource.resourceType == 'Bundle'
        add_message('error', "#{request_number}Unexpected resource type: Expected `Bundle`. Got" \
                             "`#{received_resource.resourceType}`.")
        return
      end

      if received_resource.entry.empty?
        add_message('error', "#{request_number}Bundle of coverage resources received from prefetch is empty")
        return
      end

      if received_context_patient_id.blank?
        add_message('error',
                    "#{request_number}Cannot verify `coverage` patient id because no id provided in the context.")
      end

      received_resource.entry.each_with_index do |entry, index|
        validate_prefetch_coverage(entry&.resource, advertised_prefetch_key,
                                   received_context_patient_id, advertised_status, index)
      end
    end

    def validate_prefetch_coverage(coverage_resource, advertised_prefetch_key,
                                   received_context_patient_id, advertised_status, entry_index)
      unless coverage_resource.present?
        add_message('error', "#{request_number}Coverage Bundle entry #{entry_index + 1} had no resource")
        return
      end

      unless coverage_resource.resourceType == 'Coverage'
        add_message('error', "#{request_number}Coverage Bundle entry #{entry_index + 1} - Unexpected resource type: " \
                             "Expected `Coverage`. Got `#{coverage_resource.resourceType}`.")
        return
      end

      resource_is_valid?(resource: coverage_resource,
                         profile_url: structure_definition_map['Coverage'])

      coverage_beneficiary_reference = coverage_resource.beneficiary
      coverage_beneficiary_patient_id = coverage_beneficiary_reference.reference_id
      if coverage_beneficiary_patient_id.blank?
        add_message('error', "#{request_number}Coverage Bundle entry #{entry_index + 1} - Could not get beneficiary " \
                             "reference id from `#{advertised_prefetch_key}` field's Coverage resource")
        return
      end

      if received_context_patient_id.present? && coverage_beneficiary_patient_id != received_context_patient_id
        add_message('error', "#{request_number}Coverage Bundle entry #{entry_index + 1} - " \
                             "Expected `#{advertised_prefetch_key}` field's Coverage resource to have a `beneficiary`" \
                             "reference id of '#{received_context_patient_id}', " \
                             "instead was '#{coverage_beneficiary_patient_id}`")
        return
      end

      coverage_status = coverage_resource.status
      return unless coverage_status != advertised_status

      add_message('error', "#{request_number}Coverage Bundle entry #{entry_index + 1} - " \
                           "Expected `#{advertised_prefetch_key}` field's Coverage resource to have a `status` of" \
                           "'#{advertised_status}', instead was '#{coverage_status}'")
    end

    def validate_prefetch_resource(received_resource, advertised_prefetch_key, context_field_resource_type,
                                   context_field_id)

      return unless prefetch_resource_type_correct?(received_resource, context_field_resource_type,
                                                    "#{request_number}`#{advertised_prefetch_key}` - ")

      if hook_name == 'order-dispatch'
        resource_is_valid?(resource: received_resource)
      else
        resource_is_valid?(resource: received_resource,
                           profile_url: structure_definition_map[context_field_resource_type])
      end

      prefetch_resource_id_correct?(received_resource, context_field_id,
                                    "#{request_number}`#{advertised_prefetch_key}` - ")
    end

    def prefetch_resource_type_correct?(resource, expected_type, error_prefix)
      if expected_type.present?
        return true if resource.resourceType == expected_type

        add_message(:error, "#{error_prefix}Prefetched resource has the wrong resource type. " \
                            "Expected `#{expected_type}`, got `#{resource.resourceType}`.")
      else
        add_message(:error, "#{error_prefix}No resource type provided to verify prefetched resource against.")
      end
      false
    end

    def prefetch_resource_id_correct?(resource, expected_id, error_prefix)
      if expected_id.present?
        return true if resource.id == expected_id

        add_message(:error, "#{error_prefix}Prefetched resource has the wrong resource id. " \
                            "Expected `#{expected_id}`, got `#{resource.id}`.")
      else
        add_message(:error, "#{error_prefix}No resource id provided to verify prefetched resource against.")
      end
      false
    end
  end
end
