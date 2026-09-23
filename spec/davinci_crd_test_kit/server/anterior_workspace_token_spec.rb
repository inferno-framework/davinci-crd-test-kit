RSpec.describe DaVinciCRDTestKit::AnteriorWorkspaceToken do
  let(:service_url) { 'http://crd.test:3000/auth/fhir/cds-services/order-sign-crd' }
  let(:token_url) { 'http://crd.test:3000/auth/token' }
  let(:machine_key) { 'sandbox-machine-key' }

  around do |example|
    previous = ENV.fetch(described_class::MACHINE_KEY_ENV, nil)
    ENV[described_class::MACHINE_KEY_ENV] = machine_key
    described_class.reset!
    example.run
  ensure
    described_class.reset!
    if previous
      ENV[described_class::MACHINE_KEY_ENV] = previous
    else
      ENV.delete(described_class::MACHINE_KEY_ENV)
    end
  end

  it 'exchanges the machine key once and reuses the workspace bearer' do
    exchange = stub_request(:post, token_url)
      .with(
        headers: { 'Content-Type' => 'application/x-www-form-urlencoded' },
        body: {
          'grant_type' => 'client_credentials',
          'client_id' => described_class::CLIENT_ID,
          'client_secret' => machine_key
        }
      )
      .to_return(
        status: 200,
        body: { access_token: 'workspace-token', expires_in: 7200, token_type: 'Bearer' }.to_json
      )

    expect(described_class.authorization_header(service_url)).to eq('Bearer workspace-token')
    expect(described_class.authorization_header(service_url)).to eq('Bearer workspace-token')
    expect(exchange).to have_been_made.once
  end

  it 'raises when the machine key is missing' do
    ENV.delete(described_class::MACHINE_KEY_ENV)

    expect { described_class.authorization_header(service_url) }
      .to raise_error(described_class::MissingKey, /#{Regexp.escape(described_class::MACHINE_KEY_ENV)}/)
  end
end
