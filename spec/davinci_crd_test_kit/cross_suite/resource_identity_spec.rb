require_relative '../../../lib/davinci_crd_test_kit/cross_suite/resource_identity'

RSpec.describe DaVinciCRDTestKit::ResourceIdentity do
  let(:identity) { described_class }
  let(:base) { 'https://example.com/fhir' }

  def resource(type, id)
    { 'resourceType' => type, 'id' => id }
  end

  describe '.fhir_server_base' do
    it 'drops a trailing slash' do
      expect(identity.fhir_server_base({ 'fhirServer' => "#{base}/" })).to eq(base)
    end

    it 'is nil when the request names no FHIR server' do
      expect(identity.fhir_server_base({ 'fhirServer' => '' })).to be_nil
      expect(identity.fhir_server_base({})).to be_nil
    end

    it 'is nil when the request is not a JSON object' do
      expect(identity.fhir_server_base('not a request')).to be_nil
    end
  end

  describe '.restful_identity' do
    it 'is the URL of the resource on the given server' do
      expect(identity.restful_identity(resource('Patient', '1'), "#{base}/")).to eq("#{base}/Patient/1")
    end

    it 'accepts a FHIR model as well as a Hash' do
      expect(identity.restful_identity(FHIR::Patient.new(id: '1'), base)).to eq("#{base}/Patient/1")
    end

    it 'is nil without an id or a server' do
      expect(identity.restful_identity({ 'resourceType' => 'Patient' }, base)).to be_nil
      expect(identity.restful_identity(resource('Patient', '1'), nil)).to be_nil
    end
  end

  describe '.each_identified_resource' do
    def identified(hook_request)
      results = []
      identity.each_identified_resource(hook_request) { |url, raw| results << [url, raw['id']] }
      results
    end

    it 'identifies a resource without a fullUrl by its URL on the FHIR server' do
      hook_request = { 'fhirServer' => base, 'context' => { 'patient' => resource('Patient', '1') } }
      expect(identified(hook_request)).to eq([["#{base}/Patient/1", '1']])
    end

    it 'identifies a Bundle entry by its fullUrl, and does not identify one without a fullUrl' do
      urn = 'urn:uuid:5b0e7a1c-3f2d-4e8b-9c6a-1d4f7e2b8a90'
      bundle = { 'resourceType' => 'Bundle', 'entry' => [
        { 'fullUrl' => urn, 'resource' => resource('Location', 'a') },
        { 'resource' => resource('Location', 'b') }
      ] }
      hook_request = { 'fhirServer' => base, 'prefetch' => { 'locations' => bundle } }
      expect(identified(hook_request)).to eq([[urn, 'a']])
    end

    it 'identifies resources in context before those in prefetch' do
      hook_request = { 'fhirServer' => base,
                       'prefetch' => { 'patient' => resource('Patient', 'p') },
                       'context' => { 'encounter' => resource('Encounter', 'e') } }
      expect(identified(hook_request).map(&:last)).to eq(['e', 'p'])
    end

    it 'looks inside arrays and skips values that are not resources' do
      hook_request = { 'fhirServer' => base,
                       'context' => { 'userId' => 'Practitioner/1', 'selections' => ['x'],
                                      'orders' => [resource('ServiceRequest', 'sr'), { 'not' => 'a resource' }] } }
      expect(identified(hook_request)).to eq([["#{base}/ServiceRequest/sr", 'sr']])
    end

    it 'skips a resource with no identity when the request names no FHIR server' do
      expect(identified({ 'context' => { 'patient' => resource('Patient', '1') } })).to be_empty
    end
  end

  describe '.base_for' do
    it 'is the server of a RESTful URL' do
      expect(identity.base_for("#{base}/Patient/1")).to eq(base)
      expect(identity.base_for('https://example.com/Patient/1')).to eq('https://example.com')
    end

    it 'keeps a path that only begins like another base' do
      expect(identity.base_for('http://x/fhirx/Patient/1')).to eq('http://x/fhirx')
    end

    it 'ignores a query string or fragment after the id' do
      expect(identity.base_for("#{base}/Patient/1?_format=json")).to eq(base)
      expect(identity.base_for("#{base}/Patient/1#frag")).to eq(base)
    end

    it 'is nil for a value that is not a RESTful http(s) URL' do
      expect(identity.base_for('Patient/1')).to be_nil
      expect(identity.base_for('urn:uuid:5b0e7a1c-3f2d-4e8b-9c6a-1d4f7e2b8a90')).to be_nil
      expect(identity.base_for(nil)).to be_nil
    end
  end

  describe '.relative_to' do
    it 'is the part of the URL after the base' do
      expect(identity.relative_to("#{base}/Patient/1", base)).to eq('Patient/1')
      expect(identity.relative_to("#{base}/Patient/1", "#{base}/")).to eq('Patient/1')
      expect(identity.relative_to('http://x/Patient/1', 'http://x')).to eq('Patient/1')
    end

    it 'is nil for a URL whose path only begins like the base path' do
      expect(identity.relative_to('http://x/fhirx/Patient/1', 'http://x/fhir')).to be_nil
      expect(identity.on_server?('http://x/fhirx/Patient/1', 'http://x/fhir')).to be(false)
    end

    it 'is nil for the base itself' do
      expect(identity.relative_to(base, base)).to be_nil
    end

    it 'ignores case in the scheme and host and matches a default port to an omitted one' do
      expect(identity.relative_to('HTTP://X:80/fhir/Patient/1', 'http://x/fhir')).to eq('Patient/1')
    end

    it 'keeps the path case-sensitive' do
      expect(identity.relative_to('http://x/FHIR/Patient/1', 'http://x/fhir')).to be_nil
    end

    it 'is nil on a different scheme or port' do
      expect(identity.relative_to('https://x/fhir/Patient/1', 'http://x/fhir')).to be_nil
      expect(identity.relative_to('http://x:8080/fhir/Patient/1', 'http://x/fhir')).to be_nil
    end

    it 'keeps a query string but drops a fragment' do
      expect(identity.relative_to("#{base}/Patient?identifier=a|b", base)).to eq('Patient?identifier=a|b')
      expect(identity.relative_to("#{base}/Patient/1#frag", base)).to eq('Patient/1')
    end

    it 'is nil without a base, or for a value that is not an absolute URL' do
      expect(identity.relative_to("#{base}/Patient/1", nil)).to be_nil
      expect(identity.relative_to('Patient/1', base)).to be_nil
      expect(identity.relative_to('urn:uuid:5b0e7a1c-3f2d-4e8b-9c6a-1d4f7e2b8a90', base)).to be_nil
    end
  end

  describe '.absolute_reference' do
    it 'appends a relative reference to the base' do
      expect(identity.absolute_reference('Patient/1', base)).to eq("#{base}/Patient/1")
      expect(identity.absolute_reference('Patient/1', "#{base}/")).to eq("#{base}/Patient/1")
    end

    it 'returns an absolute reference as given, whatever its scheme' do
      urn = 'urn:uuid:5b0e7a1c-3f2d-4e8b-9c6a-1d4f7e2b8a90'
      expect(identity.absolute_reference(urn, base)).to eq(urn)
      expect(identity.absolute_reference('https://elsewhere.example/Patient/1', base))
        .to eq('https://elsewhere.example/Patient/1')
    end

    it 'treats a value naming only a scheme as absolute' do
      expect(identity.absolute_reference('foo:', base)).to eq('foo:')
    end

    it 'keeps a query string or fragment on an absolute reference' do
      expect(identity.absolute_reference("#{base}/Patient?identifier=a", 'http://other'))
        .to eq("#{base}/Patient?identifier=a")
      expect(identity.absolute_reference("#{base}/Patient/1#frag", 'http://other')).to eq("#{base}/Patient/1#frag")
    end

    it 'is nil for a contained or blank reference' do
      expect(identity.absolute_reference('#contained-1', base)).to be_nil
      expect(identity.absolute_reference('', base)).to be_nil
      expect(identity.absolute_reference(nil, base)).to be_nil
    end

    it 'is nil for a reference that is not a string' do
      expect(identity.absolute_reference(42, base)).to be_nil
      expect(identity.absolute_reference({ 'reference' => 'Patient/1' }, base)).to be_nil
      expect(identity.absolute_reference(['Patient/1'], base)).to be_nil
    end

    it 'is nil for a relative reference without a base' do
      expect(identity.absolute_reference('Patient/1', nil)).to be_nil
    end

    it 'is nil for a relative value that is not of the form Type/id' do
      expect(identity.absolute_reference('patient/1', base)).to be_nil
      expect(identity.absolute_reference('Patient?identifier=a', base)).to be_nil
      expect(identity.absolute_reference('Patient/1#frag', base)).to be_nil
    end
  end

  describe '.absolute_url?' do
    it 'is decided by the presence of a scheme, ignoring case' do
      expect(identity.absolute_url?('Urn:uuid:x')).to be(true)
      expect(identity.absolute_url?('Patient/1')).to be(false)
      expect(identity.absolute_url?('1http:x')).to be(false)
    end
  end

  describe '.http_url?' do
    it 'is true only for http(s) URLs, ignoring case in the scheme' do
      expect(identity.http_url?('HTTPS://x/fhir')).to be(true)
      expect(identity.http_url?('ftp://x/fhir')).to be(false)
      expect(identity.http_url?('urn:uuid:x')).to be(false)
    end
  end

  describe '.normalized_url' do
    it 'lowercases the scheme and host but not the path' do
      expect(identity.normalized_url('HTTPS://EXAMPLE.com/Fhir/Patient/1')).to eq('https://example.com/Fhir/Patient/1')
    end

    it 'drops a default port' do
      expect(identity.normalized_url('https://Example.COM:443/fhir/Patient/1')).to eq('https://example.com/fhir/Patient/1')
      expect(identity.normalized_url('http://example.com:80/fhir/Patient/1')).to eq('http://example.com/fhir/Patient/1')
    end

    it 'keeps a port that is not the default for the scheme' do
      expect(identity.normalized_url('http://example.com:443/fhir')).to eq('http://example.com:443/fhir')
      expect(identity.normalized_url('https://example.com:8443/fhir')).to eq('https://example.com:8443/fhir')
    end

    it 'keeps a query string and fragment as given' do
      expect(identity.normalized_url('https://Example.com/fhir/Patient/1?q=A#F'))
        .to eq('https://example.com/fhir/Patient/1?q=A#F')
    end

    it 'returns a value that is not an http(s) URL unchanged' do
      expect(identity.normalized_url('urn:uuid:ABC')).to eq('urn:uuid:ABC')
      expect(identity.normalized_url('Patient/1')).to eq('Patient/1')
      expect(identity.normalized_url(nil)).to be_nil
    end

    it 'returns an http(s) value it cannot parse, or one without a host, unchanged' do
      expect(identity.normalized_url('http://exa mple.com/x')).to eq('http://exa mple.com/x')
      expect(identity.normalized_url('http:///nohost')).to eq('http:///nohost')
    end
  end

  describe '.readable? and .names?' do
    it 'reads a RESTful URL to a single resource' do
      expect(identity.readable?("#{base}/Patient/1")).to be(true)
    end

    it 'does not read a search or a URL with a query string or fragment' do
      expect(identity.readable?("#{base}/Patient?identifier=a")).to be(false)
      expect(identity.readable?("#{base}/Patient/1?_format=json")).to be(false)
      expect(identity.readable?("#{base}/Patient/1#frag")).to be(false)
    end

    it 'matches a resource by type and id' do
      expect(identity.names?("#{base}/Patient/1", FHIR::Patient.new(id: '1'))).to be(true)
      expect(identity.names?("#{base}/Patient/1", resource('Patient', '2'))).to be(false)
      expect(identity.names?("#{base}/Patient/1", resource('Practitioner', '1'))).to be(false)
      expect(identity.names?('Patient/1', resource('Patient', '1'))).to be(false)
    end
  end

  # Versioned references are a documented limitation (see docs/Client-Details.md): the reference patterns end at
  # the id, so a `/_history/<vid>` reference neither resolves to nor names the resource it points to.
  describe 'with a version-specific reference' do
    it 'gives no absolute form for a relative reference' do
      expect(identity.absolute_reference('Patient/1/_history/2', base)).to be_nil
    end

    it 'returns an absolute reference as given, so it matches no fullUrl or RESTful identity' do
      versioned = "#{base}/Patient/1/_history/2"
      expect(identity.absolute_reference(versioned, base)).to eq(versioned)
      expect(versioned).to_not eq(identity.restful_identity(resource('Patient', '1'), base))
    end

    it 'is neither readable nor naming the resource, and gives no base' do
      versioned = "#{base}/Patient/1/_history/2"
      expect(identity.readable?(versioned)).to be(false)
      expect(identity.names?(versioned, resource('Patient', '1'))).to be(false)
      expect(identity.base_for(versioned)).to be_nil
    end
  end
end
