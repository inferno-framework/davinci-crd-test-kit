RSpec.describe DaVinciCRDTestKit::ExternalReferenceCardValidationTest do
  let(:suite_id) { 'crd_server' }
  let(:runnable) { described_class }
  let(:valid_response_body) do
    File.read(File.join(__dir__, '..', 'fixtures', 'crd_authorization_hook_response.json'))
  end
  let(:cards) { JSON.parse(valid_response_body)['cards'] }
  let(:external_ref_card) { cards.find { |card| card['links'].present? } }

  it 'passes if cards contain a valid external reference card' do
    result = run(runnable, valid_cards_with_links: [external_ref_card].to_json)
    expect(result.result).to eq('pass')
  end

  it 'skips if valid_cards_with_links not present' do
    result = run(runnable)
    expect(result.result).to eq('skip')
    expect(result.result_message).to match(/'valid_cards_with_links' is nil, skipping test/)
  end

  it 'fails if valid_cards_with_links is not json' do
    result = run(runnable, valid_cards_with_links: '[[')
    expect(result.result).to eq('fail')
    expect(result.result_message).to match(/Invalid JSON/)
  end

  it 'fails if no external reference card present' do
    result = run(runnable, valid_cards_with_links: [].to_json)
    expect(result.result).to eq('fail')
    expect(result.result_message).to match(/did not contain an External Reference card/)
  end
end
