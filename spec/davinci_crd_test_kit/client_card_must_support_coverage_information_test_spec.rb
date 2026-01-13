RSpec.describe DaVinciCRDTestKit::ClientCardMustSupportCoverageInformationTest do
  let(:suite_id) { 'crd_client' }
  let(:runnable) { described_class }

  let(:order_sign_hook_request) do
    File.read(File.join(
                __dir__, '..', 'fixtures', 'order_sign_hook_request.json'
              ))
  end
  let(:order_sign_hook_response_covered) do
    {
      cards: [],
      systemActions: [JSON.parse(File.read(File.join(
                                             __dir__, '..', 'fixtures', 'coverage_info_system_action_covered.json'
                                           )))]
    }.to_json
  end
  let(:order_sign_hook_response_conditional) do
    {
      cards: [],
      systemActions: [JSON.parse(File.read(File.join(
                                             __dir__, '..', 'fixtures', 'coverage_info_system_action_conditional.json'
                                           )))]
    }.to_json
  end

  describe 'When checking coverage information actions' do
    it 'fails when no coverage information actions are found' do
      allow_any_instance_of(described_class)
        .to receive(:requests_to_analyze).and_return([])

      result = run(runnable)
      expect(result.result).to eq('fail')
      expect(result.result_message).to match(/Coverage Information action support not demonstrated./)
    end

    it 'fails when some must support elements are missing' do
      allow_any_instance_of(described_class)
        .to receive(:requests_to_analyze).and_return(
          [Inferno::Entities::Request.new(
            request_body: order_sign_hook_request,
            response_body: order_sign_hook_response_covered
          )]
        )

      result = run(runnable)
      expect(result.result).to eq('fail')
      expect(result.result_message).to match(/Extension.extension:doc-needed/)
      expect(result.result_message).to match(/Extension.extension:doc-purpose/)
      expect(result.result_message).to match(/Extension.extension:info-needed/)
    end

    it 'passes when all must support elements are present' do
      allow_any_instance_of(described_class)
        .to receive(:requests_to_analyze).and_return(
          [Inferno::Entities::Request.new(
            request_body: order_sign_hook_request,
            response_body: order_sign_hook_response_covered
          ), Inferno::Entities::Request.new(
            request_body: order_sign_hook_request,
            response_body: order_sign_hook_response_conditional
          )]
        )

      result = run(runnable)
      expect(result.result).to eq('pass')
    end
  end
end
