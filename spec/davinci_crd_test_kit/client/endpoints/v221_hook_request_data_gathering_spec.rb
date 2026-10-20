require_relative '../../../../lib/davinci_crd_test_kit/client/endpoints/v221_hook_request_data_gathering'
require_relative 'hook_request_data_fixtures'

RSpec.describe DaVinciCRDTestKit::V221HookRequestDataGathering do
  include_context 'with hook request data fixtures'

  describe 'when handling prefetched location data' do
    let(:location_fhir) { FHIR.from_contents(location_example.to_json) }
    let(:location2_fhir) { FHIR.from_contents(location2_example.to_json) }
    let(:location_prefetch_bundle) do
      bundle = FHIR::Bundle.new(type: 'searchset')
      bundle.entry << FHIR::Bundle::Entry.new(resource: location_fhir)
      bundle.entry << FHIR::Bundle::Entry.new(resource: location2_fhir)
      bundle
    end

    describe '#prefetched_location_bundle' do
      it 'returns nil when no locations in prefetch' do
        allow(module_instance).to receive(:request_body).and_return(order_sign_request)
        expect(module_instance.prefetched_location_bundle).to be_nil
      end

      it 'returns the bundle when prefetch contains a location bundle' do
        order_sign_request['prefetch'] = { 'locations' => JSON.parse(location_prefetch_bundle.to_json) }
        allow(module_instance).to receive(:request_body).and_return(order_sign_request)
        result = module_instance.prefetched_location_bundle
        expect(result).to be_a(FHIR::Bundle)
        expect(result.entry.count).to eq(2)
      end

      it 'wraps a single prefetched Location in a Bundle' do
        order_sign_request['prefetch'] = { 'locations' => JSON.parse(location_fhir.to_json) }
        allow(module_instance).to receive(:request_body).and_return(order_sign_request)
        result = module_instance.prefetched_location_bundle
        expect(result).to be_a(FHIR::Bundle)
        expect(result.entry.first.resource.id).to eq('example')
      end

      it 'returns nil when prefetch locations is neither a Bundle nor a Location' do
        order_sign_request['prefetch'] = { 'locations' => { 'resourceType' => 'Patient', 'id' => '1' } }
        allow(module_instance).to receive(:request_body).and_return(order_sign_request)
        expect(module_instance.prefetched_location_bundle).to be_nil
      end
    end

    describe '#prefetched_locations_and_parents_hash' do
      it 'returns nil when no locations in prefetch' do
        allow(module_instance).to receive(:request_body).and_return(order_sign_request)
        expect(module_instance.prefetched_locations_and_parents_hash).to be_nil
      end

      it 'returns a hash keyed by the absolute url identifying each location' do
        order_sign_request['prefetch'] = { 'locations' => JSON.parse(location_prefetch_bundle.to_json) }
        allow(module_instance).to receive(:request_body).and_return(order_sign_request)
        result = module_instance.prefetched_locations_and_parents_hash
        expect(result.size).to eq(2)
        expect(result[location_example_reference_absolute]).to be_a(FHIR::Location)
        expect(result[location2_example_reference_absolute]).to be_a(FHIR::Location)
      end

      it 'skips bundle entries without an id' do
        location_prefetch_bundle.entry << FHIR::Bundle::Entry.new(resource: FHIR::Location.new(name: 'no-id'))
        order_sign_request['prefetch'] = { 'locations' => JSON.parse(location_prefetch_bundle.to_json) }
        allow(module_instance).to receive(:request_body).and_return(order_sign_request)
        result = module_instance.prefetched_locations_and_parents_hash
        expect(result.size).to eq(2)
      end

      it 'deduplicates entries identifying the same location' do
        location_prefetch_bundle.entry << FHIR::Bundle::Entry.new(resource: location_fhir)
        order_sign_request['prefetch'] = { 'locations' => JSON.parse(location_prefetch_bundle.to_json) }
        allow(module_instance).to receive(:request_body).and_return(order_sign_request)
        result = module_instance.prefetched_locations_and_parents_hash
        expect(result.size).to eq(2)
      end

      it 'fetches and includes parent locations when a prefetched location has partOf' do
        location_with_parent = FHIR.from_contents(location_example.to_json)
        location_with_parent.partOf = FHIR::Reference.new(reference: location2_example_reference_relative)
        bundle = FHIR::Bundle.new(type: 'searchset')
        bundle.entry << FHIR::Bundle::Entry.new(resource: location_with_parent)
        order_sign_request['prefetch'] = { 'locations' => JSON.parse(bundle.to_json) }
        allow(module_instance).to receive(:request_body).and_return(order_sign_request)

        parent_request = stub_request(:get, location2_example_reference_absolute)
          .to_return(status: 200, body: location2_example.to_json)

        result = module_instance.prefetched_locations_and_parents_hash
        expect(result.size).to eq(2)
        expect(result[location_example_reference_absolute]).to be_a(FHIR::Location)
        expect(result[location2_example_reference_absolute]).to be_a(FHIR::Location)
        expect(parent_request).to have_been_made.once
      end
    end

    describe '#add_location_to_hash' do
      let(:location_hash) { {} }

      before do
        allow(module_instance).to receive(:request_body).and_return(order_sign_request)
      end

      it 'does nothing when given a non-Location resource' do
        module_instance.add_location_to_hash(nil, location_hash)
        module_instance.add_location_to_hash('not a location', location_hash)
        expect(location_hash).to be_empty
      end

      it 'does nothing when the Location has no id' do
        module_instance.add_location_to_hash(FHIR::Location.new, location_hash)
        expect(location_hash).to be_empty
      end

      it 'adds a valid Location to the hash keyed by the absolute url identifying it' do
        module_instance.add_location_to_hash(location_fhir, location_hash)
        expect(location_hash[location_example_reference_absolute]).to eq(location_fhir)
      end

      it 'does not re-add a Location already present in the hash' do
        location_hash[location_example_reference_absolute] = location_fhir
        module_instance.add_location_to_hash(location_fhir, location_hash)
        expect(location_hash.size).to eq(1)
      end

      it 'fetches and recursively adds the parent location when partOf is present' do
        location_with_parent = FHIR.from_contents(location_example.to_json)
        location_with_parent.partOf = FHIR::Reference.new(reference: location2_example_reference_relative)
        allow(module_instance).to receive(:request_body).and_return(order_sign_request)
        loc_request = stub_request(:get, location2_example_reference_absolute)
          .to_return(status: 200, body: location2_example.to_json)

        module_instance.add_location_to_hash(location_with_parent, location_hash)
        expect(location_hash.size).to eq(2)
        expect(location_hash[location_example_reference_absolute]).to eq(location_with_parent)
        expect(location_hash[location2_example_reference_absolute]).to eq(location2_fhir)
        expect(loc_request).to have_been_made.once
      end
    end

    describe '#request_parent_locations' do
      it 'returns a hash of prefetched locations' do
        order_sign_request['prefetch'] = { 'locations' => JSON.parse(location_prefetch_bundle.to_json) }
        allow(module_instance).to receive(:request_body).and_return(order_sign_request)
        result = module_instance.request_parent_locations
        expect(result).to be_a(Hash)
        expect(result[location_example_reference_absolute]).to be_a(FHIR::Location)
        expect(result[location2_example_reference_absolute]).to be_a(FHIR::Location)
      end
    end
  end

  describe '#request_access_level_target' do
    let(:target_reference) { 'Observation/123' }
    let(:access_level_instance) do
      Class.new do
        include DaVinciCRDTestKit::V221HookRequestDataGathering

        attr_accessor :result, :request_body
      end.new
    end

    def stub_target_input(value)
      inputs = value.nil? ? [] : [{ 'name' => 'access_level_target_reference', 'value' => value }]
      access_level_instance.result = double(input_json: inputs.to_json)
      access_level_instance.request_body = { 'fhirServer' => fhir_server }
    end

    it 'does not attempt a read when no target reference was provided' do
      stub_target_input(nil)
      allow(access_level_instance).to receive(:fetch_reference)

      access_level_instance.request_access_level_target

      expect(access_level_instance).to_not have_received(:fetch_reference)
    end

    # the test finds this read by its tag, so that it is not confused with the other data gathered
    it 'reads the target reference and tags the request' do
      stub_target_input(target_reference)
      allow(access_level_instance).to receive(:fetch_reference)

      access_level_instance.request_access_level_target

      expect(access_level_instance).to have_received(:fetch_reference)
        .with(target_reference, additional_tag: DaVinciCRDTestKit::ACCESS_LEVEL_TARGET_FETCH_TAG)
    end

    it 'reads a reference given as an absolute url on the request fhirServer with the access token' do
      stub_target_input("#{fhir_server}/#{target_reference}")
      access_level_instance.request_body['fhirAuthorization'] = { 'access_token' => 'SAMPLE_TOKEN' }
      allow(access_level_instance).to receive(:persist_query_request)
      target_request = stub_request(:get, "#{fhir_server}/#{target_reference}")
        .with(headers: { 'Authorization' => 'Bearer SAMPLE_TOKEN' })
        .to_return(status: 200, body: { resourceType: 'Observation', id: '123' }.to_json)

      access_level_instance.request_access_level_target

      expect(target_request).to have_been_made.once
    end
  end

  describe 'when reading references to other servers outside must support analysis' do
    def stub_tokenless_get(url, body)
      stub_request(:get, url)
        .with { |request| request.headers.keys.none? { |name| name.casecmp?('Authorization') } }
        .to_return(status: 200, body: body.to_json)
    end

    # The coverage fixture's payor is an absolute reference to http://example.org/fhir.
    it 'reads the coverage payer from its server without the access token' do
      order_sign_request['prefetch'] = { 'coverage' => crd_coverage }
      allow(module_instance).to receive(:request_body).and_return(order_sign_request)
      payer_request = stub_tokenless_get(crd_coverage['payor'].first['reference'], organization_example)

      module_instance.request_coverage_payer

      expect(payer_request).to have_been_made.once
      expect(module_instance).to have_received(:persist_query_request)
        .with(anything, include(DaVinciCRDTestKit::PAYER_ORG_FETCH_TAG), url: crd_coverage['payor'].first['reference'],
                                                                         request_headers: {})
    end

    it 'reads a relative payer reference from the server of the prefetched Coverage fullUrl' do
      elsewhere = 'https://elsewhere.example/r4'
      coverage = crd_coverage.merge('payor' => [{ 'reference' => organization_example_reference_relative }])
      entry = { 'fullUrl' => "#{elsewhere}/Coverage/#{coverage['id']}", 'resource' => coverage }
      order_sign_request['prefetch'] = { 'coverage' => { 'resourceType' => 'Bundle', 'type' => 'searchset',
                                                         'entry' => [entry] } }
      allow(module_instance).to receive(:request_body).and_return(order_sign_request)
      payer_request = stub_tokenless_get("#{elsewhere}/#{organization_example_reference_relative}",
                                         organization_example)

      module_instance.request_coverage_payer

      expect(payer_request).to have_been_made.once
    end

    it 'reads a relative payer reference from the FHIR server with the access token' do
      coverage = crd_coverage.merge('payor' => [{ 'reference' => organization_example_reference_relative }])
      order_sign_request['prefetch'] = { 'coverage' => coverage }
      allow(module_instance).to receive(:request_body).and_return(order_sign_request)
      payer_request = stub_request(:get, organization_example_reference_absolute)
        .with(headers: { 'Authorization' => 'Bearer SAMPLE_TOKEN' })
        .to_return(status: 200, body: organization_example.to_json)

      module_instance.request_coverage_payer

      expect(payer_request).to have_been_made.once
      expect(module_instance).to have_received(:persist_query_request)
        .with(anything, include(DaVinciCRDTestKit::PAYER_ORG_FETCH_TAG, DaVinciCRDTestKit::DATA_FETCH_TAG),
              url: organization_example_reference_absolute, request_headers: anything)
    end

    it 'reads the relative parent of a parent location from the server that parent was read from' do
      external_parent = 'https://elsewhere.example/r4/Location/parent'
      location = location_example.merge('partOf' => { 'reference' => external_parent })
      parent = location2_example.merge('id' => 'parent', 'partOf' => { 'reference' => 'Location/grandparent' })
      order_sign_request['prefetch'] = { 'locations' => location }
      allow(module_instance).to receive(:request_body).and_return(order_sign_request)
      stub_tokenless_get(external_parent, parent)
      grandparent_request = stub_tokenless_get('https://elsewhere.example/r4/Location/grandparent',
                                               location2_example.merge('id' => 'grandparent'))

      result = module_instance.request_parent_locations

      expect(grandparent_request).to have_been_made.once
      expect(result.keys).to contain_exactly(location_example_reference_absolute, external_parent,
                                             'https://elsewhere.example/r4/Location/grandparent')
    end

    it 'reads a parent location from its server without the access token' do
      external_parent = 'https://elsewhere.example/r4/Location/parent'
      location = location_example.merge('partOf' => { 'reference' => external_parent })
      order_sign_request['prefetch'] = { 'locations' => location }
      allow(module_instance).to receive(:request_body).and_return(order_sign_request)
      parent_request = stub_tokenless_get(external_parent, location2_example)

      module_instance.request_parent_locations

      expect(parent_request).to have_been_made.once
      expect(module_instance).to have_received(:persist_query_request)
        .with(anything, include(DaVinciCRDTestKit::PARENT_LOCATION_FETCH_TAG), url: external_parent,
                                                                               request_headers: {})
    end
  end

  describe 'when reading must support references' do
    let(:performer) { [] }
    let(:external_practitioner_url) { 'https://elsewhere.example/r4/Practitioner/other' }
    let(:service_request) do
      {
        resourceType: 'ServiceRequest',
        id: 'sr1',
        subject: { reference: patient_example_reference_relative },
        requester: { reference: practitioner_role_example_reference_absolute },
        performer:,
        locationReference: [{ reference: '#contained-location' }]
      }
    end
    let(:hook_request) do
      {
        'hook' => 'order-sign',
        'hookInstance' => 'instance-1',
        'fhirServer' => fhir_server,
        'fhirAuthorization' => { 'access_token' => 'SAMPLE_TOKEN' },
        'context' => {
          'draftOrders' => { 'resourceType' => 'Bundle', 'entry' => [{ 'resource' => service_request }] }
        },
        'prefetch' => { 'patient' => patient_example }
      }.as_json
    end
    let(:must_support_fetch_tags) do
      [DaVinciCRDTestKit::DATA_FETCH_TAG, DaVinciCRDTestKit::TagMethods.hook_instance_data_fetch_tag('instance-1'),
       DaVinciCRDTestKit::MUST_SUPPORT_REFERENCE_FETCH_TAG]
    end

    let!(:practitioner_role_request) do
      stub_request(:get, practitioner_role_example_reference_absolute)
        .to_return(status: 200, body: practitioner_role_example.to_json)
    end
    let!(:practitioner_request) do
      stub_request(:get, practitioner_example_reference_absolute)
        .to_return(status: 200, body: practitioner_example.to_json)
    end

    before do
      allow(module_instance).to receive_messages(request_body: hook_request, include_in_cross_hook_analysis?: true)
    end

    it 'reads references within must support elements without following those within what it reads' do
      module_instance.request_additional_fhir_data

      expect(practitioner_role_request).to have_been_made.once
      expect(practitioner_request).to_not have_been_made
    end

    it 'tags each read as a must support reference fetch for the hook instance' do
      module_instance.request_additional_fhir_data

      expect(module_instance).to have_received(:persist_query_request)
        .with(anything, must_support_fetch_tags, url: anything,
                                                 request_headers: { 'Authorization' => 'Bearer SAMPLE_TOKEN' }).once
    end

    it 'records a redirected read under the URL requested' do
      redirected_url = "#{fhir_server}/PractitionerRole/moved"
      stub_request(:get, practitioner_role_example_reference_absolute)
        .to_return(status: 301, headers: { 'Location' => redirected_url })
      stub_request(:get, redirected_url).to_return(status: 200, body: practitioner_role_example.to_json)

      module_instance.request_additional_fhir_data

      expect(module_instance).to have_received(:persist_query_request)
        .with(anything, must_support_fetch_tags, url: practitioner_role_example_reference_absolute,
                                                 request_headers: anything).once
      expect(module_instance).to_not have_received(:persist_query_request)
        .with(anything, anything, url: redirected_url, request_headers: anything)
    end

    it 'does not read resources carried in the request or contained' do
      patient_request = stub_request(:get, patient_example_reference_absolute)

      module_instance.request_additional_fhir_data

      expect(patient_request).to_not have_been_made
      expect(a_request(:get, /contained-location/)).to_not have_been_made
    end

    context 'when two elements hold the same reference' do
      let(:performer) { [{ reference: practitioner_role_example_reference_relative }] }

      it 'reads it only once' do
        module_instance.request_additional_fhir_data

        expect(practitioner_role_request).to have_been_made.once
      end
    end

    it 'makes no reads for requests outside the cross hook analysis' do
      allow(module_instance).to receive(:include_in_cross_hook_analysis?).and_return(false)

      module_instance.request_additional_fhir_data

      expect(practitioner_role_request).to_not have_been_made
    end

    context 'when a reference points to another server' do
      let(:performer) { [{ reference: external_practitioner_url }] }

      it 'reads it from that server without the access token' do
        external_request = stub_request(:get, external_practitioner_url)
          .with { |request| request.headers.keys.none? { |name| name.casecmp?('Authorization') } }
          .to_return(status: 200, body: practitioner_example.to_json)

        module_instance.request_additional_fhir_data

        expect(external_request).to have_been_made.once
      end

      it 'records that no access token was sent, leaving off the tag for reads made with it' do
        stub_request(:get, external_practitioner_url).to_return(status: 200, body: practitioner_example.to_json)

        module_instance.request_additional_fhir_data

        expect(module_instance).to have_received(:persist_query_request)
          .with(anything, must_support_fetch_tags - [DaVinciCRDTestKit::DATA_FETCH_TAG],
                url: external_practitioner_url, request_headers: {}).once
      end

      it 'keeps reading from the FHIR server after the other server times out' do
        stub_request(:get, external_practitioner_url).to_timeout

        module_instance.request_additional_fhir_data

        expect(practitioner_role_request).to have_been_made.once
      end
    end

    context 'when an external reference names a resource carried in the request under that fullUrl' do
      let(:performer) { [{ reference: external_practitioner_url }] }

      it 'does not read it' do
        hook_request['prefetch']['others'] = {
          'resourceType' => 'Bundle',
          'entry' => [{ 'fullUrl' => external_practitioner_url, 'resource' => practitioner_example }]
        }
        external_request = stub_request(:get, external_practitioner_url)

        module_instance.request_additional_fhir_data

        expect(external_request).to_not have_been_made
      end
    end

    context 'when a resource is identified by a fullUrl on another server' do
      let(:elsewhere) { 'https://elsewhere.example/r4' }

      def stub_tokenless_get(url, body)
        stub_request(:get, url)
          .with { |request| request.headers.keys.none? { |name| name.casecmp?('Authorization') } }
          .to_return(status: 200, body: body.to_json)
      end

      it 'reads its relative references from that server without the access token' do
        entry = hook_request['context']['draftOrders']['entry'].first
        entry['fullUrl'] = "#{elsewhere}/ServiceRequest/sr1"
        entry['resource']['requester'] = { 'reference' => practitioner_role_example_reference_relative }
        role_request = stub_tokenless_get("#{elsewhere}/#{practitioner_role_example_reference_relative}",
                                          practitioner_role_example)
        stub_request(:get, "#{elsewhere}/#{patient_example_reference_relative}").to_return(status: 404)

        module_instance.request_additional_fhir_data

        expect(role_request).to have_been_made.once
        expect(practitioner_role_request).to_not have_been_made
      end
    end

    # performer is read before requester, as the elements are visited in path order.
    context 'when a read from the FHIR server times out' do
      let(:performer) { [{ reference: 'Practitioner/slow' }] }

      it 'attempts no further reads from that server for the request' do
        stub_request(:get, "#{fhir_server}/Practitioner/slow").to_timeout

        module_instance.request_additional_fhir_data

        expect(module_instance.server_timed_out?(practitioner_role_example_reference_relative)).to be(true)
        expect(practitioner_role_request).to_not have_been_made
      end
    end

    context 'when a read fails without timing out' do
      let(:performer) { [{ reference: 'Practitioner/missing' }] }

      it 'continues with the remaining reads' do
        stub_request(:get, "#{fhir_server}/Practitioner/missing").to_return(status: 404)

        module_instance.request_additional_fhir_data

        expect(module_instance.timed_out_servers).to be_empty
        expect(practitioner_role_request).to have_been_made.once
      end
    end
  end
end
