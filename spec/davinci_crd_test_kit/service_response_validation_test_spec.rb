RSpec.describe DaVinciCRDTestKit::ServiceResponseValidationTest do
  let(:suite_id) { 'crd_server' }
  let(:runnable) { described_class }
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:discovery_url) { 'http://example.com/cds-services' }
  let(:service_id) { 'service_id' }
  let(:valid_response_body_json) do
    File.read(File.join(__dir__, '..', 'fixtures', 'crd_authorization_hook_response.json'))
  end
  let(:card_required_fields) { ['summary', 'indicator', 'source'] }
  let(:body) { JSON.parse(valid_response_body_json) }

  def create_service_request(body: nil, status: 200, headers: nil)
    repo_create(
      :request,
      direction: 'outgoing',
      url: "#{discovery_url}/#{service_id}",
      test_session_id: test_session.id,
      response_body: body.is_a?(Hash) ? body.to_json : body,
      status:,
      headers:
    )
  end

  def mock_server(body: nil, status: 200, headers: nil, hook: 'other')
    allow_any_instance_of(runnable).to receive(:tested_hook_name).and_return(hook)
    request = create_service_request(body:, status:, headers:)
    allow_any_instance_of(runnable).to receive(:requests).and_return([request])
  end

  def entity_result_message
    results_repo.current_results_for_test_session_and_runnables(test_session.id, [runnable])
      .first
      .messages
      .first
  end

  context 'when appointment-book or order-sign hook' do
    let(:hook) { ['appointment-book', 'order-sign'].sample }

    it 'passes if response body contains valid cards and system actions' do
      mock_server(body: valid_response_body_json, hook:)
      result = run(runnable, invoked_hook: hook)
      expect(result.result).to eq('pass')
    end

    it 'fails if system actions is missing from the response' do
      body.delete('systemActions')
      mock_server(body: body.to_json, hook:)

      result = run(runnable, invoked_hook: hook)
      expect(result.result).to eq('fail')
      expect(entity_result_message.message).to match(/did not have `systemActions` field/)
    end

    it 'fails if system actions is not an array' do
      body['systemActions'] = {}
      mock_server(body: body.to_json, hook:)

      result = run(runnable, invoked_hook: hook)
      expect(result.result).to eq('fail')
      expect(entity_result_message.message).to match(/is not an array/)
    end

    it 'persists outputs' do
      mock_server(body: valid_response_body_json, hook:)

      result = run(runnable, invoked_hook: hook)
      expect(result.result).to eq('pass')

      persisted_cards = session_data_repo.load(test_session_id: test_session.id, name: :valid_cards)
      persisted_actions = session_data_repo.load(test_session_id: test_session.id, name: :valid_system_actions)
      expect(persisted_cards).to eq(body['cards'].to_json)
      expect(persisted_actions).to eq(body['systemActions'].to_json)
    end
  end

  context 'when any hook' do
    it 'passes if response body contains valid cards' do
      mock_server(body: valid_response_body_json)

      result = run(runnable, invoked_hook: 'order-sign')
      expect(result.result).to eq('pass')
    end

    it 'skips if no successful requests' do
      mock_server(status: 400)

      result = run(runnable, invoked_hook: 'order-sign')
      expect(result.result).to eq('skip')
      expect(result.result_message).to match(/All service requests were unsuccessful/)
    end

    it 'passes with warning if response body `cards` is an empty array' do
      mock_server(body: { 'cards' => [], 'systemActions' => [] })

      result = run(runnable, invoked_hook: 'order-sign')
      expect(result.result).to eq('pass')
      expect(entity_result_message.message).to match(/no decision support/)
      expect(entity_result_message.type).to eq('warning')
    end

    it 'fails if response body is invalid json' do
      mock_server(body: 'body')

      result = run(runnable, invoked_hook: 'order-sign')
      expect(result.result).to eq('fail')
      expect(entity_result_message.message).to match(/Invalid JSON/)
    end

    it 'fails if cards is missing from a response' do
      mock_server(body: {})

      result = run(runnable, invoked_hook: 'order-sign')
      expect(result.result).to eq('fail')
      expect(entity_result_message.message).to match(/did not have the `cards` field/)
    end

    it 'fails if cards is not an array in at least one of the responses' do
      mock_server(body: { 'cards' => {} })

      result = run(runnable, invoked_hook: 'order-sign')
      expect(result.result).to eq('fail')
      expect(entity_result_message.message).to match(/is not an array/)
    end

    it 'fails if required field is missing from a card' do
      card_required_fields.each do |field|
        body_dup = body.deep_dup
        body_dup['cards'].first.delete(field)
        mock_server(body: body_dup)

        result = run(runnable, invoked_hook: 'order-sign')
        expect(result.result).to eq('fail')
        expect(entity_result_message.message).to match(/Card does not contain required field `#{field}`/)
      end
    end

    it 'fails if card required field is the wrong type' do
      card_required_fields.each do |field|
        body_dup = body.deep_dup
        body_dup['cards'].first.merge!(field => 123)
        mock_server(body: body_dup)

        result = run(runnable, invoked_hook: 'order-sign')
        expect(result.result).to eq('fail')
        expect(entity_result_message.message).to match(/Card field `#{field}` is not of type/)
      end
    end

    it 'fails if a card\'s summary if more than 140 characters' do
      body_dup = body.deep_dup
      body_dup['cards'].each do |card|
        card['summary'] = SecureRandom.alphanumeric(150)
        mock_server(body: body_dup)

        result = run(runnable, invoked_hook: 'order-sign')
        expect(result.result).to eq('fail')
        expect(entity_result_message.message).to match(/`summary` is over the 140-character limit/)
      end
    end

    it 'fails if a card\'s indicator value is not an allowed value' do
      body_dup = body.deep_dup
      body_dup['cards'].each do |card|
        card['indicator'] = 'random'
        mock_server(body: body_dup)

        result = run(runnable, invoked_hook: 'order-sign')
        expect(result.result).to eq('fail')
        expect(entity_result_message.message).to match(/Allowed values are `info`, `warning`, `critical`/)
      end
    end

    it 'fails if a required field is missing from a card source' do
      ['label', 'topic'].each do |field|
        body_dup = body.deep_dup
        body_dup['cards'].first['source'].delete(field)
        mock_server(body: body_dup)

        result = run(runnable, invoked_hook: 'order-sign')
        expect(result.result).to eq('fail')
        expect(entity_result_message.message).to match(/Source does not contain required field `#{field}`/)
      end
    end

    it 'fails if a card source required field is a wrong type' do
      ['label', 'topic'].each do |field|
        body_dup = body.deep_dup
        body_dup['cards'].first['source'].merge!(field => 123)
        mock_server(body: body_dup)

        result = run(runnable, invoked_hook: 'order-sign')
        expect(result.result).to eq('fail')
        expect(entity_result_message.message).to match(/Source field `#{field}` is not of type/)
      end
    end

    it 'fails if a required field is missing from a card source topic' do
      ['code', 'system'].each do |field|
        body_dup = body.deep_dup
        body_dup['cards'].first['source']['topic'].delete(field)
        mock_server(body: body_dup)

        result = run(runnable, invoked_hook: 'order-sign')
        expect(result.result).to eq('fail')
        expect(entity_result_message.message).to match(/Source topic does not contain required field `#{field}`/)
      end
    end

    it 'fails if a card source topic required field is a wrong type' do
      ['code', 'system'].each do |field|
        body_dup = body.deep_dup
        body_dup['cards'].first['source']['topic'].merge!(field => 123)
        mock_server(body: body_dup)

        result = run(runnable, invoked_hook: 'order-sign')
        expect(result.result).to eq('fail')
        expect(entity_result_message.message).to match(/Source topic field `#{field}` is not of type/)
      end
    end

    it 'fails if a required field is missing from systemAction' do
      body_dup = body.deep_dup
      body_dup['systemActions'] = [
        { 'type' => 'delete', 'resourceId' => ['MedicationRequest/smart-MedicationRequest-103'] }
      ]
      mock_server(body: body_dup)
      result = run(runnable, invoked_hook: 'order-sign')
      expect(result.result).to eq('fail')
      expect(entity_result_message.message).to match(/does not contain required field `description`/)
    end

    it 'fails if systemAction required field is a wrong type' do
      body_dup = body.deep_dup
      body_dup['systemActions'] = [
        { 'type' => 'delete', 'resourceId' => ['MedicationRequest/smart-MedicationRequest-103'], 'description' => 123 }
      ]
      mock_server(body: body_dup)
      result = run(runnable, invoked_hook: 'order-sign')
      expect(result.result).to eq('fail')
      expect(entity_result_message.message).to match(/field `description` is not of type/)
    end

    it 'fails systemAction.type is not an allowed value' do
      body_dup = body.deep_dup
      body_dup['systemActions'] = [
        { 'type' => 'abc', 'resourceId' => ['MedicationRequest/smart-MedicationRequest-103'], 'description' => 'ok' }
      ]
      mock_server(body: body_dup)
      result = run(runnable, invoked_hook: 'order-sign')
      expect(result.result).to eq('fail')
      expect(entity_result_message.message).to match(/is not allowed/)
    end

    it 'fails if a create action does not have a resource field' do
      body_dup = body.deep_dup
      body_dup['systemActions'] = [
        { 'type' => 'create', 'description' => 'ok' }
      ]
      mock_server(body: body_dup)
      result = run(runnable, invoked_hook: 'order-sign')
      expect(result.result).to eq('fail')
      expect(entity_result_message.message).to match(/Action.resource` must be present/)
    end

    it 'fails if a create action resource is not a FHIR resource' do
      body_dup = body.deep_dup
      body_dup['systemActions'] = [
        { 'type' => 'create', 'description' => 'ok', 'resource' => '123' }
      ]
      mock_server(body: body_dup)
      result = run(runnable, invoked_hook: 'order-sign')
      expect(result.result).to eq('fail')
      expect(entity_result_message.message).to match(/`Action.resource` must be a FHIR resource/)
    end

    it 'fails if a delete action does not have a resourceId field' do
      body_dup = body.deep_dup
      body_dup['systemActions'] = [
        { 'type' => 'delete', 'description' => '123' }
      ]
      mock_server(body: body_dup)
      result = run(runnable, invoked_hook: 'order-sign')
      expect(result.result).to eq('fail')
      expect(entity_result_message.message).to match(/does not contain required field `resourceId`/)
    end

    it 'fails if a delete action resourceId is not an array' do
      body_dup = body.deep_dup
      body_dup['systemActions'] = [
        { 'type' => 'delete', 'description' => '123', 'resourceId' => ['123'] }
      ]
      mock_server(body: body_dup)
      result = run(runnable, invoked_hook: 'order-sign')
      expect(result.result).to eq('fail')
      expect(entity_result_message.message).to match(/is not of type `String`/)
    end

    it 'fails if a delete action resourceId item is not a relative reference' do
      body_dup = body.deep_dup
      body_dup['systemActions'] = [
        { 'type' => 'delete', 'description' => '123', 'resourceId' => '123' }
      ]
      mock_server(body: body_dup)
      result = run(runnable, invoked_hook: 'order-sign')
      expect(result.result).to eq('fail')
      expect(entity_result_message.message).to match(/Invalid `Action.resourceId` format/)
    end

    it 'persists outputs' do
      mock_server(body: valid_response_body_json)

      result = run(runnable, invoked_hook: 'order-sign')
      expect(result.result).to eq('pass')

      persisted_cards = session_data_repo.load(test_session_id: test_session.id, name: :valid_cards)
      persisted_actions = session_data_repo.load(test_session_id: test_session.id, name: :valid_system_actions)
      expect(persisted_cards).to eq(body['cards'].to_json)
      expect(persisted_actions).to eq(body['systemActions'].to_json)
    end
  end
end
