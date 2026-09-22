RSpec.describe DaVinciCRDTestKit::V221::ClientSelfPayNoRequestTest do
  let(:suite_id) { 'crd_client_v221' }
  let(:test) { described_class }

  it 'passes when no hook requests were sent during the previous wait' do
    allow_any_instance_of(test).to receive(:load_interaction_group_requests).and_return([])

    result = run(test)

    expect(result.result).to eq('pass')
  end

  it 'fails when a hook request was sent during the previous wait' do
    allow_any_instance_of(test).to receive(:load_interaction_group_requests).and_return(['stub_request'])

    result = run(test)

    expect(result.result).to eq('fail')
    expect(result.result_message).to include('incorrectly received a hook request')
  end

  it 'fails when multiple hook requests were sent during the previous wait' do
    allow_any_instance_of(test).to receive(:load_interaction_group_requests)
      .and_return(['stub_request', 'stub_request'])

    result = run(test)

    expect(result.result).to eq('fail')
    expect(result.result_message).to include('incorrectly received a hook request')
  end
end
