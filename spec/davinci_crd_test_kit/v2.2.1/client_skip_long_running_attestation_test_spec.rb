RSpec.describe DaVinciCRDTestKit::V221::ClientSkipLongRunningAttestationTest, :request do
  let(:suite_id) { 'crd_client_v221' }
  let(:test) { described_class }
  let(:results_repo) { Inferno::Repositories::Results.new }

  let(:base_url) { "#{Inferno::Application['base_url']}/custom/crd_client_v221" }
  let(:known_token) { 'abc123' }
  let(:attest_true_url) { "#{base_url}/resume_pass?token=#{known_token}" }
  let(:attest_false_url) { "#{base_url}/resume_fail?token=#{known_token}" }

  before do
    allow(SecureRandom).to receive(:hex).and_return(known_token)
  end

  it 'skips when no long-running requests were sent during the previous wait' do
    allow_any_instance_of(test).to receive(:load_hook_requests).and_return([])

    result = run(test)

    expect(result.result).to eq('skip')
    expect(result.result_message).to match(/no hook requests sent during the previous wait/)
  end

  it 'enters wait state when long-running requests exist' do
    allow_any_instance_of(test).to receive(:load_hook_requests).and_return(['stub_request'])

    result = run(test)

    expect(result.result).to eq('wait')
  end

  it 'passes when the user attests true' do
    allow_any_instance_of(test).to receive(:load_hook_requests).and_return(['stub_request'])

    result = run(test)
    expect(result.result).to eq('wait')

    get(attest_true_url)

    result = results_repo.find(result.id)
    expect(result.result).to eq('pass')
  end

  it 'fails when the user attests false' do
    allow_any_instance_of(test).to receive(:load_hook_requests).and_return(['stub_request'])

    result = run(test)
    expect(result.result).to eq('wait')

    get(attest_false_url)

    result = results_repo.find(result.id)
    expect(result.result).to eq('fail')
  end
end
