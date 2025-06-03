RSpec.describe DaVinciCRDTestKit::InstructionsCardReceivedAcrossHooksTest do
  let(:suite_id) { 'crd_server' }
  let(:runnable_across) do
    id = 'crd_server-crd_server_hooks-crd_server_required_card_response_validation' \
         '-crd_valid_instructions_card_received_across_hooks'
    Inferno::Repositories::Tests.new.find(id)
  end
  let(:runnable_within) do
    Inferno::Repositories::Tests.new
      .find('crd_server-crd_server_hooks-crd_server_order_dispatch-crd_valid_instructions_card_received')
  end
  let(:valid_response_body) do
    File.read(File.join(__dir__, '..', 'fixtures', 'crd_authorization_hook_response.json'))
  end
  let(:cards) do
    JSON.parse(valid_response_body)['cards']
  end
  let(:base_url) { 'http://example.com/' }

  it 'passes if an Instructions card is present' do
    run(runnable_within, order_dispatch_valid_cards: cards.to_json, base_url:)
    result = run(runnable_across)
    expect(result.result).to eq('pass')
  end

  it 'skips if no instructions card present' do
    run(runnable_within, order_dispatch_valid_cards: [].to_json, base_url:)
    result = run(runnable_across)
    expect(result.result).to eq('skip')
    expect(result.result_message).to match(/None of the hooks invoked returned a valid Instructions card/)
  end
end
