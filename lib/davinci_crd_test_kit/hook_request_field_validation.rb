module DaVinciCRDTestKit
  module HookRequestFieldValidation
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
        'Task' => 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-taskquestionnaire'
      }.freeze
    end

    def hook_request_required_fields_check(request_body, hook_name)
      hook_required_fields.each do |field, type|
        assert(request_body[field], "Hook request did not contain required field: `#{field}`")
        assert(request_body[field].is_a?(type), "Hook request field #{field} is not of type #{type}")
      end

      assert(request_body['hook'] == hook_name,
             "The `hook` field should be #{hook_name}, but was #{request_body['hook']}")

      return unless request_body['fhirAuthorization']

      assert(request_body['fhirServer'],
             'Missing `fhirServer` field: If `fhirAuthorization` is provided, this field is REQUIRED.')
    end

    def hook_request_fhir_auth_check(request_body)
      if request_body['fhirAuthorization']

        fhir_authorization = request_body['fhirAuthorization']

        fhir_authorization_required_fields.each do |field, type|
          assert(fhir_authorization[field], "`fhirAuthorization` did not contain required field: `#{field}`")
          assert(fhir_authorization[field].is_a?(type), "`fhirAuthorization` field #{field} is not of type #{type}")
        end

        assert(fhir_authorization['token_type'] == 'Bearer',
               "`fhirAuthorization` `token_type` field is not set to 'Bearer'")

        access_token = fhir_authorization['access_token']

        scopes = fhir_authorization['scope'].split

        if scopes.any? { |scope| scope.start_with?('patient/') }
          info do
            assert(fhir_authorization['patient'] && fhir_authorization['patient'].is_a?(String),
                   %(The `patient` field SHOULD be populated to identify the FHIR id of that patient when the granted
                    SMART scopes include patient scopes))
          end
        end
      end
      { fhir_server_uri: request_body['fhirServer'], fhir_access_token: access_token }
    end

    def hook_request_optional_fields_check(request_body)
      hook_optional_fields.each do |field, type|
        info do
          assert(request_body[field], "Hook request did not contain optional field: `#{field}`")
        end
        if request_body[field]
          assert(request_body[field].is_a?(type), "Hook request field #{field} is not of type #{type}")
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
        validate_presence_and_type(context, field, type, "#{hook_name} request context")
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
        error_msg = "Unsupported resource type: `#{field_name}` type should be one " \
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

      add_message('error', "Invalid `#{field_name}` format. Expected `{resourceType}/{id}`, received `#{reference}`.")
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
        error_msg = "`#{field}` in #{hook_name} context should be a plain ID, not a reference. Got: `#{resource_id}`."
        add_message('error', error_msg)
        false
      end
      true
    end

    def bundle_entries_check(context, context_field_name, bundle, resource_types, status = nil)
      target_resources = bundle.entry.map(&:resource).select { |r| resource_types.include?(r.resourceType) }
      unless target_resources.present?
        error_msg = "`#{context_field_name}` bundle must contain at least one of the expected resource types: " \
                    "#{resource_types.to_sentence}. In Context `#{context}`"
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

      error_msg = "All #{resources.map(&:resourceType).uniq.to_sentence} resources in `#{context_field_name}` " \
                  "bundle must have a `#{status}` status. In Context `#{context}`"
      add_message('error', error_msg)
    end

    def parse_fhir_bundle_from_context(context_field_name, context)
      fhir_bundle = FHIR.from_contents(context[context_field_name].to_json)
      unless fhir_bundle
        error_msg = "`#{context_field_name}` field is not a FHIR resource: `#{context[context_field_name]}`. " \
                    "In Context `#{context}`"
        add_message('error', error_msg)
        return
      end

      return fhir_bundle if fhir_bundle.is_a?(FHIR::Bundle)

      error_msg = "Wrong context resource type: Expected `Bundle`, got `#{fhir_bundle.resourceType}`. " \
                  "In Context `#{context}`"
      add_message('error', error_msg)
      nil
    end

    def context_selections_check(context, selections, order_refs, expected_resource_types)
      return unless selections.is_a?(Array)

      selections.each do |reference|
        resource_reference_check(reference, 'selections item', supported_resource_types: expected_resource_types)
        next if order_refs.include?(reference)

        error_msg = '`selections` field must reference FHIR resources in `draftOrders`. ' \
                    "#{reference} is not in `draftOrders`. In Context `#{context}`"
        add_message('error', error_msg)
      end
    end

    def appointment_book_context_check(context)
      hook_user_type_check(context, 'appointment-book')
      id_only_fields_check('appointment-book', context, ['patientId'])

      appointment_bundle = parse_fhir_bundle_from_context('appointments', context)
      return unless appointment_bundle

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
      return unless draft_orders_bundle

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
        add_message('error', "Unexpected response status: expected 200, but received #{status}")
        return
      end
      unless resource.resourceType == resource_type
        add_message('error', "Unexpected resource type: Expected `#{resource_type}`. Got `#{resource.resourceType}`.")
        return
      end
      unless resource.id == resource_id
        add_message('error', "Requested resource with id #{resource_id}, received resource with id #{resource.id}")
        return
      end

      profile_url = hook_name == 'order-dispatch' ? nil : structure_definition_map[resource_type]
      resource_is_valid?(profile_url:)
    end

    def context_validate_optional_fields(hook_context, hook_name)
      hook_optional_context_fields = context_optional_fields_by_hook[hook_name]
      return unless hook_optional_context_fields.present?

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
        unless fhir_resource
          add_message('error', "Field `#{field}` is not a FHIR resource.")
          next
        end
        resource_type = optional_field_resource_types[field]
        unless fhir_resource.resourceType == resource_type
          add_message('error', "Field `#{field}` must be a `#{resource_type}`. Got `#{fhir_resource.resourceType}`.")
          next
        end
        resource_is_valid?(resource: fhir_resource)
      end
    end
  end
end
