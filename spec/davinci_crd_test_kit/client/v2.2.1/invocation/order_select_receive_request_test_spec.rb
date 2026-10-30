require_relative '../../../../../lib/davinci_crd_test_kit/client/v2.2.1/invocation/order_select_receive_request_test'

RSpec.describe DaVinciCRDTestKit::V221::OrderSelectReceiveRequestTest, :request do
  let(:suite_id) { 'crd_client_v221' }
  let(:test) { described_class }
  let(:example_client_url) { 'https://cds.example.org' }

  describe 'mocked response types in the wait dialog' do
    it 'lists only Instructions when no types are selected' do
      result = run(test, cds_jwt_iss: example_client_url, order_select_response_approach: 'mocked',
                         order_select_selected_response_types: [])

      expect(result.result).to eq('wait')
      expect(result.result_message).to include("- Instructions (card)\n")
      expect(result.result_message).to_not include('Coverage Information')
    end

    it 'does not add Coverage Information when it is not selected' do
      result = run(test, cds_jwt_iss: example_client_url, order_select_response_approach: 'mocked',
                         order_select_selected_response_types: ['external_reference'])

      expect(result.result).to eq('wait')
      expect(result.result_message).to include("- External Reference (card)\n")
      expect(result.result_message).to_not include('Coverage Information')
    end
  end
end
