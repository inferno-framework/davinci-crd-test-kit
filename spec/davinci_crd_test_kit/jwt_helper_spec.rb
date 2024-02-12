RSpec.describe DaVinciCRDTestKit::JwtHelper do
  let(:encryption_methods) { ['ES384', 'RS384'] }
  let(:aud) { 'AUD' }
  let(:iss) { 'ISS' }
  let(:jku) { 'JKU' }
  let(:jwks_hash) { JSON.parse(DaVinciCRDTestKit::JWKS.jwks_json) }

  def build_and_decode_jwt(encryption_method, kid = nil)
    jwt = described_class.build(aud:, encryption_method:, iss:, jku:, kid:)
    described_class.decode_jwt(jwt, jwks_hash, kid)
  end

  describe '#build' do
    context 'with unspecified key id' do
      it 'creates a valid JWT' do
        encryption_methods.each do |encryption_method|
          payload, header = build_and_decode_jwt(encryption_method)

          expect(header['alg']).to eq(encryption_method)
          expect(header['typ']).to eq('JWT')
          expect(header['kid']).to be_present
          expect(payload['iss']).to eq(iss)
          expect(payload['aud']).to eq(aud)
          expect(payload['iat']).to be_present
          expect(payload['exp']).to be_present
          expect(payload['jti']).to be_present
        end
      end
    end

    context 'with specified key id' do
      it 'creates a valid JWT with correct algorithm and kid' do
        encryption_method = 'ES384'
        kid = '4b49a739d1eb115b3225f4cf9beb6d1b'
        payload, header = build_and_decode_jwt(encryption_method, kid)

        expect(header['alg']).to eq(encryption_method)
        expect(header['typ']).to eq('JWT')
        expect(header['kid']).to eq(kid)
        expect(payload['iss']).to eq(iss)
        expect(payload['aud']).to eq(aud)
        expect(payload['iat']).to be_present
        expect(payload['exp']).to be_present
        expect(payload['jti']).to be_present
      end
    end

    it 'throws exception when key id not found for algorithm' do
      encryption_method = 'RS384'
      kid = '4b49a739d1eb115b3225f4cf9beb6d1b'

      expect do
        build_and_decode_jwt(encryption_method, kid)
      end.to raise_error(Inferno::Exceptions::AssertionException)
    end
  end
end
