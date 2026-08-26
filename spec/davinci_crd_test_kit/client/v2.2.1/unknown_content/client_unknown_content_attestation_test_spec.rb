RSpec.describe DaVinciCRDTestKit::V221::ClientUnknownContentAttestationTest, :request do
  let(:suite_id) { 'crd_client_v221' }
  let(:test) { described_class }
  let(:results_repo) { Inferno::Repositories::Results.new }

  let(:base_url) { "#{Inferno::Application['base_url']}/custom/crd_client_v221" }
  let(:known_token) { 'abc123' }
  let(:attest_true_url) { "#{base_url}/resume_pass?token=#{known_token}" }
  let(:attest_false_url) { "#{base_url}/resume_fail?token=#{known_token}" }

  let(:coverage_info_system_action) do
    JSON.parse(File.read(File.join(
                           __dir__, '..', '..', '..', '..', 'fixtures',
                           'coverage_info_system_action_complete.json'
                         )))
  end
  let(:unknown_content_request) do
    Inferno::Entities::Request.new(
      response_body: {
        cards: [],
        systemActions: [coverage_info_system_action.merge('qwertyuiopasdfgh' => 'zxcvbnmlkjhgfdsa')],
        extension: { 'poiuytrewqlkjhgf' => 'mnbvcxzasdfghjkl' }
      }.to_json
    )
  end

  before do
    allow(SecureRandom).to receive(:hex).and_return(known_token)
  end

  it 'skips when no requests were sent during the previous wait' do
    allow_any_instance_of(test).to receive(:load_interaction_group_requests).and_return([])

    result = run(test)

    expect(result.result).to eq('skip')
    expect(result.result_message).to match(/no hook requests sent during the previous wait/)
  end

  it 'skips when no coverage information system action was returned' do
    allow_any_instance_of(test).to receive(:load_interaction_group_requests).and_return(
      [Inferno::Entities::Request.new(response_body: { cards: [], systemActions: [] }.to_json)]
    )

    result = run(test)

    expect(result.result).to eq('skip')
    expect(result.result_message).to match(/no coverage information system action was returned/)
  end

  it 'enters wait state and lists the unknown content returned' do
    allow_any_instance_of(test).to receive(:load_interaction_group_requests).and_return([unknown_content_request])

    result = run(test)

    expect(result.result).to eq('wait')
    expect(result.result_message).to match(/System action element name: `qwertyuiopasdfgh`/)
    expect(result.result_message).to match(/Response extension name: `poiuytrewqlkjhgf`/)
  end

  it 'passes when the user attests true' do
    allow_any_instance_of(test).to receive(:load_interaction_group_requests).and_return([unknown_content_request])

    result = run(test)
    expect(result.result).to eq('wait')

    get(attest_true_url)

    result = results_repo.find(result.id)
    expect(result.result).to eq('pass')
  end

  it 'fails when the user attests false' do
    allow_any_instance_of(test).to receive(:load_interaction_group_requests).and_return([unknown_content_request])

    result = run(test)
    expect(result.result).to eq('wait')

    get(attest_false_url)

    result = results_repo.find(result.id)
    expect(result.result).to eq('fail')
  end
end
