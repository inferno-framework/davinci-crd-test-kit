require_relative '../../../lib/davinci_crd_test_kit/client/jwt_claim_types'

RSpec.describe DaVinciCRDTestKit::JwtClaimTypes do
  let(:checker) { Class.new { include DaVinciCRDTestKit::JwtClaimTypes }.new }
  let(:payload) do
    {
      'iss' => 'https://client.example.com',
      'aud' => 'https://inferno.example.com/cds-services/order-sign-service',
      'exp' => 1_800_000_000,
      'iat' => 1_799_999_700,
      'jti' => 'unique-id'
    }
  end

  it 'reports nothing when every claim has the required type' do
    expect(checker.jwt_claim_type_errors(payload)).to be_empty
  end

  it 'accepts an `aud` array of strings' do
    expect(checker.jwt_claim_type_errors(payload.merge('aud' => ['https://a.example', 'https://b.example'])))
      .to be_empty
  end

  it 'does not report claims that are absent' do
    expect(checker.jwt_claim_type_errors({})).to be_empty
  end

  it 'reports nothing when the payload is not an object' do
    expect(checker.jwt_claim_type_errors('not a payload')).to be_empty
  end

  it 'reports an `iss` that is not a string' do
    expect(checker.jwt_claim_type_errors(payload.merge('iss' => 42)))
      .to eq(['JWT payload claim `iss` must be a string, got 42.'])
  end

  it 'reports an `aud` that is neither a string nor an array of strings' do
    expect(checker.jwt_claim_type_errors(payload.merge('aud' => { 'url' => 'https://a.example' })))
      .to eq(['JWT payload claim `aud` must be a string or an array of strings, got {"url":"https://a.example"}.'])
  end

  it 'reports a null claim, since a present claim must have the required type' do
    expect(checker.jwt_claim_type_errors(payload.merge('jti' => nil)))
      .to eq(['JWT payload claim `jti` must be a string, got null.'])
  end
end
