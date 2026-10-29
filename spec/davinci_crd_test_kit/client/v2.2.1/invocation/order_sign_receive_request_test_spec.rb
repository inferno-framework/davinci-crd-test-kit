require_relative '../../../../../lib/davinci_crd_test_kit/client/v2.2.1/invocation/order_sign_receive_request_test'

RSpec.describe DaVinciCRDTestKit::V221::OrderSignReceiveRequestTest, :request do
  let(:suite_id) { 'crd_client_v221' }
  let(:test) { described_class }
  let(:example_client_url) { 'https://cds.example.org' }

  it 'lists the payer organization ids in the wait dialog when provided' do
    result = run(test, cds_jwt_iss: example_client_url, order_sign_response_approach: 'mocked',
                       complete_prefetch_service_organization_id: 'org-complete',
                       subset_prefetch_service_organization_id: 'org-subset')

    expect(result.result).to eq('wait')
    expect(result.result_message).to include('associated with payer `Organization/org-complete`')
    expect(result.result_message).to include('associated with payer `Organization/org-subset`')
  end

  it 'omits the payer organization notes when the ids are not provided' do
    result = run(test, cds_jwt_iss: example_client_url, order_sign_response_approach: 'mocked')

    expect(result.result).to eq('wait')
    expect(result.result_message).to_not include('associated with payer')
  end

  describe 'mocked response types in the wait dialog' do
    it 'lists only Coverage Information when no types are selected' do
      result = run(test, cds_jwt_iss: example_client_url, order_sign_response_approach: 'mocked',
                         order_sign_selected_response_types: [])

      expect(result.result).to eq('wait')
      expect(result.result_message).to include("- Coverage Information (systemAction)\n")
      expect(result.result_message).to_not include('Instructions (card)')
    end

    it 'adds Coverage Information when it is not selected' do
      result = run(test, cds_jwt_iss: example_client_url, order_sign_response_approach: 'mocked',
                         order_sign_selected_response_types: ['instructions'])

      expect(result.result).to eq('wait')
      expect(result.result_message).to include("- Instructions (card)\n- Coverage Information (systemAction)")
    end

    it 'lists Coverage Information once when it is selected' do
      result = run(test, cds_jwt_iss: example_client_url, order_sign_response_approach: 'mocked',
                         order_sign_selected_response_types: ['coverage_information', 'instructions'])

      expect(result.result).to eq('wait')
      expect(result.result_message.scan('Coverage Information (systemAction)').length).to eq(1)
    end
  end
end
