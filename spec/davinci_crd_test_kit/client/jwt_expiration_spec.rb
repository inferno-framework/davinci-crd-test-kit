require_relative '../../../lib/davinci_crd_test_kit/client/jwt_expiration'

RSpec.describe DaVinciCRDTestKit::JwtExpiration do
  let(:checker) { Class.new { include DaVinciCRDTestKit::JwtExpiration }.new }
  let(:received_at) { 1_800_000_000 }
  let(:request) { Struct.new(:created_at).new(Time.at(received_at)) }

  def error_for(exp, for_request = request)
    checker.jwt_expiration_error({ 'exp' => exp }, for_request)
  end

  it 'reports nothing when the token had not expired when the request was received' do
    expect(error_for(received_at + 300)).to be_nil
  end

  it 'allows up to 60 seconds of clock skew' do
    expect(error_for(received_at - 30)).to be_nil
    expect(error_for(received_at - 59)).to be_nil
  end

  it 'reports a token whose `exp` is 60 seconds or more before the request was received' do
    expect(error_for(received_at - 60)).to eq(
      'Token had expired when the request was received: `exp` is 2027-01-15T07:59:00Z, ' \
      'the request was received at 2027-01-15T08:00:00Z.'
    )
  end

  it 'compares with the current time when there is no request' do
    allow(Time).to receive(:now).and_return(Time.at(received_at))

    expect(error_for(received_at - 30, nil)).to be_nil
    expect(error_for(received_at - 60, nil)).to include('Token had expired')
  end

  it 'compares with the current time when the request has no created_at' do
    allow(Time).to receive(:now).and_return(Time.at(received_at))

    expect(error_for(received_at - 60, Struct.new(:created_at).new(nil))).to include('Token had expired')
  end

  it 'does not report a missing or non-numeric `exp`, since other checks report those' do
    expect(checker.jwt_expiration_error({}, request)).to be_nil
    expect(error_for((received_at - 600).to_s)).to be_nil
    expect(error_for(nil)).to be_nil
  end

  it 'reports nothing when the payload is not an object' do
    expect(checker.jwt_expiration_error('not a payload', request)).to be_nil
  end
end
