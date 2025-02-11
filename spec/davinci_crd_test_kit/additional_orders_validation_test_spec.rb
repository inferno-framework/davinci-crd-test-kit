RSpec.describe DaVinciCRDTestKit::AdditionalOrdersValidationTest do
  let(:suite_id) { 'crd_server' }
  let(:runnable) { described_class }
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:valid_cards) do
    json = File.read(File.join(__dir__, '..', 'fixtures', 'valid_cards.json'))
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
    expect(result.result).to eq('pass')
  end

  it 'skips if valid_cards_with_suggestions not present' do
    result = run(runnable)
    expect(result.result).to eq('skip')
    expect(result.result_message).to match(/'valid_cards_with_suggestions' is nil, skipping test/)
  end

  it 'fails if valid_cards_with_suggestions is not valid json' do
    result = run(runnable, valid_cards_with_suggestions: '[[')
    expect(result.result).to eq('fail')
    expect(result.result_message).to match(/Invalid JSON/)
  end

  it 'skips if no additional orders as companions card present' do
    dup_cards = cards_with_suggestions.deep_dup
    dup_cards.reject! { |card| card['summary'].include?('Additional Orders As Companions') }

    result = run(runnable, valid_cards_with_suggestions: dup_cards.to_json)
    expect(result.result).to eq('skip')
    expect(result.result_message).to match(%r{does not include Additional Orders as companion/prerequisite cards})
  end
end
