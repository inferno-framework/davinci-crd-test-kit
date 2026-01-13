RSpec.describe DaVinciCRDTestKit::ClientCardMustSupportInstructionsTest do
  let(:suite_id) { 'crd_client' }
  let(:runnable) { described_class }

  let(:order_sign_hook_request) do
    File.read(File.join(
                __dir__, '..', 'fixtures', 'order_sign_hook_request.json'
              ))
  end
  let(:order_sign_hook_response) do
    {
      cards: [
        JSON.parse(File.read(File.join(
                               __dir__, '..', '..', 'lib', 'davinci_crd_test_kit', 'card_responses', 'instructions.json'
                             )))
      ],
      systemActions: []
    }.to_json
  end

  describe 'When checking instructions cards' do
    it 'fails when no instructions cards are found' do
      allow_any_instance_of(described_class)
        .to receive(:requests_to_analyze).and_return([])

      result = run(runnable)
      expect(result.result).to eq('fail')
      expect(result.result_message).to match(/Instructions card support not demonstrated./)
    end

    it 'passes when an instructions card is present' do
      allow_any_instance_of(described_class)
        .to receive(:requests_to_analyze).and_return(
          [Inferno::Entities::Request.new(
            request_body: order_sign_hook_request,
            response_body: order_sign_hook_response
          )]
        )

      result = run(runnable)
      expect(result.result).to eq('pass')
    end
  end
end
