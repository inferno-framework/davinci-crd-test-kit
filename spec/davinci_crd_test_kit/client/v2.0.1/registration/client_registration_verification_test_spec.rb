require_relative '../../../../../lib/davinci_crd_test_kit/client/v2.0.1/registration/client_registration_verification_test' # rubocop:disable Layout/LineLength

RSpec.describe DaVinciCRDTestKit::V201::CRDClientRegistrationVerification do
  let(:suite_id) { 'crd_client' }
  let(:test) { described_class }
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:jwks_hash) { JSON.parse(DaVinciCRDTestKit::JWKS.jwks_json) }

  def result_messages
    results_repo.current_results_for_test_session_and_runnables(test_session.id, [test]).first.messages
  end

  def run_with_jwks(jwks)
    run(test, cds_jwt_iss: 'https://cds.example.org', cds_jwk_set: jwks.to_json)
  end

  it 'passes with a valid raw JWKS' do
    expect(run_with_jwks(jwks_hash).result).to eq('pass')
  end

  it 'warns about an invalid key, naming it by its kid, and still passes with the valid keys' do
    result = run_with_jwks({ 'keys' => jwks_hash['keys'] + [{ 'kty' => 'unknown', 'kid' => 'bad-key' }] })

    expect(result.result).to eq('pass')
    warning = result_messages.find { |message| message.message.start_with?('Key bad-key invalid:') }
    expect(warning).to be_present
    expect(warning.type).to eq('warning')
  end

  it 'warns about an invalid key without a kid, naming it by its position in the key set' do
    result = run_with_jwks({ 'keys' => jwks_hash['keys'] + [{ 'kty' => 'unknown' }] })

    expect(result.result).to eq('pass')
    expect(result_messages.map(&:message)).to include(start_with("Key #{jwks_hash['keys'].length} invalid:"))
  end

  it 'fails when every key in the JWKS is invalid' do
    result = run_with_jwks({ 'keys' => [{ 'kty' => 'unknown', 'kid' => 'bad-key' }] })

    expect(result.result).to eq('fail')
    expect(result.result_message).to include('does not include any valid keys')
    expect(result_messages.map(&:message)).to include(start_with('Key bad-key invalid:'))
  end
end
