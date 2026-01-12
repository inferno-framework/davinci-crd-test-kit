require_relative '../../lib/davinci_crd_test_kit/client_tests/order_sign_receive_request_test'

RSpec.describe DaVinciCRDTestKit::CustomServiceResponse, :request do
  let(:suite_id) { 'crd_client' }
  let(:test) { DaVinciCRDTestKit::OrderSignReceiveRequestTest }

  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:jwt_helper) { Class.new(DaVinciCRDTestKit::JwtHelper) }

  let(:example_client_url) { 'https://cds.example.org' }
  let(:fhirpath_url) { 'https://example.com/fhirpath/evaluate' }
  let(:fhirpath_false_response_body) { [{ type: 'boolean', element: false }] }
  let(:fhirpath_true_response_body) { [{ type: 'boolean', element: true }] }
  let(:base_url) { "#{Inferno::Application['base_url']}/custom/crd_client" }
  let(:order_sign_url) { "#{base_url}/cds-services/order-sign-service" }
  let(:client_fhir_server) { 'https://example/r4' }

  let(:server_endpoint) { '/custom/crd_client/cds-services/order-sign-service' }
  let(:body) do
    JSON.parse(File.read(File.join(
                           __dir__, '..', 'fixtures', 'order_sign_hook_request.json'
                         )))
  end

  let(:crd_coverage) do
    JSON.parse(File.read(File.join(
                           __dir__, '..', 'fixtures', 'crd_coverage_example.json'
                         )))
  end
  let(:crd_coverage_bundle) do
    bundle = FHIR::Bundle.new(type: 'searchset')
    bundle.entry.append(FHIR::Bundle::Entry.new(
                          fullUrl: 'https://example.com/base/Coverage/coverage_example',
                          resource: FHIR.from_contents(crd_coverage.to_json)
                        ))
    bundle
  end
  let(:instructions_card_template) do
    JSON.parse(File.read(File.join(
                           __dir__, '..', '..', 'lib', 'davinci_crd_test_kit', 'card_responses', 'instructions.json'
                         )))
  end
  let(:suggestions_card_template) do
    JSON.parse(
      File.read(File.join(
                  __dir__, '..', '..', 'lib', 'davinci_crd_test_kit', 'card_responses', 'propose_alternate_request.json'
                ))
    )
  end
  let(:system_action_template_static) do
    { type: 'delete', description: 'delete the patient!', resourceId: 'Patient/example' }
  end
  let(:system_action_template_delete_with_tokens) do
    { type: 'delete', description: 'delete the patient!', resourceId: 'Patient/{{context.patientId}}' }
  end
  let(:system_action_template_update_extension_with_tokens) do
    { type: 'update', description: 'add extension',
      resource: { id: 'overrideId', extension: [{ url: 'added_hookInstance', valueString: '{{hookInstance}}' }] } }
  end
  let(:system_action_template_update_extension_default) do
    { type: 'update', description: 'add extension (Default)',
      resource: { id: 'overrideId', extension: [{ url: 'added_hookInstance', valueString: '{{hookInstance}}' }] } }
  end

  let(:sytem_action_update_coverage_information_no_defaults) do
    { type: 'update', description: 'add coverage-information extension',
      resource: {
        extension: [{
          url: 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/ext-coverage-information',
          extension: [
            {
              url: 'coverage',
              valueReference: { reference: 'Coverage/123' }
            },
            {
              url: 'covered',
              valueCode: 'covered'
            },
            {
              url: 'pa-needed',
              valueCode: 'no-auth'
            },
            {
              url: 'date',
              valueDate: '2025-01-01'
            },
            {
              url: 'coverage-assertion-id',
              valueString: '111222333444'
            }
          ]
        }]
      },
      extension: {
        'com.inferno.resourceSelectionCriteria': 'context.draftOrders.entry.resource.ofType(NutritionOrder)'
      } }
  end

  let(:sytem_action_update_coverage_information_default_empty) do
    { type: 'update', description: 'add coverage-information extension',
      resource: {
        extension: [{
          url: 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/ext-coverage-information',
          extension: [
            {
              url: 'coverage',
              valueReference: { reference: '' }
            },
            {
              url: 'covered',
              valueCode: 'covered'
            },
            {
              url: 'pa-needed',
              valueCode: 'no-auth'
            },
            {
              url: 'date',
              valueDate: nil
            },
            {
              url: 'coverage-assertion-id'
            }
          ]
        }]
      },
      extension: {
        'com.inferno.resourceSelectionCriteria': 'context.draftOrders.entry.resource.ofType(NutritionOrder)'
      } }
  end

  let(:sytem_action_update_coverage_information_default_missing) do
    { type: 'update', description: 'add coverage-information extension',
      resource: {
        extension: [{
          url: 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/ext-coverage-information',
          extension: [
            {
              url: 'covered',
              valueCode: 'covered'
            },
            {
              url: 'pa-needed',
              valueCode: 'no-auth'
            }
          ]
        }]
      },
      extension: {
        'com.inferno.resourceSelectionCriteria': 'context.draftOrders.entry.resource.ofType(NutritionOrder)'
      } }
  end

  # from inferno core (spec/runnable_context.rb) since described class is not one that can receive requests
  let(:suite) { Inferno::Repositories::TestSuites.new.find(suite_id) }
  let(:session_data_repo) { Inferno::Repositories::SessionData.new }
  let(:validation_url) { "#{ENV.fetch('FHIR_RESOURCE_VALIDATOR_URL')}/validate" }
  let(:test_session) { repo_create(:test_session, test_suite_id: suite_id) }

  def run(runnable, inputs = {}, scratch = {})
    test_run_params = { test_session_id: test_session.id }.merge(runnable.reference_hash)
    test_run = Inferno::Repositories::TestRuns.new.create(test_run_params)
    inputs.each do |original_name, value|
      name = runnable.config.input_name(original_name).presence || original_name
      session_data_repo.save(
        test_session_id: test_session.id,
        name:,
        value:,
        type: runnable.available_inputs[name.to_sym]&.type
      )
    end

    Inferno::TestRunner.new(test_session:, test_run:).run(runnable, scratch)
  end

  describe 'When returning a custom response' do
    it 'returns 400 when bad json specified in the input' do
      allow(test).to receive(:suite).and_return(suite)

      token = jwt_helper.build(
        aud: order_sign_url,
        iss: example_client_url,
        jku: "#{example_client_url}/jwks.json",
        encryption_method: 'RS384'
      )

      run(test, cds_jwt_iss: example_client_url, order_sign_custom_response_template: 'not json')

      body['prefetch'] = { 'coverage' => crd_coverage }
      header('Authorization', "Bearer #{token}")
      post_json(server_endpoint, body)

      expect(last_response).to be_server_error
      expect(last_response.body).to match(/Invalid template provided for custom Inferno CRD response: invalid JSON/)
    end

    it 'returns success and updates the uuid on the card when present' do
      allow(test).to receive(:suite).and_return(suite)

      token = jwt_helper.build(
        aud: order_sign_url,
        iss: example_client_url,
        jku: "#{example_client_url}/jwks.json",
        encryption_method: 'RS384'
      )

      instructions_card_template['uuid'] = 'to be replaced'
      response_template = { cards: [instructions_card_template] }
      run(test, cds_jwt_iss: example_client_url, order_sign_custom_response_template: response_template.to_json)

      header('Authorization', "Bearer #{token}")
      post_json(server_endpoint, body)

      expect(last_response).to be_ok
      card_response = JSON.parse(last_response.body)
      expect(card_response['extension']).to be_nil
      cards = card_response['cards']
      expect(cards.length).to eq(1)
      expect(cards[0]['uuid']).to_not eq('to be replaced')
      expect(cards[0]['uuid']).to match(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i)
    end

    it 'returns success and updates the suggestion uuid and instantiates suggestion actions when present' do
      allow(test).to receive(:suite).and_return(suite)
      fhirpath_result = [{ type: 'resource',
                           element: { resourceType: 'MedicationRequest', id: 'smart-MedicationRequest-103',
                                      status: 'details_elided' } }]
      stub_request(:post, "#{fhirpath_url}?path=entry.resource.ofType(MedicationRequest)")
        .to_return(status: 200, body: fhirpath_result.to_json)
      stub_request(:post, "#{fhirpath_url}?path=entry.resource.ofType(MedicationRequest).id")
        .to_return(status: 200, body: [{ type: 'id', element: 'smart-MedicationRequest-103' }].to_json)
      stub_request(:post, "#{fhirpath_url}?path=entry.resource.ofType(ServiceRequest).exists()")
        .to_return(status: 200, body: fhirpath_false_response_body.to_json)

      token = jwt_helper.build(
        aud: order_sign_url,
        iss: example_client_url,
        jku: "#{example_client_url}/jwks.json",
        encryption_method: 'RS384'
      )

      suggestions_card_template['suggestions'][0]['uuid'] = 'to be replaced'
      suggestions_card_template['suggestions'][0]['actions'] << {
        type: 'delete',
        description: 'remove order',
        extension: {
          'com.inferno.resourceSelectionCriteria': 'context.draftOrders.entry.resource.ofType(MedicationRequest)'
        }
      }
      suggestions_card_template['suggestions'][0]['actions'] << {
        type: 'create',
        description: 'add eval',
        resource: { resourceType: 'ServiceRequest',
                    id: '{{context.draftOrders.entry.resource.ofType(MedicationRequest).id}}-replacement' }
      }
      suggestions_card_template['suggestions'][0]['actions'] << {
        type: 'update',
        description: 'add service detail',
        resource: { extension: [{ url: 'test', valueString: 'not_added' }] },
        extension:
          { 'com.inferno.inclusionCriteria': 'context.draftOrders.entry.resource.ofType(ServiceRequest).exists()' }
      }
      response_template = { cards: [suggestions_card_template] }
      run(test, cds_jwt_iss: example_client_url, order_sign_custom_response_template: response_template.to_json)

      header('Authorization', "Bearer #{token}")
      post_json(server_endpoint, body)

      expect(last_response).to be_ok
      card_response = JSON.parse(last_response.body)
      expect(card_response['extension']).to be_nil
      cards = card_response['cards']
      expect(cards.length).to eq(1)
      expect(cards[0]['suggestions'].length).to eq(1)
      expect(cards[0]['suggestions'][0]['uuid'])
        .to match(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i)
      actions = cards[0]['suggestions'][0]['actions']
      expect(actions.length).to eq(2)
      expect(actions[0]['type']).to eq('delete')
      expect(actions[0]['resourceId']).to eq('MedicationRequest/smart-MedicationRequest-103')
      expect(actions[0]['extension']).to be_nil
      expect(actions[1]['type']).to eq('create')
      expect(actions[1]['resource']['resourceType']).to eq('ServiceRequest')
      expect(actions[1]['resource']['id']).to eq('smart-MedicationRequest-103-replacement')
      expect(actions[1]['extension']).to be_nil
    end

    it 'returns success and filters cards and actions when inclusion criteria not met' do
      allow(test).to receive(:suite).and_return(suite)
      stub_request(:post, "#{fhirpath_url}?path=entry.resource.ofType(MedicationRequest).exists()")
        .to_return(status: 200, body: fhirpath_false_response_body.to_json)

      token = jwt_helper.build(
        aud: order_sign_url,
        iss: example_client_url,
        jku: "#{example_client_url}/jwks.json",
        encryption_method: 'RS384'
      )
      instructions_card_template['extension'] =
        { 'com.inferno.inclusionCriteria': 'context.draftOrders.entry.resource.ofType(MedicationRequest).exists()' }
      system_action_template_static['extension'] =
        { 'com.inferno.inclusionCriteria': 'context.draftOrders.entry.resource.ofType(MedicationRequest).exists()' }
      response_template = { cards: [instructions_card_template], systemActions: [system_action_template_static] }
      run(test, cds_jwt_iss: example_client_url, order_sign_custom_response_template: response_template.to_json)

      header('Authorization', "Bearer #{token}")
      post_json(server_endpoint, body)

      expect(last_response).to be_ok
      card_response = JSON.parse(last_response.body)
      expect(card_response['extension']).to be_nil
      cards = card_response['cards']
      actions = card_response['systemActions']
      expect(cards.length).to eq(0)
      expect(actions.length).to eq(0)
    end

    it 'returns success and includes the default card when no other cards selected' do
      allow(test).to receive(:suite).and_return(suite)
      stub_request(:post, "#{fhirpath_url}?path=entry.resource.ofType(MedicationRequest).exists()")
        .to_return(status: 200, body: fhirpath_false_response_body.to_json)

      token = jwt_helper.build(
        aud: order_sign_url,
        iss: example_client_url,
        jku: "#{example_client_url}/jwks.json",
        encryption_method: 'RS384'
      )
      instructions_card_template['extension'] =
        { 'com.inferno.inclusionCriteria': 'context.draftOrders.entry.resource.ofType(MedicationRequest).exists()' }
      suggestions_card_template['extension'] =
        { 'com.inferno.inclusionCriteria': 'default' }
      response_template = { cards: [instructions_card_template, suggestions_card_template] }
      run(test, cds_jwt_iss: example_client_url, order_sign_custom_response_template: response_template.to_json)

      header('Authorization', "Bearer #{token}")
      post_json(server_endpoint, body)

      expect(last_response).to be_ok
      card_response = JSON.parse(last_response.body)
      expect(card_response['extension']).to be_nil
      cards = card_response['cards']
      actions = card_response['systemActions']
      expect(cards.length).to eq(1)
      expect(cards[0]['suggestions']).to be_present
      expect(cards[0]['extension']).to be_nil
      expect(actions.length).to eq(0)
    end

    it 'returns success and does not include the default card when inclusion criteria is met on another card' do
      allow(test).to receive(:suite).and_return(suite)
      stub_request(:post, "#{fhirpath_url}?path=entry.resource.ofType(NutritionOrder).exists()")
        .to_return(status: 200, body: fhirpath_true_response_body.to_json)

      token = jwt_helper.build(
        aud: order_sign_url,
        iss: example_client_url,
        jku: "#{example_client_url}/jwks.json",
        encryption_method: 'RS384'
      )
      instructions_card_template['extension'] =
        { 'com.inferno.inclusionCriteria': 'context.draftOrders.entry.resource.ofType(NutritionOrder).exists()' }
      suggestions_card_template['extension'] =
        { 'com.inferno.inclusionCriteria': 'default' }

      response_template = { cards: [instructions_card_template, suggestions_card_template] }
      run(test, cds_jwt_iss: example_client_url, order_sign_custom_response_template: response_template.to_json)

      header('Authorization', "Bearer #{token}")
      post_json(server_endpoint, body)

      expect(last_response).to be_ok
      card_response = JSON.parse(last_response.body)
      expect(card_response['extension']).to be_nil
      cards = card_response['cards']
      actions = card_response['systemActions']
      expect(cards.length).to eq(1)
      expect(cards[0]['suggestions']).to be_nil
      expect(actions.length).to eq(0)
    end

    it 'returns success and includes cards and actions when inclusion criteria is met' do
      allow(test).to receive(:suite).and_return(suite)
      stub_request(:post, "#{fhirpath_url}?path=entry.resource.ofType(NutritionOrder).exists()")
        .to_return(status: 200, body: fhirpath_true_response_body.to_json)

      token = jwt_helper.build(
        aud: order_sign_url,
        iss: example_client_url,
        jku: "#{example_client_url}/jwks.json",
        encryption_method: 'RS384'
      )
      instructions_card_template['extension'] =
        { 'com.inferno.inclusionCriteria': 'context.draftOrders.entry.resource.ofType(NutritionOrder).exists()' }
      system_action_template_static['extension'] =
        {
          already: 'defined',
          'com.inferno.inclusionCriteria': 'context.draftOrders.entry.resource.ofType(NutritionOrder).exists()'
        }
      response_template = { cards: [instructions_card_template], systemActions: [system_action_template_static] }
      run(test, cds_jwt_iss: example_client_url, order_sign_custom_response_template: response_template.to_json)

      header('Authorization', "Bearer #{token}")
      post_json(server_endpoint, body)

      expect(last_response).to be_ok
      card_response = JSON.parse(last_response.body)
      expect(card_response['extension']).to be_nil
      cards = card_response['cards']
      actions = card_response['systemActions']
      expect(cards.length).to eq(1)
      expect(cards[0]['extension']).to be_nil
      expect(actions.length).to eq(1)
      expect(actions[0]['extension']).to be_present
      expect(actions[0]['extension']['com.inferno.inclusionCriteria']).to be_nil
    end

    it 'returns success and includes actions with replaced tokens' do
      allow(test).to receive(:suite).and_return(suite)

      token = jwt_helper.build(
        aud: order_sign_url,
        iss: example_client_url,
        jku: "#{example_client_url}/jwks.json",
        encryption_method: 'RS384'
      )

      response_template = { cards: [], systemActions: [system_action_template_delete_with_tokens] }
      run(test, cds_jwt_iss: example_client_url, order_sign_custom_response_template: response_template.to_json)

      header('Authorization', "Bearer #{token}")
      post_json(server_endpoint, body)

      expect(last_response).to be_ok
      card_response = JSON.parse(last_response.body)
      expect(card_response['extension']).to be_nil
      cards = card_response['cards']
      actions = card_response['systemActions']
      expect(cards.length).to eq(0)
      expect(actions.length).to eq(1)
      expect(actions[0]['resourceId']).to eq('Patient/example')
    end

    it 'returns success and includes single instantiated actions' do
      allow(test).to receive(:suite).and_return(suite)
      fhirpath_result = [{ type: 'resource',
                           element: { resourceType: 'NutritionOrder', id: 'pureeddiet-simple',
                                      status: 'details_elided' } }]
      stub_request(:post, "#{fhirpath_url}?path=entry.resource.ofType(NutritionOrder)")
        .to_return(status: 200, body: fhirpath_result.to_json)

      token = jwt_helper.build(
        aud: order_sign_url,
        iss: example_client_url,
        jku: "#{example_client_url}/jwks.json",
        encryption_method: 'RS384'
      )
      system_action_template_delete_with_tokens['extension'] =
        { 'com.inferno.resourceSelectionCriteria': 'context.draftOrders.entry.resource.ofType(NutritionOrder)' }

      response_template = { cards: [],
                            systemActions: [system_action_template_delete_with_tokens] }
      run(test, cds_jwt_iss: example_client_url, order_sign_custom_response_template: response_template.to_json)

      header('Authorization', "Bearer #{token}")
      post_json(server_endpoint, body)

      expect(last_response).to be_ok
      card_response = JSON.parse(last_response.body)
      expect(card_response['extension']).to be_nil
      cards = card_response['cards']
      actions = card_response['systemActions']
      expect(cards.length).to eq(0)
      expect(actions.length).to eq(1)
      expect(actions[0]['type']).to eq('delete')
      expect(actions[0]['resourceId']).to eq('NutritionOrder/pureeddiet-simple')
      expect(actions[0]['resource']).to be_nil
      expect(actions[0]['extension']).to be_nil
    end

    it 'returns success and includes multiple instantiated actions' do
      allow(test).to receive(:suite).and_return(suite)
      fhirpath_result = [{ type: 'resource',
                           element: { resourceType: 'NutritionOrder', id: 'pureeddiet-simple',
                                      status: 'details_elided' } },
                         { type: 'resource',
                           element: { resourceType: 'MedicationRequest', id: 'smart-MedicationRequest-103',
                                      status: 'details_elided' } }]
      stub_request(:post, "#{fhirpath_url}?path=entry.resource")
        .to_return(status: 200, body: fhirpath_result.to_json)

      token = jwt_helper.build(
        aud: order_sign_url,
        iss: example_client_url,
        jku: "#{example_client_url}/jwks.json",
        encryption_method: 'RS384'
      )
      system_action_template_delete_with_tokens['extension'] =
        { 'com.inferno.resourceSelectionCriteria': 'context.draftOrders.entry.resource' }
      response_template = { cards: [],
                            systemActions: [system_action_template_delete_with_tokens] }
      run(test, cds_jwt_iss: example_client_url, order_sign_custom_response_template: response_template.to_json)

      header('Authorization', "Bearer #{token}")
      post_json(server_endpoint, body)

      expect(last_response).to be_ok
      card_response = JSON.parse(last_response.body)
      expect(card_response['extension']).to be_nil
      cards = card_response['cards']
      actions = card_response['systemActions']
      expect(cards.length).to eq(0)
      expect(actions.length).to eq(2)
      expect(actions[0]['type']).to eq('delete')
      expect(actions[0]['resourceId']).to eq('NutritionOrder/pureeddiet-simple')
      expect(actions[0]['resource']).to be_nil
      expect(actions[0]['extension']).to be_nil
      expect(actions[1]['type']).to eq('delete')
      expect(actions[1]['resourceId']).to eq('MedicationRequest/smart-MedicationRequest-103')
      expect(actions[1]['resource']).to be_nil
      expect(actions[1]['extension']).to be_nil
    end

    it 'returns success and includes instantiated systemActions defaults when appropriate' do
      allow(test).to receive(:suite).and_return(suite)
      fhirpath_result = [{ type: 'resource',
                           element: { resourceType: 'ServiceRequest', id: '123',
                                      status: 'details_elided' } },
                         { type: 'resource',
                           element: { resourceType: 'MedicationRequest', id: 'smart-MedicationRequest-103',
                                      status: 'details_elided' } }]
      stub_request(
        :post,
        "#{fhirpath_url}?path=entry.select(resource.ofType(ServiceRequest) | resource.ofType(MedicationRequest))"
      ).to_return(status: 200, body: fhirpath_result.to_json)

      fhirpath_result = [{ type: 'resource',
                           element: { resourceType: 'ServiceRequest', id: '123',
                                      status: 'details_elided' } },
                         { type: 'resource',
                           element: { resourceType: 'DeviceRequest', id: '456',
                                      status: 'details_elided' } }]
      stub_request(
        :post,
        "#{fhirpath_url}?path=entry.select(resource.ofType(ServiceRequest) | resource.ofType(DeviceRequest))"
      ).to_return(status: 200, body: fhirpath_result.to_json)

      token = jwt_helper.build(
        aud: order_sign_url,
        iss: example_client_url,
        jku: "#{example_client_url}/jwks.json",
        encryption_method: 'RS384'
      )
      system_action_template_update_extension_with_tokens['extension'] =
        { 'com.inferno.resourceSelectionCriteria':
            'context.draftOrders.entry.select(resource.ofType(ServiceRequest) | resource.ofType(MedicationRequest))' }
      system_action_template_update_extension_default['extension'] =
        { 'com.inferno.inclusionCriteria': 'default',
          'com.inferno.resourceSelectionCriteria':
            'context.draftOrders.entry.select(resource.ofType(ServiceRequest) | resource.ofType(DeviceRequest))' }
      response_template = { cards: [],
                            systemActions: [system_action_template_update_extension_with_tokens,
                                            system_action_template_update_extension_default] }
      body['context']['draftOrders']['entry'] << {
        resource: FHIR::ServiceRequest.new({ id: '123' })
      }
      body['context']['draftOrders']['entry'] << {
        resource: FHIR::DeviceRequest.new({ id: '456' })
      }

      run(test, cds_jwt_iss: example_client_url,
                order_sign_custom_response_template: response_template.to_json)

      header('Authorization', "Bearer #{token}")
      post_json(server_endpoint, body)

      expect(last_response).to be_ok
      card_response = JSON.parse(last_response.body)
      expect(card_response['extension']).to be_nil
      cards = card_response['cards']
      actions = card_response['systemActions']
      expect(cards.length).to eq(0)
      expect(actions.length).to eq(3)
      expect(actions[0]['type']).to eq('update')
      expect(actions[0]['resourceId']).to be_nil
      expect(actions[0]['resource']).to be_present
      expect(actions[0]['resource']['resourceType']).to eq('ServiceRequest')
      expect(actions[0]['description']).to eq('add extension')
      expect(actions[0]['extension']).to be_nil
      expect(actions[1]['type']).to eq('update')
      expect(actions[1]['resourceId']).to be_nil
      expect(actions[1]['resource']).to be_present
      expect(actions[1]['resource']['resourceType']).to eq('MedicationRequest')
      expect(actions[1]['description']).to eq('add extension')
      expect(actions[1]['extension']).to be_nil
      expect(actions[2]['type']).to eq('update')
      expect(actions[2]['resourceId']).to be_nil
      expect(actions[2]['resource']).to be_present
      expect(actions[2]['resource']['resourceType']).to eq('DeviceRequest')
      expect(actions[2]['description']).to eq('add extension (Default)')
      expect(actions[2]['extension']).to be_nil
    end

    it 'returns success and includes instantiated action defaults under Suggestions when appropriate' do
      allow(test).to receive(:suite).and_return(suite)
      fhirpath_result = [{ type: 'resource',
                           element: { resourceType: 'ServiceRequest', id: '123',
                                      status: 'details_elided' } },
                         { type: 'resource',
                           element: { resourceType: 'MedicationRequest', id: 'smart-MedicationRequest-103',
                                      status: 'details_elided' } }]
      stub_request(
        :post,
        "#{fhirpath_url}?path=entry.select(resource.ofType(ServiceRequest) | resource.ofType(MedicationRequest))"
      ).to_return(status: 200, body: fhirpath_result.to_json)

      fhirpath_result = [{ type: 'resource',
                           element: { resourceType: 'ServiceRequest', id: '123',
                                      status: 'details_elided' } },
                         { type: 'resource',
                           element: { resourceType: 'DeviceRequest', id: '456',
                                      status: 'details_elided' } }]
      stub_request(
        :post,
        "#{fhirpath_url}?path=entry.select(resource.ofType(ServiceRequest) | resource.ofType(DeviceRequest))"
      ).to_return(status: 200, body: fhirpath_result.to_json)

      token = jwt_helper.build(
        aud: order_sign_url,
        iss: example_client_url,
        jku: "#{example_client_url}/jwks.json",
        encryption_method: 'RS384'
      )

      system_action_template_update_extension_with_tokens['extension'] =
        { 'com.inferno.resourceSelectionCriteria':
            'context.draftOrders.entry.select(resource.ofType(ServiceRequest) | resource.ofType(MedicationRequest))' }
      system_action_template_update_extension_default['extension'] =
        { 'com.inferno.inclusionCriteria': 'default',
          'com.inferno.resourceSelectionCriteria':
            'context.draftOrders.entry.select(resource.ofType(ServiceRequest) | resource.ofType(DeviceRequest))' }
      suggestions_card_template['suggestions'][0]['actions'] << system_action_template_update_extension_with_tokens
      suggestions_card_template['suggestions'][0]['actions'] << system_action_template_update_extension_default
      response_template = { cards: [suggestions_card_template] }
      body['context']['draftOrders']['entry'] << {
        resource: FHIR::ServiceRequest.new({ id: '123' })
      }
      body['context']['draftOrders']['entry'] << {
        resource: FHIR::DeviceRequest.new({ id: '456' })
      }

      run(test, cds_jwt_iss: example_client_url,
                order_sign_custom_response_template: response_template.to_json)

      header('Authorization', "Bearer #{token}")
      post_json(server_endpoint, body)

      expect(last_response).to be_ok
      card_response = JSON.parse(last_response.body)
      expect(card_response['extension']).to be_nil
      cards = card_response['cards']
      actions = card_response['systemActions']
      expect(cards.length).to eq(1)
      expect(actions.length).to eq(0)
      suggestion = cards[0]['suggestions']&.first
      expect(suggestion).to be_present
      expect(suggestion['actions'].length).to eq(3)
      expect(suggestion['actions'][0]['type']).to eq('update')
      expect(suggestion['actions'][0]['resourceId']).to be_nil
      expect(suggestion['actions'][0]['resource']).to be_present
      expect(suggestion['actions'][0]['resource']['resourceType']).to eq('ServiceRequest')
      expect(suggestion['actions'][0]['description']).to eq('add extension')
      expect(suggestion['actions'][0]['extension']).to be_nil
      expect(suggestion['actions'][1]['type']).to eq('update')
      expect(suggestion['actions'][1]['resourceId']).to be_nil
      expect(suggestion['actions'][1]['resource']).to be_present
      expect(suggestion['actions'][1]['resource']['resourceType']).to eq('MedicationRequest')
      expect(suggestion['actions'][1]['description']).to eq('add extension')
      expect(suggestion['actions'][1]['extension']).to be_nil
      expect(suggestion['actions'][2]['type']).to eq('update')
      expect(suggestion['actions'][2]['resourceId']).to be_nil
      expect(suggestion['actions'][2]['resource']).to be_present
      expect(suggestion['actions'][2]['resource']['resourceType']).to eq('DeviceRequest')
      expect(suggestion['actions'][2]['description']).to eq('add extension (Default)')
      expect(suggestion['actions'][2]['extension']).to be_nil
    end

    it 'returns success and instantiates an update action with a resource without extensions' do
      allow(test).to receive(:suite).and_return(suite)
      fhirpath_result = [{ type: 'resource',
                           element: { resourceType: 'MedicationRequest', id: 'smart-MedicationRequest-103',
                                      status: 'details_elided' } }]
      stub_request(:post, "#{fhirpath_url}?path=entry.resource.ofType(MedicationRequest)")
        .to_return(status: 200, body: fhirpath_result.to_json)

      token = jwt_helper.build(
        aud: order_sign_url,
        iss: example_client_url,
        jku: "#{example_client_url}/jwks.json",
        encryption_method: 'RS384'
      )
      system_action_template_update_extension_with_tokens['extension'] =
        { 'com.inferno.resourceSelectionCriteria': 'context.draftOrders.entry.resource.ofType(MedicationRequest)' }

      response_template = { cards: [],
                            systemActions: [system_action_template_update_extension_with_tokens] }
      run(test, cds_jwt_iss: example_client_url, order_sign_custom_response_template: response_template.to_json)

      header('Authorization', "Bearer #{token}")
      post_json(server_endpoint, body)

      expect(last_response).to be_ok
      card_response = JSON.parse(last_response.body)
      expect(card_response['extension']).to be_nil
      cards = card_response['cards']
      actions = card_response['systemActions']
      expect(cards.length).to eq(0)
      expect(actions.length).to eq(1)
      expect(actions[0]['type']).to eq('update')
      expect(actions[0]['extension']).to be_nil
      expect(actions[0]['resourceId']).to be_nil
      expect(actions[0]['resource']['resourceType']).to eq('MedicationRequest')
      expect(actions[0]['resource']['id']).to eq('overrideId')
      expect(actions[0]['resource']['extension'].length).to eq(1)
      expect(actions[0]['resource']['extension'][0]['url']).to eq('added_hookInstance')
      expect(actions[0]['resource']['extension'][0]['valueString']).to eq('d1577c69-dfbe-44ad-ba6d-3e05e953b2ea')
    end

    it 'returns success and instantiates an update action with a resource with extensions' do
      allow(test).to receive(:suite).and_return(suite)
      fhirpath_result = [{ type: 'resource',
                           element: { resourceType: 'NutritionOrder', id: 'pureeddiet-simple',
                                      extension: [
                                        {
                                          url: 'existing_extension',
                                          valueString: 'existing_value'
                                        },
                                        {
                                          url: 'to_replace',
                                          valueString: 'existing_value'
                                        }
                                      ],
                                      status: 'details_elided' } }]
      stub_request(:post, "#{fhirpath_url}?path=entry.resource.ofType(NutritionOrder)")
        .to_return(status: 200, body: fhirpath_result.to_json)

      token = jwt_helper.build(
        aud: order_sign_url,
        iss: example_client_url,
        jku: "#{example_client_url}/jwks.json",
        encryption_method: 'RS384'
      )
      system_action_template_update_extension_with_tokens['extension'] =
        { 'com.inferno.resourceSelectionCriteria': 'context.draftOrders.entry.resource.ofType(NutritionOrder)' }
      system_action_template_update_extension_with_tokens[:resource][:extension] << {
        url: 'to_replace',
        valueString: 'new_value'
      }

      response_template = { cards: [],
                            systemActions: [system_action_template_update_extension_with_tokens] }
      run(test, cds_jwt_iss: example_client_url, order_sign_custom_response_template: response_template.to_json)

      header('Authorization', "Bearer #{token}")
      post_json(server_endpoint, body)

      expect(last_response).to be_ok
      card_response = JSON.parse(last_response.body)
      expect(card_response['extension']).to be_nil
      cards = card_response['cards']
      actions = card_response['systemActions']
      expect(cards.length).to eq(0)
      expect(actions.length).to eq(1)
      expect(actions[0]['type']).to eq('update')
      expect(actions[0]['extension']).to be_nil
      expect(actions[0]['resourceId']).to be_nil
      expect(actions[0]['resource']['resourceType']).to eq('NutritionOrder')
      expect(actions[0]['resource']['id']).to eq('overrideId')
      expect(actions[0]['resource']['extension'].length).to eq(3)
      expect(actions[0]['resource']['extension'][0]['url']).to eq('existing_extension')
      expect(actions[0]['resource']['extension'][0]['valueString']).to eq('existing_value')
      expect(actions[0]['resource']['extension'][1]['url']).to eq('added_hookInstance')
      expect(actions[0]['resource']['extension'][1]['valueString']).to eq('d1577c69-dfbe-44ad-ba6d-3e05e953b2ea')
      expect(actions[0]['resource']['extension'][2]['url']).to eq('to_replace')
      expect(actions[0]['resource']['extension'][2]['valueString']).to eq('new_value')
    end

    it 'returns success and instantiates update actions with a coverage-information extension details' do
      allow(test).to receive(:suite).and_return(suite)
      fhirpath_result = [{ type: 'resource',
                           element: { resourceType: 'NutritionOrder', id: 'pureeddiet-simple',
                                      status: 'details_elided' } }]
      stub_request(:post, "#{fhirpath_url}?path=entry.resource.ofType(NutritionOrder)")
        .to_return(status: 200, body: fhirpath_result.to_json)
      coverage_result = FHIR::Bundle.new(
        entry: [
          FHIR::Bundle::Entry.new(
            resource: FHIR::Coverage.new(
              id: 'queried_coverage_id'
            )
          )
        ]
      )
      stub_request(:get, "#{client_fhir_server}/Coverage?patient=example&status=active")
        .to_return(status: 200, body: coverage_result.to_json)

      token = jwt_helper.build(
        aud: order_sign_url,
        iss: example_client_url,
        jku: "#{example_client_url}/jwks.json",
        encryption_method: 'RS384'
      )

      response_template = { cards: [],
                            systemActions: [sytem_action_update_coverage_information_no_defaults,
                                            sytem_action_update_coverage_information_default_empty,
                                            sytem_action_update_coverage_information_default_missing] }
      run(test, cds_jwt_iss: example_client_url, order_sign_custom_response_template: response_template.to_json)

      header('Authorization', "Bearer #{token}")
      post_json(server_endpoint, body)

      expect(last_response).to be_ok
      card_response = JSON.parse(last_response.body)
      cards = card_response['cards']
      actions = card_response['systemActions']
      expect(card_response['extension']).to be_nil
      expect(cards.length).to eq(0)
      expect(actions.length).to eq(3)
      actions.each do |action|
        expect(action['type']).to eq('update')
        expect(action['extension']).to be_nil
        expect(action['resourceId']).to be_nil
        expect(action['resource']['resourceType']).to eq('NutritionOrder')
        expect(action['resource']['id']).to eq('pureeddiet-simple')
        expect(action['resource']['extension'].length).to eq(1)
      end

      no_defaults_ext = actions[0]['resource']['extension'][0]
      expect(no_defaults_ext['url']).to eq('http://hl7.org/fhir/us/davinci-crd/StructureDefinition/ext-coverage-information')
      expect(no_defaults_ext['extension'][0]['url']).to eq('coverage')
      expect(no_defaults_ext['extension'][0]['valueReference']['reference']).to eq('Coverage/123')
      expect(no_defaults_ext['extension'][3]['url']).to eq('date')
      expect(no_defaults_ext['extension'][3]['valueDate']).to eq('2025-01-01')
      expect(no_defaults_ext['extension'][4]['url']).to eq('coverage-assertion-id')
      expect(no_defaults_ext['extension'][4]['valueString']).to eq('111222333444')

      defaults_from_empty = actions[1]['resource']['extension'][0]
      expect(defaults_from_empty['url']).to eq('http://hl7.org/fhir/us/davinci-crd/StructureDefinition/ext-coverage-information')
      expect(defaults_from_empty['extension'][0]['url']).to eq('coverage')
      expect(defaults_from_empty['extension'][0]['valueReference']['reference']).to eq('Coverage/queried_coverage_id')
      expect(defaults_from_empty['extension'][3]['url']).to eq('date')
      expect(defaults_from_empty['extension'][3]['valueDate']).to eq(Time.now.utc.strftime('%Y-%m-%d'))
      expect(defaults_from_empty['extension'][4]['url']).to eq('coverage-assertion-id')
      expect(defaults_from_empty['extension'][4]['valueString']).to be_present

      defaults_from_missing = actions[2]['resource']['extension'][0]
      expect(defaults_from_missing['url']).to eq('http://hl7.org/fhir/us/davinci-crd/StructureDefinition/ext-coverage-information')
      expect(defaults_from_missing['extension'][2]['url']).to eq('coverage')
      expect(defaults_from_missing['extension'][2]['valueReference']['reference']).to eq('Coverage/queried_coverage_id')
      expect(defaults_from_missing['extension'][3]['url']).to eq('date')
      expect(defaults_from_missing['extension'][3]['valueDate']).to eq(Time.now.utc.strftime('%Y-%m-%d'))
      expect(defaults_from_missing['extension'][4]['url']).to eq('coverage-assertion-id')
      expect(defaults_from_missing['extension'][4]['valueString']).to be_present
      expect(defaults_from_missing['extension'][4]['valueString'])
        .to_not eq(defaults_from_empty['extension'][4]['valueString'])
    end

    it 'returns success and does not duplicate sub-extensions when coverage-information is instantiated twice' do
      allow(test).to receive(:suite).and_return(suite)
      fhirpath_result = [{ type: 'resource',
                           element: { resourceType: 'NutritionOrder', id: 'pureeddiet-simple',
                                      status: 'details_elided' } },
                         { type: 'resource',
                           element: { resourceType: 'MedicationRequest', id: 'smart-MedicationRequest-103',
                                      status: 'details_elided' } }]
      stub_request(:post, "#{fhirpath_url}?path=entry.resource")
        .to_return(status: 200, body: fhirpath_result.to_json)
      coverage_result = FHIR::Bundle.new(
        entry: [
          FHIR::Bundle::Entry.new(
            resource: FHIR::Coverage.new(
              id: 'queried_coverage_id'
            )
          )
        ]
      )
      stub_request(:get, "#{client_fhir_server}/Coverage?patient=example&status=active")
        .to_return(status: 200, body: coverage_result.to_json)

      token = jwt_helper.build(
        aud: order_sign_url,
        iss: example_client_url,
        jku: "#{example_client_url}/jwks.json",
        encryption_method: 'RS384'
      )
      sytem_action_update_coverage_information_default_missing[:extension][:'com.inferno.resourceSelectionCriteria'] =
        'context.draftOrders.entry.resource'

      response_template = { cards: [],
                            systemActions: [sytem_action_update_coverage_information_default_missing] }
      run(test, cds_jwt_iss: example_client_url, order_sign_custom_response_template: response_template.to_json)

      header('Authorization', "Bearer #{token}")
      post_json(server_endpoint, body)

      expect(last_response).to be_ok
      card_response = JSON.parse(last_response.body)
      expect(card_response['extension']).to be_nil
      cards = card_response['cards']
      actions = card_response['systemActions']
      expect(cards.length).to eq(0)
      expect(actions.length).to eq(2)

      cov_info_ext = actions[0]['resource']['extension'][0]
      expect(cov_info_ext['url']).to eq('http://hl7.org/fhir/us/davinci-crd/StructureDefinition/ext-coverage-information')
      expect(cov_info_ext['extension'][2]['url']).to eq('coverage')
      expect(cov_info_ext['extension'][2]['valueReference']['reference']).to eq('Coverage/queried_coverage_id')
      expect(cov_info_ext['extension'][3]['url']).to eq('date')
      expect(cov_info_ext['extension'][3]['valueDate']).to eq(Time.now.utc.strftime('%Y-%m-%d'))
      expect(cov_info_ext['extension'][4]['url']).to eq('coverage-assertion-id')
      expect(cov_info_ext['extension'][4]['valueString']).to be_present
      expect(cov_info_ext['extension'].length).to eq(5)
    end
  end
end
