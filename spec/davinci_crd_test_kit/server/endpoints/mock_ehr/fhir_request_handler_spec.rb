require_relative '../../../../../lib/davinci_crd_test_kit/server/endpoints/mock_ehr/fhir_request_handler'

RSpec.describe DaVinciCRDTestKit::MockEHR::FHIRRequestHandler do
  let(:handler) do
    Class.new { include DaVinciCRDTestKit::MockEHR::FHIRRequestHandler }.new
  end

  describe '#token_to_session_id' do
    let(:session_id) { 'abc123' }
    let(:valid_token) { described_class.session_id_to_token(session_id) }

    it 'decodes a valid token and returns its session_id' do
      expect(handler.token_to_session_id(valid_token)).to eq(session_id)
    end

    it 'returns nil when the token contains characters invalid for urlsafe base64' do
      expect(handler.token_to_session_id('not!!!valid@base64')).to be_nil
    end

    it 'returns nil when the token is valid base64 but not JSON' do
      token = Base64.urlsafe_encode64('not json', padding: false)
      expect(handler.token_to_session_id(token)).to be_nil
    end
  end
end
