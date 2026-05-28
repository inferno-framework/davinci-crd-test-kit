RSpec.describe DaVinciCRDTestKit::V221::ClientHookResponseSupportCoverageInformationTest do
  let(:suite_id) { 'crd_client_v221' }
  let(:runnable) { described_class }

  let(:order_sign_hook_request) do
    File.read(File.join(
                __dir__, '..', '..', '..', '..', 'fixtures', 'order_sign_hook_request.json'
              ))
  end
  let(:order_sign_hook_response_with_coverage_info) do
    {
      cards: [],
      systemActions: [JSON.parse(File.read(File.join(
                                             __dir__, '..', '..', '..', '..', 'fixtures',
                                             'coverage_info_system_action_complete.json'
                                           )))]
    }.to_json
  end

  describe 'When checking coverage information actions' do
    it 'skips when no hook requests have been received' do
      result = run(runnable)
      expect(result.result).to eq('skip')
      expect(result.result_message).to match(/No.*hook requests received/)
    end

    it 'fails when no coverage information actions are found' do
      allow_any_instance_of(described_class)
        .to receive(:load_hook_requests).and_return(
          [Inferno::Entities::Request.new(
            request_body: order_sign_hook_request,
            response_body: { cards: [], systemActions: [] }.to_json
          )]
        )

      result = run(runnable)
      expect(result.result).to eq('fail')
      expect(result.result_message).to match(/Support for the Coverage Information response type not demonstrated/)
    end

    it 'passes when a coverage information action is present' do
      allow_any_instance_of(described_class)
        .to receive(:load_hook_requests).and_return(
          [Inferno::Entities::Request.new(
            request_body: order_sign_hook_request,
            response_body: order_sign_hook_response_with_coverage_info
          )]
        )

      result = run(runnable)
      expect(result.result).to eq('pass')
    end
  end
end
