RSpec.describe DaVinciCRDTestKit::FormCompletionResponseValidationTest do
  let(:suite_id) { 'crd_client' }
  let(:runnable) { described_class }
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:valid_cards) do
    json = File.read(File.join(__dir__, '..', 'fixtures', 'valid_cards.json'))
    JSON.parse(json)
  end
  let(:cards_with_suggestions) { valid_cards.filter { |card| card['suggestions'].present? } }
  let(:valid_system_actions) do
    cards_with_suggestions.filter { |card| card['summary'].include?('Request Form Completion') }
      .flat_map { |card| card['suggestions'].flat_map { |suggestion| suggestion['actions'] } }
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

  it 'passes if valid request form completion cards are received' do
    result = run(runnable, valid_cards_with_suggestions: cards_with_suggestions.to_json,
                           valid_system_actions: [].to_json)

    expect(result.result).to eq('pass')
  end

  it 'passes if valid request form completion system actions are received' do
    result = run(runnable, valid_cards_with_suggestions: [].to_json, valid_system_actions: valid_system_actions.to_json)

    expect(result.result).to eq('pass')
  end

  it 'skips if valid_cards_with_suggestions not present' do
    result = run(runnable, valid_system_actions: [].to_json)
    expect(result.result).to eq('skip')
    expect(result.result_message).to match(/'valid_cards_with_suggestions' is nil, skipping test/)
  end

  it 'skips if valid_system_actions not present' do
    result = run(runnable, valid_cards_with_suggestions: cards_with_suggestions.to_json)
    expect(result.result).to eq('skip')
    expect(result.result_message).to match(/'valid_system_actions' is nil, skipping test/)
  end

  it 'fails if valid_cards_with_suggestions is not valid json' do
    result = run(runnable, valid_cards_with_suggestions: '[[', valid_system_actions: [].to_json)
    expect(result.result).to eq('fail')
    expect(result.result_message).to match(/Invalid JSON/)
  end

  it 'fails if valid_system_actions is not valid json' do
    result = run(runnable, valid_cards_with_suggestions: [].to_json, valid_system_actions: '[[')
    expect(result.result).to eq('fail')
    expect(result.result_message).to match(/Invalid JSON/)
  end

  it 'skips if no request form completion card or system action present' do
    dup_cards = cards_with_suggestions.deep_dup
    dup_cards.reject! { |card| card['summary'].include?('Form Completion') }

    result = run(runnable, valid_cards_with_suggestions: dup_cards.to_json, valid_system_actions: [].to_json)
    expect(result.result).to eq('skip')
    expect(result.result_message).to match(/does not contain any Request Form Completion cards or system actions/)
  end
end
