require_relative '../../../../../lib/davinci_crd_test_kit/client/v2.2.1/invocation/cross_hooks_receive_request_test'

RSpec.describe DaVinciCRDTestKit::V221::CrossHooksReceiveRequestTest, :request do
  let(:suite_id) { 'crd_client_v221' }
  let(:test) { described_class }
  let(:example_client_url) { 'https://cds.example.org' }
  let(:coverage_information_note) do
    '- Coverage Information (systemAction) on `appointment-book`, `order-sign`, and `order-dispatch` requests'
  end

  def run_with_selected_types(selected_types)
    run(test, cds_jwt_iss: example_client_url, make_additional_hook_requests: 'true',
              cross_hooks_response_approach: 'mocked', cross_hooks_selected_response_types: selected_types)
  end

  describe 'mocked response types in the wait dialog' do
    it 'describes Coverage Information on primary hooks and Instructions elsewhere when no types are selected' do
      result = run_with_selected_types([])

      expect(result.result).to eq('wait')
      expect(result.result_message)
        .to include("#{coverage_information_note}\n- Instructions (card) on other hook requests")
    end

    it 'adds the primary hook Coverage Information note when it is not selected' do
      result = run_with_selected_types(['instructions'])

      expect(result.result).to eq('wait')
      expect(result.result_message).to include("- Instructions (card)\n#{coverage_information_note}")
    end

    it 'lists Coverage Information without the primary hook note when it is selected' do
      result = run_with_selected_types(['coverage_information', 'instructions'])

      expect(result.result).to eq('wait')
      expect(result.result_message).to include("- Coverage Information (systemAction)\n- Instructions (card)")
      expect(result.result_message).to_not include(coverage_information_note)
    end
  end
end
