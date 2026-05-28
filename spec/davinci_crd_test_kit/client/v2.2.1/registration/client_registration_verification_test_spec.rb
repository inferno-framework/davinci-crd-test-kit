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

  it 'fails when no JWKS is provided' do
    result = run_with_defaults(cds_jwk_set: nil)
    expect(result.result).to eq('fail')
    expect(result_messages.map(&:message)).to include(match(/CRD JSON Web Key Set/))
  end

  it 'fails when JWKS contains no valid keys' do
    empty_jwks = { 'keys' => [] }.to_json
    result = run_with_defaults(cds_jwk_set: empty_jwks)
    expect(result.result).to eq('fail')
    expect(result_messages.map(&:message)).to include(match(/does not include any valid keys/))
  end

  it 'adds a warning when JWKS is provided as raw JSON rather than a URL' do
    result = run_with_defaults
    expect(result.result).to eq('pass')
    expect(result_messages.map(&:message)).to include(match(/strongly discouraged/))
  end

  it 'fails when both organization ids are the same' do
    result = run_with_defaults(
      complete_prefetch_service_organization_id: 'same-org',
      subset_prefetch_service_organization_id: 'same-org'
    )
    expect(result.result).to eq('fail')
    expect(result_messages.map(&:message)).to include(match(/unique Organization id/))
  end

  it 'passes when organization ids differ' do
    result = run_with_defaults(
      complete_prefetch_service_organization_id: 'org-a',
      subset_prefetch_service_organization_id: 'org-b'
    )
    expect(result.result).to eq('pass')
  end

  it 'fails for both missing JWKS and duplicate organization ids simultaneously' do
    result = run_with_defaults(
      cds_jwk_set: nil,
      complete_prefetch_service_organization_id: 'same-org',
      subset_prefetch_service_organization_id: 'same-org'
    )
    expect(result.result).to eq('fail')
    messages = result_messages.map(&:message)
    expect(messages).to include(match(/CRD JSON Web Key Set/))
    expect(messages).to include(match(/unique Organization id/))
  end
end
