module DaVinciCRDTestKit
  # Serve responses to CRD hook invocations
  module MockServiceResponse
    def current_time
      Time.now.utc
    end

    def coverage_information_required_hooks
      ['appointment-book', 'order-dispatch', 'order-sign']
    end

    def get_card_json(filename)
      json = JSON.parse(File.read(File.join(__dir__, 'card_responses', filename)))
      return json unless filename == 'launch_smart_app.json'

      json['links'].first['url'] = "#{Inferno::Application['base_url']}/custom/smart/launch"

      json
    end

    def format_missing_response_types(missing_response_types)
      missing_response_types
        .map do |response_type|
        response_type_string =
          response_type.split('_')
            .map(&:capitalize)
            .join(' ')
            .sub('Smart', 'SMART')
            .sub('Create Update', 'Create/Update')
            .sub('Companions Prerequisites', 'Companions/Prerequisites')
        response_type_string
      end
    end

    def missing_response_type_filter(response_type, hook_card_response)
      if response_type == 'coverage information'
        hook_card_response['systemActions'].nil? ||
          hook_card_response['systemActions'].none? do |card|
            card['description'].include?('coverage information')
          end
      else
        hook_card_response['cards'].present? &&
          hook_card_response['cards'].none? { |card| card['summary'].downcase.include?(response_type) }
      end
    end

    def get_missing_response_types(selected_response_types, hook_card_response, hook_name)
      if coverage_information_required_hooks.include?(hook_name)
        selected_response_types.append('coverage_information').uniq!
      end

      selected_response_types
        .select do |response_type|
          response_type = response_type
            .split('_')
            .join(' ')
            .sub('create update', 'create/update')
            .sub('companions prerequisites', 'companions/prerequisites')
          missing_response_type_filter(response_type, hook_card_response)
        end
    end

    def create_warning_messages(selected_response_types, hook_card_response, hook_name)
      missing_response_types = if hook_card_response.nil?
                                 selected_response_types
                               else
                                 get_missing_response_types(selected_response_types, hook_card_response, hook_name)
                               end

      return if missing_response_types.empty?

      missing_response_types = format_missing_response_types(missing_response_types)
      missing_response_types.each do |missing_response_type|
        Inferno::Repositories::Messages.new.create(result_id: result.id, type: 'warning',
                                                   message: %(Unable to return response type: `#{missing_response_type}`
                                                   for #{hook_name} hook))
      end
    end

    def create_card_response(hook_card_response)
      if hook_card_response.nil?
        response.headers.merge!({ 'Access-Control-Allow-Origin' => '*' })
        response.status = 400
        response.body = 'Invalid Request: Incorrect format for hook request body'
      else
        response.body = hook_card_response.to_json
        response.headers.merge!({ 'Content-Type' => 'application/json', 'Access-Control-Allow-Origin' => '*' })
        response.status = 200
        response.format = :json
      end
    end

    def update_specific_hook_card_info(card_response, hook_name)
      return if card_response.nil?

      hook_display = hook_name.split('-').map(&:capitalize).join(' ')
      card_response['cards'].map do |card|
        card['summary'].prepend("#{hook_display} ")
        card['uuid'] = SecureRandom.uuid
      end
      card_response
    end

    def appointment_book_response(selected_response_types)
      cards_response = create_cards_and_system_actions(selected_response_types, 'appointment-book', 'appointments')
      hook_card_response = update_specific_hook_card_info(cards_response, 'appointment-book')
      create_warning_messages(selected_response_types, hook_card_response, 'appointment-book')
      create_card_response(hook_card_response)
    end

    def encounter_start_response(selected_response_types)
      cards_response = create_cards_and_system_actions(selected_response_types, 'encounter-start', 'encounterId',
                                                       'Encounter')
      hook_card_response = update_specific_hook_card_info(cards_response, 'encounter-start')
      create_warning_messages(selected_response_types, hook_card_response, 'encounter-start')
      create_card_response(hook_card_response)
    end

    def encounter_discharge_response(selected_response_types)
      cards_response = create_cards_and_system_actions(selected_response_types, 'encounter-discharge', 'encounterId',
                                                       'Encounter')
      hook_card_response = update_specific_hook_card_info(cards_response, 'encounter-discharge')
      create_warning_messages(selected_response_types, hook_card_response, 'encounter-discharge')
      create_card_response(hook_card_response)
    end

    def order_dispatch_response(selected_response_types)
      cards_response = create_cards_and_system_actions(selected_response_types, 'order-dispatch', 'order')
      hook_card_response = update_specific_hook_card_info(cards_response, 'order-dispatch')
      create_warning_messages(selected_response_types, hook_card_response, 'order-dispatch')
      create_card_response(hook_card_response)
    end

    def order_select_response(selected_response_types)
      cards_response = create_cards_and_system_actions(selected_response_types, 'order-select', 'draftOrders')
      hook_card_response = update_specific_hook_card_info(cards_response, 'order-select')
      create_warning_messages(selected_response_types, hook_card_response, 'order-select')
      create_card_response(hook_card_response)
    end

    def order_sign_response(selected_response_types)
      cards_response = create_cards_and_system_actions(selected_response_types, 'order-sign', 'draftOrders')
      hook_card_response = update_specific_hook_card_info(cards_response, 'order-sign')
      create_warning_messages(selected_response_types, hook_card_response, 'order-sign')
      create_card_response(hook_card_response)
    end

    def make_resource_request(uri, access_token)
      response = Faraday.get(uri, nil, { 'Authorization' => "Bearer #{access_token}" })
      return unless response.status == 200

      resource = FHIR.from_contents(response.body)
      return resource unless resource.resourceType == 'Bundle'
      return if resource.entry.empty?

      resource.entry.first.resource
    end

    def get_patient_coverage(request_body)
      prefetch = request_body['prefetch']
      if prefetch.present? && prefetch['coverage']
        FHIR.from_contents(prefetch['coverage'].to_json)
      else
        fhir_server = request_body['fhirServer']
        if fhir_server.present?
          access_token = request_body['fhirAuthorization']['access_token'] if request_body['fhirAuthorization']
          patient_id = request_body['context']['patientId']

          make_resource_request(
            "#{fhir_server}/Coverage?patient=#{patient_id}&status=active",
            access_token
          )
        end
      end
    end

    def get_context_resource(request_body, resource_type, update_resource_id)
      update_resource_id = "#{resource_type}/#{update_resource_id}" unless update_resource_id.include? '/'
      fhir_server = request_body['fhirServer']
      return if fhir_server.blank?

      access_token = request_body['fhirAuthorization']['access_token'] if request_body['fhirAuthorization']
      make_resource_request(
        "#{fhir_server}/#{update_resource_id}",
        access_token
      )
    end

    def add_coverage_cards?(selected_response_types, hook_name)
      (['coverage_information', 'create_update_coverage_info'].any? { |x| selected_response_types.include?(x) }) ||
        coverage_information_required_hooks.include?(hook_name)
    end

    def create_cards_and_system_actions(selected_response_types, hook_name, update_resource_name, resource_type = nil)
      request_body = JSON.parse(request.params.to_json)
      context = request_body['context']
      return if context.nil?

      cards = []

      add_basic_cards(selected_response_types, cards, context)

      add_order_hook_cards(selected_response_types, cards, request_body, hook_name)

      system_actions = add_coverage_cards(selected_response_types, cards, request_body, hook_name,
                                          update_resource_name, resource_type)

      cards.append(get_card_json('instructions.json')) if selected_response_types.include?('instructions') ||
                                                          (cards.empty? && system_actions.nil?)
      cards_response = { 'cards' => cards }
      cards_response['systemActions'] = system_actions if system_actions.present?
      cards_response
    rescue StandardError
      nil
    end

    def add_order_hook_cards(selected_response_types, cards, request_body, hook_name)
      if selected_response_types.include?('companions_prerequisites')
        cards.append(create_companions_prerequisites_card(request_body['context']))
      end

      return unless selected_response_types.include?('propose_alternate_request')

      cards.append(create_alternate_request_card(request_body, hook_name))
    end

    def add_basic_cards(selected_response_types, cards, context)
      cards.append(create_form_completion_card(context)) if selected_response_types.include?('request_form_completion')
      cards.append(get_card_json('launch_smart_app.json')) if selected_response_types.include?('launch_smart_app')
      cards.append(get_card_json('external_reference.json')) if selected_response_types.include?('external_reference')
    end

    def add_coverage_cards(selected_response_types, cards, request_body, hook_name, update_resource_name,
                           resource_type = nil)
      return unless add_coverage_cards?(selected_response_types, hook_name)

      coverage = get_patient_coverage(request_body)
      if coverage.present?
        if selected_response_types.include?('coverage_information') ||
           coverage_information_required_hooks.include?(hook_name)
          system_actions = create_coverage_extension_system_actions(request_body, update_resource_name,
                                                                    coverage.id, resource_type)
        end

        if selected_response_types.include?('create_update_coverage_info')
          cards.append(create_or_update_coverage(coverage, request_body['context']))
        end
      end
      system_actions
    end

    def create_coverage_extension_system_actions(request_body, update_resource_name, coverage_id, resource_type = nil)
      context = request_body['context']
      update_resource = context[update_resource_name]
      prefetch_id = update_resource_name.split(/(?=[A-Z])/).first

      fhir_resource = if update_resource.is_a? Hash
                        FHIR.from_contents(update_resource.to_json)
                      elsif request_body['prefetch'] && request_body['prefetch'][prefetch_id]
                        FHIR.from_contents(request_body['prefetch'][prefetch_id].to_json)
                      else
                        get_context_resource(request_body, resource_type, update_resource)
                      end
      create_system_actions(fhir_resource, coverage_id)
    rescue StandardError
      nil
    end

    def create_system_actions(resource, coverage_id)
      return if resource.nil?

      system_actions = []
      if resource.resourceType == 'Bundle'
        resource.entry.each do |entry|
          entry_resource = entry.resource
          add_coverage_extension(entry_resource, coverage_id)
          system_actions.append({ 'type' => 'update',
                                  'description' =>
                                  "Added coverage information to #{entry_resource.resourceType} resource.",
                                  'resource' => entry_resource })
        end
      else
        add_coverage_extension(resource, coverage_id)
        system_actions.append({ 'type' => 'update',
                                'description' => "Added coverage information to #{resource.resourceType} resource.",
                                'resource' => resource })
      end
      system_actions
    end

    def add_coverage_extension(resource, coverage_id)
      resource.extension = [
        FHIR::Extension.new(
          url: 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/ext-coverage-information',
          extension: [
            FHIR::Extension.new(
              url: 'coverage',
              valueReference: FHIR::Reference.new(
                reference: "Coverage/#{coverage_id}"
              )
            ),
            FHIR::Extension.new(
              url: 'covered',
              valueCode: 'covered'
            ),
            FHIR::Extension.new(
              url: 'pa-needed',
              valueCode: 'no-auth'
            ),
            FHIR::Extension.new(
              url: 'date',
              valueDate: current_time.strftime('%Y-%m-%d')
            ),
            FHIR::Extension.new(
              url: 'coverage-assertion-id',
              valueString: SecureRandom.hex(32)
            )
          ]
        )
      ]
    end

    def create_coverage_resource(patient_id)
      FHIR::Coverage.new(
        id: SecureRandom.uuid,
        status: 'draft',
        beneficiary: FHIR::Reference.new(
          reference: "Patient/#{patient_id}"
        ),
        subscriber: FHIR::Reference.new(
          reference: "Patient/#{patient_id}"
        ),
        relationship: FHIR::CodeableConcept.new(
          coding: [
            FHIR::Coding.new(
              system: 'http://terminology.hl7.org/CodeSystem/subscriber-relationship',
              code: 'self'
            )
          ]
        ),
        payor: FHIR::Reference.new(
          reference: "Patient/#{patient_id}"
        )
      )
    end

    def create_or_update_coverage(coverage, context)
      return if context.nil?

      if coverage.present?
        action = { 'type' => 'update', 'description' => 'Update current coverage record' }
        coverage.period = FHIR::Period.new(start: current_time.strftime('%Y-%m-%d'),
                                           end: (current_time + 1.month).strftime('%Y-%m-%d'))
        action['resource'] = coverage
      else
        action = { 'type' => 'create', 'description' => 'Create coverage record' }
        new_coverage = create_coverage_resource(context['patientId'])
        action['resource'] = new_coverage
      end
      coverage_info_card = get_card_json('create_update_coverage_information.json')
      coverage_info_card['suggestions'][0]['actions'] = [action]
      coverage_info_card
    end

    def create_form_completion_card(context)
      return if context.nil?

      request_form_completion_card = get_card_json('request_form_completion.json')
      form_completion_task = request_form_completion_card['suggestions'][0]['actions'].find do |action|
        action['resource']['resourceType'] == 'Task'
      end['resource']

      form_completion_task['for']['reference'] = "Patient/#{context['patientId']}"
      form_completion_task['authoredOn'] = current_time.strftime('%Y-%m-%d')
      request_form_completion_card
    end

    def update_service_request(service_request, context)
      return if context.nil?

      service_request['subject']['reference'] = "Patient/#{context['patientId']}"
      service_request['requester']['reference'] = context['userId']
      service_request['authoredOn'] = current_time.strftime('%Y-%m-%d')
    end

    def create_companions_prerequisites_card(context)
      return if context.nil?

      companions_prerequisites_card = get_card_json('companions_prerequisites.json')
      card_service_request = companions_prerequisites_card['suggestions'][0]['actions'][0]['resource']
      update_service_request(card_service_request, context)
      companions_prerequisites_card
    end

    def create_alternate_request_card(request_body, hook_name)
      context = request_body['context']
      return if context.nil?

      propose_alternate_request_card = get_card_json('propose_alternate_request.json')

      if hook_name == 'order-dispatch'
        order_resource = get_context_resource(request_body, nil, context['order'])
      else
        draft_orders = context['draftOrders']['entry']
        draft_order_resource = draft_orders[0]['resource']
        order_resource = FHIR.from_contents(draft_order_resource.to_json)
      end
      return if order_resource.nil?

      order_resource_type = order_resource.resourceType
      order_resource_id = order_resource.id

      card_actions = propose_alternate_request_card['suggestions'][0]['actions']
      card_actions.push(
        {
          'type' => 'delete',
          'description' => 'Remove current order until health assessment has been done',
          'resourceId' => ["#{order_resource_type}/#{order_resource_id}"]
        },
        {
          'type' => 'create',
          'description' => 'Order for patient health assessment',
          'resource' => order_resource
        }
      )
      propose_alternate_request_card
    end
  end
end
