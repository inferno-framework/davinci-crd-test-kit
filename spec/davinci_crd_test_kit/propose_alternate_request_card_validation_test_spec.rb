RSpec.describe DaVinciCRDTestKit::ProposeAlternateRequestCardValidationTest do
  let(:runnable) { Inferno::Repositories::Tests.new.find('crd_propose_alternate_request_card_validation') }
  let(:session_data_repo) { Inferno::Repositories::SessionData.new }
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:suite_id) { 'crd_server' }
  let(:order_select_context) do
    json = File.read(File.join(__dir__, '..', 'fixtures', 'order_select_context.json'))
    JSON.parse(json)
  end
  let(:valid_cards) do
    json = File.read(File.join(__dir__, '..', 'fixtures', 'valid_cards.json'))
    JSON.parse(json)
  end
  let(:cards_with_suggestions) { valid_cards.filter { |card| card['suggestions'].present? } }

  def run(runnable, inputs = {})
    test_run_params = { test_session_id: test_session.id }.merge(runnable.reference_hash)
    test_run = Inferno::Repositories::TestRuns.new.create(test_run_params)
    inputs.each do |name, value|
      session_data_repo.save(
        test_session_id: test_session.id,
        name:,
        value:,
        type: runnable.config.input_type(name)
      )
    end
    Inferno::TestRunner.new(test_session:, test_run:).run(runnable)
  end

  def entity_result_message
    results_repo.current_results_for_test_session_and_runnables(test_session.id, [runnable])
      .first
      .messages
      .first
  end

  before do
    allow_any_instance_of(runnable).to receive(:resource_is_valid?).and_return(true)
  end

  it 'passes if valid propose alternate request cards are received' do
    result = run(runnable, valid_cards_with_suggestions: cards_with_suggestions.to_json,
                           contexts: [order_select_context].to_json)

    expect(result.result).to eq('pass')
  end

  it 'skips if valid_cards_with_suggestions not present' do
    result = run(runnable, contexts: [order_select_context].to_json)
    expect(result.result).to eq('skip')
    expect(result.result_message).to match(/'valid_cards_with_suggestions' is nil, skipping test/)
  end

  it 'skips if contexts not present' do
    result = run(runnable, valid_cards_with_suggestions: cards_with_suggestions.to_json)
    expect(result.result).to eq('skip')
    expect(result.result_message).to match(/'contexts' is nil, skipping test/)
  end

  it 'fails if valid_cards_with_suggestions is not valid json' do
    result = run(runnable, valid_cards_with_suggestions: '[[', contexts: [order_select_context].to_json)
    expect(result.result).to eq('fail')
    expect(result.result_message).to match(/Invalid JSON/)
  end

  it 'fails if contexts is not json' do
    result = run(runnable, valid_cards_with_suggestions: cards_with_suggestions.to_json, contexts: '[[')
    expect(result.result).to eq('fail')
    expect(result.result_message).to match(/Invalid JSON/)
  end

  it 'skips if no propose alternate request card present' do
    result = run(runnable, valid_cards_with_suggestions: [].to_json, contexts: [order_select_context].to_json)
    expect(result.result).to eq('skip')
    expect(result.result_message).to match(/does not contain a Propose Alternate Request card/)
  end

  it 'fails if the order being deleted is not in draftOrders' do
    dup_cards = cards_with_suggestions.deep_dup
    action = dup_cards.first['suggestions'].first['actions'].find { |act| act['type'] == 'delete' }
    action['resourceId'] << 'ServiceRequest/example'

    result = run(runnable, valid_cards_with_suggestions: dup_cards.to_json, contexts: [order_select_context].to_json)
    expect(result.result).to eq('fail')
    expect(entity_result_message.message).to match(/must reference FHIR resource from the `draftOrders`/)
  end

  it 'fails if there is no create action for the order being deleted' do
    dup_cards = cards_with_suggestions.deep_dup
    action = dup_cards.first['suggestions'].first['actions'].find { |act| act['type'] == 'create' }
    action['resource']['resourceType'] = 'ServiceRequest'

    result = run(runnable, valid_cards_with_suggestions: dup_cards.to_json, contexts: [order_select_context].to_json)
    expect(result.result).to eq('fail')
    expect(entity_result_message.message).to match(/There's no `create` action/)
  end
end
