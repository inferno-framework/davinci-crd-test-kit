RSpec.describe DaVinciCRDTestKit::V221::LaunchSmartAppCardValidationTest do
  let(:suite_id) { 'crd_client' }
  let(:runnable) { described_class }
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:valid_cards) do
    json = File.read(File.join(__dir__, '..', '..', '..', '..', 'fixtures', 'valid_cards.json'))
    JSON.parse(json)
  end
  let(:valid_cards_with_links) { valid_cards.filter { |card| card['links'].present? } }

  def entity_result_message
    results_repo.current_results_for_test_session_and_runnables(test_session.id, [runnable])
      .first
      .messages
      .first
  end

  it 'passes if cards contain a valid Launch SMART App card' do
    result = run(runnable, valid_cards_with_links: valid_cards_with_links.to_json)
    expect(result.result).to eq('pass'), result.result_message
  end

  it 'fails if valid_cards_with_links is not json' do
    result = run(runnable, valid_cards_with_links: '[[')
    expect(result.result).to eq('fail'), result.result_message
    expect(result.result_message).to match(/Invalid JSON/)
  end

  it 'skips if no Launch SMART App card present' do
    valid_cards_with_links.reject! do |card|
      card['links'].any? { |link| link['type'] == 'smart' }
    end
    result = run(runnable, valid_cards_with_links: valid_cards_with_links.to_json)
    expect(result.result).to eq('skip'), result.result_message
    expect(result.result_message).to match(/does not contain any Launch SMART App cards/)
  end

  it 'fails if the Launch SMART App card is not valid' do
    valid_cards_with_links.reject! do |card|
      card['links'].any? { |link| link['type'] != 'smart' }
    end

    valid_cards_with_links.first.delete('suggestions')
    result = run(runnable, valid_cards_with_links: valid_cards_with_links.to_json)
    expect(result.result).to eq('fail'), result.result_message
    expect(result.result_message).to match(/Not all Launch SMART App/)
    expect(entity_result_message.message).to match(/must contain at least one suggestion/)
  end
end
