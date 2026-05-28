RSpec.describe DaVinciCRDTestKit::V221::ExternalReferenceCardValidationTest do
  let(:suite_id) { 'crd_server' }
  let(:runnable) { described_class }
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:valid_response_body) do
    File.read(File.join(__dir__, '..', '..', '..', '..', 'fixtures', 'crd_authorization_hook_response.json'))
  end
  let(:cards) { JSON.parse(valid_response_body)['cards'] }
  let(:external_ref_card) { cards.find { |card| card['links'].present? } }
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

  it 'passes if cards contain a valid external reference card' do
    result = run(runnable, valid_cards_with_links: [external_ref_card].to_json)
    expect(result.result).to eq('pass')
  end

  it 'fails if valid_cards_with_links is not json' do
    result = run(runnable, valid_cards_with_links: '[[')
    expect(result.result).to eq('fail')
    expect(result.result_message).to match(/Invalid JSON/)
  end

  it 'skips if no External Reference card present' do
    valid_cards_with_links.reject! do |card|
      card['links'].any? { |link| link['type'] == 'absolute' }
    end
    result = run(runnable, valid_cards_with_links: valid_cards_with_links.to_json)
    expect(result.result).to eq('skip'), result.result_message
    expect(result.result_message).to match(/does not contain any External Reference cards/)
  end

  it 'fails if the Launch SMART App card is not valid' do
    valid_cards_with_links.reject! do |card|
      card['links'].any? { |link| link['type'] != 'absolute' }
    end

    valid_cards_with_links.first['suggestions'] = { label: 'LABEL' }
    result = run(runnable, valid_cards_with_links: valid_cards_with_links.to_json)
    expect(result.result).to eq('fail'), result.result_message
    expect(result.result_message).to match(/Not all External Reference/)
    expect(entity_result_message.message).to match(/must not contain suggestions/)
  end
end
