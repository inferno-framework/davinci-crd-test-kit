require_relative '../../../../../lib/davinci_crd_test_kit/client/v2.2.1/registration/client_registration_verification_test' # rubocop:disable Layout/LineLength

RSpec.describe DaVinciCRDTestKit::V221::CRDClientRegistrationVerification do
  let(:suite_id) { 'crd_client_v221' }
  let(:test) { described_class }
  let(:results_repo) { Inferno::Repositories::Results.new }

  let(:jwks_hash) { JSON.parse(DaVinciCRDTestKit::JWKS.jwks_json) }
  let(:example_jwks_url) { 'https://cds.example.org/jwks.json' }
  let(:complete_org_id) { 'complete-org-1' }
  let(:subset_org_id) { 'subset-org-2' }
  let(:jwt_iss) { 'https://cds.example.org' }

  def result_messages
    results_repo.current_results_for_test_session_and_runnables(test_session.id, [test])
      .first
      .messages
  end

  def run_with_defaults(cds_jwk_set: jwks_hash.to_json,
                        complete_prefetch_service_organization_id: complete_org_id,
                        subset_prefetch_service_organization_id: subset_org_id)
    run(test,
        cds_jwt_iss: jwt_iss,
        cds_jwk_set:,
        complete_prefetch_service_organization_id:,
        subset_prefetch_service_organization_id:)
  end

  it 'passes with valid raw JWKS and distinct organization ids' do
    result = run_with_defaults
    expect(result.result).to eq('pass')
  end

  it 'passes with JWKS provided as a URL' do
    stub_request(:get, example_jwks_url).to_return(status: 200, body: jwks_hash.to_json)
    result = run_with_defaults(cds_jwk_set: example_jwks_url)
    expect(result.result).to eq('pass')
  end

  [Net::ReadTimeout, Net::OpenTimeout].each do |timeout_error|
    it "fails, rather than errors, when retrieving the JWKS URL raises #{timeout_error}" do
      stub_request(:get, example_jwks_url).to_raise(timeout_error)
      result = run_with_defaults(cds_jwk_set: example_jwks_url)
      expect(result.result).to eq('fail')
      expect(result_messages.map(&:message))
        .to include("Timed out waiting for a response from JWKS URL `#{example_jwks_url}`.")
      expect(result_messages.map(&:message)).to include(include('does not include any valid keys'))
    end
  end

  it 'fails, rather than errors, when the JWKS URL refuses the connection' do
    stub_request(:get, example_jwks_url).to_raise(Errno::ECONNREFUSED)
    result = run_with_defaults(cds_jwk_set: example_jwks_url)
    expect(result.result).to eq('fail')
    expect(result_messages.map(&:message)).to include(start_with("Failed to fetch JWKS from #{example_jwks_url}:"))
  end

  it 'fails, rather than errors, when the JWKS content is not a JSON object' do
    stub_request(:get, example_jwks_url).to_return(status: 200, body: jwks_hash['keys'].to_json)
    [example_jwks_url, '5'].each do |cds_jwk_set|
      result = run_with_defaults(cds_jwk_set:)
      expect(result.result).to eq('fail')
      expect(result_messages.map(&:message)).to include('JWKS content is not a JSON object.')
    end
  end

  it 'fails, rather than errors, when the JWKS input is neither JSON nor a URL' do
    ['{"keys": [}', 'not a url', 'example.com/jwks'].each do |cds_jwk_set|
      result = run_with_defaults(cds_jwk_set:)
      expect(result.result).to eq('fail')
      expect(result_messages.map(&:message))
        .to include('JWKS input is neither a valid JSON Web Key Set nor an http(s) URL.')
    end
  end

  it 'limits how long it waits for the JWKS URL' do
    stub_request(:get, example_jwks_url).to_return(status: 200, body: jwks_hash.to_json)
    allow(Faraday).to receive(:new).and_call_original
    run_with_defaults(cds_jwk_set: example_jwks_url)
    expect(Faraday).to have_received(:new).with(request: { open_timeout: 10, timeout: 10 })
  end

  it 'fails when no JWKS is provided' do
    result = run_with_defaults(cds_jwk_set: nil)
    expect(result.result).to eq('fail')
    expect(result_messages.map(&:message)).to include(include('CRD JSON Web Key Set'))
  end

  it 'fails when JWKS contains no valid keys' do
    empty_jwks = { 'keys' => [] }.to_json
    result = run_with_defaults(cds_jwk_set: empty_jwks)
    expect(result.result).to eq('fail')
    expect(result_messages.map(&:message)).to include(include('does not include any valid keys'))
  end

  it 'adds a warning when JWKS is provided as raw JSON rather than a URL' do
    result = run_with_defaults
    expect(result.result).to eq('pass')
    expect(result_messages.map(&:message)).to include(include('strongly discouraged'))
  end

  it 'fails when both organization ids are the same' do
    result = run_with_defaults(
      complete_prefetch_service_organization_id: 'same-org',
      subset_prefetch_service_organization_id: 'same-org'
    )
    expect(result.result).to eq('fail')
    expect(result_messages.map(&:message)).to include(include('unique Organization id'))
  end

  it 'passes when organization ids differ' do
    result = run_with_defaults(
      complete_prefetch_service_organization_id: 'org-a',
      subset_prefetch_service_organization_id: 'org-b'
    )
    expect(result.result).to eq('pass')
  end

  describe 'invalid keys in the JWKS' do
    let(:invalid_key_with_kid) { { 'kty' => 'unknown', 'kid' => 'bad-key' } }
    let(:invalid_key_without_kid) { { 'kty' => 'unknown' } }

    def jwks_with(*extra_keys)
      { 'keys' => jwks_hash['keys'] + extra_keys }.to_json
    end

    it 'warns about an invalid key, naming it by its kid, and still passes with the valid keys' do
      result = run_with_defaults(cds_jwk_set: jwks_with(invalid_key_with_kid))

      expect(result.result).to eq('pass')
      warning = result_messages.find { |message| message.message.start_with?('Key bad-key invalid:') }
      expect(warning).to be_present
      expect(warning.type).to eq('warning')
    end

    it 'warns about an invalid key without a kid, naming it by its position in the key set' do
      result = run_with_defaults(cds_jwk_set: jwks_with(invalid_key_without_kid))

      expect(result.result).to eq('pass')
      expect(result_messages.map(&:message))
        .to include(start_with("Key #{jwks_hash['keys'].length} invalid:"))
    end

    it 'fails when every key in the JWKS is invalid' do
      result = run_with_defaults(cds_jwk_set: { 'keys' => [invalid_key_with_kid] }.to_json)

      expect(result.result).to eq('fail')
      messages = result_messages.map(&:message)
      expect(messages).to include(start_with('Key bad-key invalid:'))
      expect(messages).to include(include('does not include any valid keys'))
    end
  end

  it 'fails for both missing JWKS and duplicate organization ids simultaneously' do
    result = run_with_defaults(
      cds_jwk_set: nil,
      complete_prefetch_service_organization_id: 'same-org',
      subset_prefetch_service_organization_id: 'same-org'
    )
    expect(result.result).to eq('fail')
    messages = result_messages.map(&:message)
    expect(messages).to include(include('CRD JSON Web Key Set'))
    expect(messages).to include(include('unique Organization id'))
  end
end
