require_relative '../../../../lib/davinci_crd_test_kit/cross_suite/tags'

RSpec.describe DaVinciCRDTestKit::MockServiceResponse do
  describe 'v201' do
    let(:mocked_response_creator_v201) do
      Class.new do
        include DaVinciCRDTestKit::MockServiceResponse

        def ig_version
          'v201'
        end

        def selected_response_types
          @selected_response_types ||= [
            'request_form_completion'
          ]
        end

        def request_body
          @request_body ||=
            JSON.parse(File.read(File.join(__dir__, '..', '..', '..', 'fixtures', 'order_sign_hook_request.json')))
              .merge({
                       'prefetch' => {
                         'coverage' =>
                          JSON.parse(File.read(File.join(__dir__, '..', '..', '..', 'fixtures',
                                                         'crd_coverage_example.json')))
                       }
                     })
        end

        def requested_hook
          DaVinciCRDTestKit::ORDER_SIGN_TAG
        end

        def result
          @result ||= Struct.new(:id).new('test-result-id')
        end
      end.new
    end

    it 'form completion task has two inputs' do
      response = mocked_response_creator_v201.build_mock_hook_response
      expect(response['cards'].size).to eq(1)
      task = response.dig('cards', 0, 'suggestions', 0, 'actions', 1, 'resource')
      expect(task).to be_present
      expect(task['resourceType']).to eq('Task')
      expect(task['input'].size).to eq(2)
    end

    it 'card source topic uses temp code system' do
      response = mocked_response_creator_v201.build_mock_hook_response
      source_system = response.dig('cards', 0, 'source', 'topic', 'system')
      expect(source_system).to eq('http://hl7.org/fhir/us/davinci-crd/CodeSystem/temp')
    end

    def make_v201_creator(types:, body:, hook: DaVinciCRDTestKit::ORDER_SIGN_TAG)
      rb = body
      Class.new do
        include DaVinciCRDTestKit::MockServiceResponse

        define_method(:ig_version) { 'v201' }
        define_method(:selected_response_types) { @selected_response_types ||= types.dup }
        define_method(:request_body) { @request_body ||= rb }
        define_method(:requested_hook) { hook }
        define_method(:result) { @result ||= Struct.new(:id).new('test-result-id') }
      end.new
    end

    it 'propose_alternate_request for order-dispatch uses context order reference to fetch from FHIR server' do
      coverage = JSON.parse(File.read(File.join(__dir__, '..', '..', '..', 'fixtures', 'crd_coverage_example.json')))
      service_request = FHIR::ServiceRequest.new(id: 'example')
      allow(Faraday).to receive(:get)
        .with('https://example/r4/ServiceRequest/example', nil, anything)
        .and_return(instance_double(Faraday::Response, status: 200, body: service_request.to_json))
      messages_double = instance_double(Inferno::Repositories::Messages)
      allow(messages_double).to receive(:create)
      allow(Inferno::Repositories::Messages).to receive(:new).and_return(messages_double)

      creator = make_v201_creator(
        types: ['propose_alternate_request'],
        hook: DaVinciCRDTestKit::ORDER_DISPATCH_TAG,
        body: {
          'fhirServer' => 'https://example/r4',
          'fhirAuthorization' => { 'access_token' => 'SAMPLE_TOKEN' },
          'context' => { 'patientId' => 'example', 'order' => 'ServiceRequest/example' },
          'prefetch' => { 'coverage' => coverage }
        }
      )
      response = creator.build_mock_hook_response
      actions = response.dig('cards', 0, 'suggestions', 0, 'actions')
      expect(actions[0]['type']).to eq('delete')
      expect(actions[0]['resourceId']).to eq('ServiceRequest/example')
      expect(actions[1]['type']).to eq('create')
    end
  end

  describe 'v221' do
    let(:mocked_response_creator_v221) do
      Class.new do
        include DaVinciCRDTestKit::MockServiceResponse

        def ig_version
          'v221'
        end

        def selected_response_types
          @selected_response_types ||= [
            'request_form_completion'
          ]
        end

        def request_body
          @request_body ||=
            JSON.parse(File.read(File.join(__dir__, '..', '..', '..', 'fixtures', 'order_sign_hook_request.json')))
              .merge({
                       'prefetch' => {
                         'coverage' =>
                          JSON.parse(File.read(File.join(__dir__, '..', '..', '..', 'fixtures',
                                                         'crd_coverage_example.json')))
                       }
                     })
        end

        def requested_hook
          DaVinciCRDTestKit::ORDER_SIGN_TAG
        end

        def result
          @result ||= Struct.new(:id).new('test-result-id')
        end
      end.new
    end

    let(:mocked_response_creator_v221_order_dispatch) do
      Class.new do
        include DaVinciCRDTestKit::MockServiceResponse
        include DaVinciCRDTestKit::CardsIdentification

        def ig_version
          'v221'
        end

        def selected_response_types
          @selected_response_types ||= [
            'create_update_coverage_info'
          ]
        end

        def request_body
          @request_body ||=
            JSON.parse(File.read(File.join(__dir__, '..', '..', '..', '..', 'execution_scripts', 'prefetch',
                                           'order-dispatch-request_complete-prefetch.json')))
        end

        def requested_hook
          DaVinciCRDTestKit::ORDER_DISPATCH_TAG
        end

        def result
          @result ||= Struct.new(:id).new('test-result-id')
        end
      end.new
    end

    let(:order_sign_request_with_coverage) do
      JSON.parse(File.read(File.join(__dir__, '..', '..', '..', 'fixtures', 'order_sign_hook_request.json')))
        .merge({
                 'prefetch' => {
                   'coverage' =>
                    JSON.parse(File.read(File.join(__dir__, '..', '..', '..', 'fixtures', 'crd_coverage_example.json')))
                 }
               })
    end

    it 'form completion task has two inputs' do
      response = mocked_response_creator_v221.build_mock_hook_response
      expect(response['cards'].size).to eq(1)
      task = response.dig('cards', 0, 'suggestions', 0, 'actions', 1, 'resource')
      expect(task).to be_present
      expect(task['resourceType']).to eq('Task')
      expect(task['input'].size).to eq(1)
    end

    it 'form completion questionnaire version is a string' do
      response = mocked_response_creator_v221.build_mock_hook_response
      questionnaire = response.dig('cards', 0, 'suggestions', 0, 'actions', 0, 'resource')

      expect(questionnaire['resourceType']).to eq('Questionnaire')
      expect(questionnaire['version']).to eq('2')
    end

    it 'card source topic uses cdshooks code system instead of temp' do
      response = mocked_response_creator_v221.build_mock_hook_response
      source_system = response.dig('cards', 0, 'source', 'topic', 'system')
      expect(source_system).to eq('http://terminology.hl7.org/CodeSystem/cdshooks-card-type')
    end

    it 'order dispatch returns create/update coverage card' do
      response = mocked_response_creator_v221_order_dispatch.build_mock_hook_response
      expect(response['cards'].size).to eq(1)
      expect(response.dig('cards', 0, 'summary')).to include('Create/Update Coverage Information')
    end

    it 'order dispatch returns coverage-information system action' do
      response = mocked_response_creator_v221_order_dispatch.build_mock_hook_response
      system_actions = response['systemActions']
      expect(system_actions).to be_present
      expect(system_actions.size).to eq(13)
      expect(system_actions.first['description']).to include('coverage information')
    end

    it 'order dispatch coverage-information system action targets the dispatched order' do
      response = mocked_response_creator_v221_order_dispatch.build_mock_hook_response
      action_resource = response.dig('systemActions', 0, 'resource')
      expect(action_resource).to be_present
      expect(action_resource.resourceType).to eq('CommunicationRequest')
      coverage_ext = action_resource.extension&.find do |ext|
        ext.url == 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/ext-coverage-information'
      end
      expect(coverage_ext).to be_present
    end

    def make_v221_creator(types:, body:, hook: DaVinciCRDTestKit::ORDER_SIGN_TAG)
      rb = body
      Class.new do
        include DaVinciCRDTestKit::MockServiceResponse

        define_method(:ig_version) { 'v221' }
        define_method(:selected_response_types) { @selected_response_types ||= types.dup }
        define_method(:request_body) { @request_body ||= rb }
        define_method(:requested_hook) { hook }
        define_method(:result) { @result ||= Struct.new(:id).new('test-result-id') }
      end.new
    end

    it 'external_reference returns a card with the correct summary' do
      creator = make_v221_creator(types: ['external_reference'], body: order_sign_request_with_coverage)
      response = creator.build_mock_hook_response
      expect(response['cards'].size).to eq(1)
      expect(response.dig('cards', 0, 'summary')).to include('External Reference')
    end

    it 'launch_smart_app card link URL is set to the Inferno smart launch URL' do
      creator = make_v221_creator(types: ['launch_smart_app'], body: order_sign_request_with_coverage)
      response = creator.build_mock_hook_response
      launch_url = response.dig('cards', 0, 'links', 0, 'url')
      expect(launch_url).to eq("#{Inferno::Application['base_url']}/custom/smart/launch")
    end

    it 'companions_prerequisites card populates service request subject and requester from context' do
      creator = make_v221_creator(types: ['companions_prerequisites'], body: order_sign_request_with_coverage)
      response = creator.build_mock_hook_response
      service_request = response.dig('cards', 0, 'suggestions', 0, 'actions', 0, 'resource')
      expect(service_request['subject']['reference']).to eq('Patient/example')
      expect(service_request['requester']['reference']).to eq('Practitioner/example')
    end

    it 'companions_prerequisites card uses performer as requester for order-dispatch v221' do
      order_dispatch_body = JSON.parse(File.read(
                                         File.join(__dir__, '..', '..', '..', '..', 'execution_scripts', 'prefetch',
                                                   'order-dispatch-request_complete-prefetch.json')
                                       )).deep_merge('context' => { 'performer' => 'Practitioner/the-performer' })
      creator = make_v221_creator(types: ['companions_prerequisites'], body: order_dispatch_body,
                                  hook: DaVinciCRDTestKit::ORDER_DISPATCH_TAG)
      response = creator.build_mock_hook_response
      service_request = response.dig('cards', 0, 'suggestions', 0, 'actions', 0, 'resource')
      expect(service_request['subject']['reference']).to eq('Patient/forprefetch')
      expect(service_request['requester']['reference']).to eq('Practitioner/the-performer')
    end

    it 'propose_alternate_request appends delete and create actions for order-sign' do
      creator = make_v221_creator(types: ['propose_alternate_request'], body: order_sign_request_with_coverage)
      response = creator.build_mock_hook_response
      actions = response.dig('cards', 0, 'suggestions', 0, 'actions')
      expect(actions.size).to eq(2)
      expect(actions[0]['type']).to eq('delete')
      expect(actions[0]['resourceId']).to eq('NutritionOrder/pureeddiet-simple')
      expect(actions[1]['type']).to eq('create')
      expect(actions[1]['resource'].resourceType).to eq('NutritionOrder')
    end

    it 'multiple selected response types produce multiple cards' do
      creator = make_v221_creator(
        types: ['external_reference', 'request_form_completion'],
        body: order_sign_request_with_coverage
      )
      response = creator.build_mock_hook_response
      expect(response['cards'].size).to eq(2)
    end

    it 'hook display name is prepended to each card summary' do
      creator = make_v221_creator(types: ['external_reference'], body: order_sign_request_with_coverage)
      response = creator.build_mock_hook_response
      expect(response.dig('cards', 0, 'summary')).to start_with('Order Sign ')
    end

    it 'coverage_information system action created for each draftOrder entry in order-sign' do
      creator = make_v221_creator(types: ['coverage_information'], body: order_sign_request_with_coverage)
      response = creator.build_mock_hook_response
      system_actions = response['systemActions']
      expect(system_actions).to be_present
      expect(system_actions.size).to eq(2)
      expect(system_actions.all? { |a| a['description'].include?('coverage information') }).to be true
    end

    it 'coverage_information system action built from encounter prefetch for encounter-start hook' do
      request = JSON.parse(File.read(File.join(__dir__, '..', '..', '..', 'fixtures',
                                               'encounter_start_hook_request.json')))
        .merge({
                 'prefetch' => {
                   'coverage' =>
                    JSON.parse(File.read(File.join(__dir__, '..', '..', '..', 'fixtures',
                                                   'crd_coverage_example.json'))),
                   'encounter' =>
                    JSON.parse(File.read(File.join(__dir__, '..', '..', '..', 'fixtures',
                                                   'crd_encounter_example.json')))
                 }
               })
      creator = make_v221_creator(
        types: ['coverage_information'],
        hook: DaVinciCRDTestKit::ENCOUNTER_START_TAG,
        body: request
      )
      response = creator.build_mock_hook_response
      system_actions = response['systemActions']
      expect(system_actions).to be_present
      expect(system_actions.size).to eq(1)
      expect(system_actions.first['resource'].resourceType).to eq('Encounter')
    end

    it 'instructions card returned as fallback when no cards or system actions would otherwise be produced' do
      request = JSON.parse(
        File.read(File.join(__dir__, '..', '..', '..', 'fixtures', 'encounter_discharge_hook_request.json'))
      )
      creator = make_v221_creator(
        types: [],
        hook: DaVinciCRDTestKit::ENCOUNTER_DISCHARGE_TAG,
        body: request
      )
      response = creator.build_mock_hook_response
      expect(response['cards'].size).to eq(1)
      expect(response.dig('cards', 0, 'summary')).to include('Instructions')
    end

    it 'dispatched order not found in prefetch is fetched from FHIR server' do
      coverage = JSON.parse(File.read(File.join(__dir__, '..', '..', '..', 'fixtures', 'crd_coverage_example.json')))
      service_request = FHIR::ServiceRequest.new(id: 'example')
      allow(Faraday).to receive(:get)
        .with('https://example/r4/ServiceRequest/example', nil, anything)
        .and_return(instance_double(Faraday::Response, status: 200, body: service_request.to_json))

      creator = make_v221_creator(
        types: [],
        hook: DaVinciCRDTestKit::ORDER_DISPATCH_TAG,
        body: {
          'fhirServer' => 'https://example/r4',
          'fhirAuthorization' => { 'access_token' => 'SAMPLE_TOKEN' },
          'context' => { 'patientId' => 'example', 'dispatchedOrders' => ['ServiceRequest/example'] },
          'prefetch' => { 'coverage' => coverage }
        }
      )
      response = creator.build_mock_hook_response
      system_actions = response['systemActions']
      expect(system_actions).to be_present
      expect(system_actions.first['resource'].resourceType).to eq('ServiceRequest')
    end

    it 'get_context_resource returns nil for a blank resource ID' do
      creator = make_v221_creator(types: [], body: order_sign_request_with_coverage)
      expect(creator.get_context_resource(nil)).to be_nil
      expect(creator.get_context_resource('')).to be_nil
    end

    it 'get_context_resource returns nil when fhirServer is absent from request body' do
      creator = make_v221_creator(types: [], body: { 'context' => { 'patientId' => 'example' } })
      expect(creator.get_context_resource('ServiceRequest/example')).to be_nil
    end

    it 'get_context_resource prepends encounter resource type to bare ID before fetching' do
      coverage = JSON.parse(File.read(File.join(__dir__, '..', '..', '..', 'fixtures', 'crd_coverage_example.json')))
      encounter = FHIR::Encounter.new(id: 'example')
      allow(Faraday).to receive(:get)
        .with('https://example/r4/Encounter/example', nil, anything)
        .and_return(instance_double(Faraday::Response, status: 200, body: encounter.to_json))

      creator = make_v221_creator(
        types: ['coverage_information'],
        hook: DaVinciCRDTestKit::ENCOUNTER_START_TAG,
        body: {
          'fhirServer' => 'https://example/r4',
          'fhirAuthorization' => { 'access_token' => 'SAMPLE_TOKEN' },
          'context' => { 'userId' => 'Practitioner/example', 'patientId' => 'example', 'encounterId' => 'example' },
          'prefetch' => { 'coverage' => coverage }
        }
      )
      response = creator.build_mock_hook_response
      expect(response['systemActions']).to be_present
      expect(response.dig('systemActions', 0, 'resource').resourceType).to eq('Encounter')
    end

    it 'creates a warning when required coverage_information cannot be returned' do
      creator = make_v221_creator(
        types: [],
        body: {
          'context' => {
            'userId' => 'Practitioner/example',
            'patientId' => 'example',
            'draftOrders' => { 'resourceType' => 'Bundle', 'entry' => [] }
          }
        }
      )
      messages_double = instance_double(Inferno::Repositories::Messages)
      allow(messages_double).to receive(:create)
      allow(Inferno::Repositories::Messages).to receive(:new).and_return(messages_double)

      creator.build_mock_hook_response

      expect(messages_double).to have_received(:create).with(
        hash_including(
          type: 'warning',
          message: include('Coverage Information')
        )
      )
    end

    it 'form completion questionnaire if-none-exist includes the fhirServer URL' do
      creator = make_v221_creator(types: ['request_form_completion'], body: order_sign_request_with_coverage)
      response = creator.build_mock_hook_response
      questionnaire_action = response.dig('cards', 0, 'suggestions', 0, 'actions').find do |a|
        a.dig('resource', 'resourceType') == 'Questionnaire'
      end
      if_none_exist = questionnaire_action.dig('extension', 'davinci-crd.if-none-exist')
      expect(if_none_exist).to include('https://example/r4/Questionnaire')
      expect(if_none_exist).to_not include('<target_fhir_server>')
    end

    it 'form completion questionnaire if-none-exist uses empty string when fhirServer is absent' do
      body = { 'context' => { 'userId' => 'Practitioner/example', 'patientId' => 'example' } }
      messages_double = instance_double(Inferno::Repositories::Messages)
      allow(messages_double).to receive(:create)
      allow(Inferno::Repositories::Messages).to receive(:new).and_return(messages_double)

      creator = make_v221_creator(types: ['request_form_completion'], body: body)
      response = creator.build_mock_hook_response
      questionnaire_action = response.dig('cards', 0, 'suggestions', 0, 'actions').find do |a|
        a.dig('resource', 'resourceType') == 'Questionnaire'
      end
      if_none_exist = questionnaire_action.dig('extension', 'davinci-crd.if-none-exist')
      expect(if_none_exist).to_not include('<target_fhir_server>')
      expect(if_none_exist).to start_with('url=/')
    end

    it 'form completion task for reference is set from patientId' do
      creator = make_v221_creator(types: ['request_form_completion'], body: order_sign_request_with_coverage)
      response = creator.build_mock_hook_response
      task = response.dig('cards', 0, 'suggestions', 0, 'actions').find do |a|
        a.dig('resource', 'resourceType') == 'Task'
      end['resource']
      expect(task['for']['reference']).to eq('Patient/example')
    end

    it 'form completion task id is a generated UUID' do
      creator = make_v221_creator(types: ['request_form_completion'], body: order_sign_request_with_coverage)
      response = creator.build_mock_hook_response
      task = response.dig('cards', 0, 'suggestions', 0, 'actions').find do |a|
        a.dig('resource', 'resourceType') == 'Task'
      end['resource']
      expect(task['id']).to match(/\A[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}\z/i)
    end

    it 'form completion task requester is set from coverage payor reference' do
      creator = make_v221_creator(types: ['request_form_completion'], body: order_sign_request_with_coverage)
      response = creator.build_mock_hook_response
      task = response.dig('cards', 0, 'suggestions', 0, 'actions').find do |a|
        a.dig('resource', 'resourceType') == 'Task'
      end['resource']
      expect(task['requester']['reference']).to eq('http://example.org/fhir/Organization/example-payer')
    end

    it 'form completion task requester is removed when no coverage is available' do
      body = { 'context' => { 'userId' => 'Practitioner/example', 'patientId' => 'example' } }
      messages_double = instance_double(Inferno::Repositories::Messages)
      allow(messages_double).to receive(:create)
      allow(Inferno::Repositories::Messages).to receive(:new).and_return(messages_double)

      creator = make_v221_creator(types: ['request_form_completion'], body: body)
      response = creator.build_mock_hook_response
      task = response.dig('cards', 0, 'suggestions', 0, 'actions').find do |a|
        a.dig('resource', 'resourceType') == 'Task'
      end['resource']
      expect(task).to_not have_key('requester')
    end
  end
end
