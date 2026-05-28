RSpec.describe DaVinciCRDTestKit::V221::AdditionalOrdersValidationTest do
  let(:suite_id) { 'crd_server' }
  let(:runnable) { described_class }
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:valid_cards) do
    json = File.read(File.join(__dir__, '..', '..', '..', '..', 'fixtures', 'valid_cards.json'))
    JSON.parse(json)
  end
  let(:cards_with_suggestions) { valid_cards.filter { |card| card['suggestions'].present? } }

  def entity_result_message
    results_repo.current_results_for_test_session_and_runnables(test_session.id, [runnable])
      .first
      .messages
      .first
  end

  before do
    allow_any_instance_of(runnable).to receive(:resource_is_valid?).and_return(true)
  end

  it 'passes if valid additional orders as companions cards are received' do
    result = run(runnable, valid_cards_with_suggestions: cards_with_suggestions.to_json)
    expect(result.result).to eq('pass'), result.result_message
  end

  it 'fails if valid_cards_with_suggestions is not valid json' do
    result = run(runnable, valid_cards_with_suggestions: '[[')
    expect(result.result).to eq('fail'), result.result_message
    expect(result.result_message).to match(/Invalid JSON/)
  end

  it 'fails if additional orders card has errors' do
    cards_with_suggestions[2]['suggestions'].first['actions'].first['resourceId'] = '123'

    result = run(runnable, valid_cards_with_suggestions: cards_with_suggestions.to_json)
    expect(result.result).to eq('fail'), result.result_message
    expect(result.result_message).to match(/Additional Order cards are not valid/)
    expect(entity_result_message.message).to match(/`resourceId` should not be populated/)
  end

  it 'skips if no additional orders as companions card present' do
    dup_cards = cards_with_suggestions.deep_dup
    dup_cards.reject! { |card| card['summary'].include?('Additional Orders As Companions') }

    result = run(runnable, valid_cards_with_suggestions: dup_cards.to_json)
    expect(result.result).to eq('skip'), result.result_message
    expect(result.result_message).to match(%r{does not include Additional Orders as companion/prerequisite cards})
  end
end
