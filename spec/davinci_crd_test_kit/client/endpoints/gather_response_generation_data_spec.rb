require_relative '../../../../lib/davinci_crd_test_kit/client/endpoints/gather_response_generation_data'
require_relative '../../../../lib/davinci_crd_test_kit/cross_suite/tags'

RSpec.describe DaVinciCRDTestKit::GatherResponseGenerationData do
  let(:module_instance) do
    Class.new do
      include DaVinciCRDTestKit::GatherResponseGenerationData

      def request_body
        nil
      end
    end.new
  end

  let(:fhir_server) { 'https://example/r4' }
  let(:patient_example_reference_relative) { 'Patient/example' }
  let(:patient_example_reference_absolute) { "#{fhir_server}/#{patient_example_reference_relative}" }
  let(:patient_example) do
    JSON.parse(File.read(File.join(__dir__, '..', '..', '..', 'fixtures', 'crd_patient_example.json')))
  end
  let(:organization_example_reference_relative) { 'Organization/example' }
  let(:organization_example_reference_absolute) { "#{fhir_server}/#{organization_example_reference_relative}" }
  let(:organization_example) do
    JSON.parse(File.read(File.join(__dir__, '..', '..', '..', 'fixtures', 'crd_organization_example.json')))
  end
  let(:practitioner_example_reference_relative) { 'Practitioner/example' }
  let(:practitioner_example_reference_absolute) { "#{fhir_server}/#{practitioner_example_reference_relative}" }
  let(:practitioner_example) do
    JSON.parse(File.read(File.join(__dir__, '..', '..', '..', 'fixtures', 'crd_practitioner_example.json')))
  end
  let(:practitioner_role_example_reference_relative) { 'PractitionerRole/example' }
  let(:practitioner_role_example_reference_absolute) do
    "#{fhir_server}/#{practitioner_role_example_reference_relative}"
  end
  let(:practitioner_role_example) do
    JSON.parse(File.read(File.join(__dir__, '..', '..', '..', 'fixtures', 'crd_practitioner_role_example.json')))
  end
  let(:location_example_reference_relative) { 'Location/example' }
  let(:location_example_reference_absolute) do
    "#{fhir_server}/#{location_example_reference_relative}"
  end
  let(:location_example) do
    JSON.parse(File.read(File.join(__dir__, '..', '..', '..', 'fixtures', 'crd_location_example.json')))
  end
  let(:location2_example_reference_relative) { 'Location/example2' }
  let(:location2_example_reference_absolute) do
    "#{fhir_server}/#{location2_example_reference_relative}"
  end
  let(:location2_example) do
    loc = JSON.parse(File.read(File.join(__dir__, '..', '..', '..', 'fixtures', 'crd_location_example.json')))
    loc['id'] = 'example2'
    loc
  end
  let(:encounter_example_reference_relative) { 'Encounter/example' }
  let(:encounter_example_reference_absolute) do
    "#{fhir_server}/#{encounter_example_reference_relative}"
  end
  let(:encounter_example) do
    JSON.parse(File.read(File.join(__dir__, '..', '..', '..', 'fixtures', 'crd_encounter_example.json')))
  end
  let(:service_request_example_reference_relative) { 'ServiceRequest/example' }
  let(:service_request_example_reference_absolute) do
    "#{fhir_server}/#{service_request_example_reference_relative}"
  end
  let(:service_request_example) do
    JSON.parse(File.read(File.join(__dir__, '..', '..', '..', 'fixtures', 'crd_service_request_example.json')))
  end
  let(:crd_coverage) do
    JSON.parse(File.read(File.join(
                           __dir__, '..', '..', '..', 'fixtures', 'crd_coverage_example.json'
                         )))
  end
  let(:crd_coverage_bundle) do
    bundle = FHIR::Bundle.new(type: 'searchset')
    bundle.entry.append(FHIR::Bundle::Entry.new(
                          fullUrl: 'https://example.com/base/Coverage/coverage_example',
                          resource: FHIR.from_contents(crd_coverage.to_json)
                        ))
    bundle
  end
  let(:coverage_search_url) { "#{fhir_server}/Coverage?patient=example&status=active" }
  let(:appointment_book_request) do
    JSON.parse(File.read(File.join(__dir__, '..', '..', '..', 'fixtures', 'appointment_book_hook_request.json')))
  end
  let(:encounter_start_request) do
    JSON.parse(File.read(File.join(__dir__, '..', '..', '..', 'fixtures', 'encounter_start_hook_request.json')))
  end
  let(:encounter_discharge_request) do
    JSON.parse(File.read(File.join(__dir__, '..', '..', '..', 'fixtures', 'encounter_discharge_hook_request.json')))
  end
  let(:order_select_request) do
    JSON.parse(File.read(File.join(__dir__, '..', '..', '..', 'fixtures', 'order_select_hook_request.json')))
  end
  let(:order_sign_request) do
    JSON.parse(File.read(File.join(__dir__, '..', '..', '..', 'fixtures', 'order_sign_hook_request.json')))
  end
  let(:order_dispatch_request) do
    JSON.parse(File.read(File.join(__dir__, '..', '..', '..', 'fixtures', 'order_dispatch_hook_request.json')))
  end

  before do
    allow(module_instance).to(receive(:persist_query_request))
  end

  describe 'when deciding what data to fetch' do
    it 'does not fetch data that has been prefetched (relative reference)' do
      order_sign_request['prefetch'] = { patient: patient_example }
      allow(module_instance).to receive(:request_body).and_return(order_sign_request)

      module_instance.gather_data_for_request([patient_example_reference_relative], [])
      expect(module_instance.prefetched_resources[patient_example_reference_relative]).to eq(patient_example)
      expect(module_instance.analyzed_resources[patient_example_reference_relative]).to eq(patient_example)
      # no http requests made
    end

    it 'does not fetch data that has been prefetched (local absolute reference)' do
      order_sign_request['prefetch'] = { patient: patient_example }
      allow(module_instance).to receive(:request_body).and_return(order_sign_request)

      module_instance.gather_data_for_request([patient_example_reference_absolute], [])
      expect(module_instance.prefetched_resources[patient_example_reference_relative]).to eq(patient_example)
      expect(module_instance.analyzed_resources[patient_example_reference_relative]).to eq(patient_example)
      # no http requests made
    end

    it 'does not fetch data that has already been fetched (relative reference)' do
      allow(module_instance).to receive_messages(request_body: order_sign_request,
                                                 analyzed_resources:
                                                  { patient_example_reference_relative => patient_example })

      module_instance.gather_data_for_request([patient_example_reference_relative], [])
      expect(module_instance.analyzed_resources[patient_example_reference_relative]).to eq(patient_example)
      # no http requests made
    end

    it 'does not fetch data that has already been fetched (local absolute reference)' do
      allow(module_instance).to receive_messages(request_body: order_sign_request,
                                                 analyzed_resources:
                                                  { patient_example_reference_relative => patient_example })

      module_instance.gather_data_for_request(["#{fhir_server}/#{patient_example_reference_relative}"], [])
      expect(module_instance.analyzed_resources[patient_example_reference_relative]).to eq(patient_example)
      # no http requests made
    end

    it 'does not fetch data that has already been fetched (external absolute reference)' do
      external_reference = "https://another.server/r4/#{patient_example_reference_relative}"
      allow(module_instance).to receive(:request_body).and_return(order_sign_request)
      allow(module_instance).to receive_messages(request_body: order_sign_request,
                                                 analyzed_resources: { external_reference => patient_example })

      module_instance.gather_data_for_request([external_reference], [])
      expect(module_instance.analyzed_resources[external_reference]).to eq(patient_example)
      # no http requests made
    end

    it 'requests references (relative reference)' do
      allow(module_instance).to receive_messages(request_body: order_sign_request)

      local_request = stub_request(:get, patient_example_reference_absolute)
        .to_return(status: 200, body: patient_example.to_json)

      module_instance.gather_data_for_request([patient_example_reference_relative], [])
      expect(module_instance.analyzed_resources[patient_example_reference_relative]).to eq(patient_example)
      expect(local_request).to have_been_made.once
    end

    it 'requests references (local absolute reference)' do
      allow(module_instance).to receive_messages(request_body: order_sign_request)

      local_request = stub_request(:get, patient_example_reference_absolute)
        .to_return(status: 200, body: patient_example.to_json)

      module_instance.gather_data_for_request([patient_example_reference_absolute], [])
      expect(module_instance.analyzed_resources[patient_example_reference_relative]).to eq(patient_example)
      expect(local_request).to have_been_made.once
    end

    it 'requests references (external absolute refrence)' do
      external_reference = "https://another.server/r4/#{patient_example_reference_relative}"
      allow(module_instance).to receive(:request_body).and_return(order_sign_request)

      external_request = stub_request(:get, external_reference)
        .to_return(status: 200, body: patient_example.to_json)

      module_instance.gather_data_for_request([external_reference], [])
      expect(module_instance.analyzed_resources[external_reference]).to eq(patient_example)
      expect(external_request).to have_been_made.once
    end
  end

  describe 'when analyzing resources' do
    it 'finds references in top-level, single entry elements' do
      order_sign_request['prefetch'] = { practitioner: practitioner_example }
      allow(module_instance).to receive(:request_body).and_return(order_sign_request)

      module_instance.gather_data_for_request([], [practitioner_role_example])
      expect(module_instance.analyzed_resources.size).to eq(2)
      expect(module_instance.analyzed_resources[practitioner_role_example_reference_relative]).to be_present
      expect(module_instance.analyzed_resources[practitioner_example_reference_relative]).to be_present
    end

    it 'finds references in top-level, multiple entry elements' do
      order_sign_request['prefetch'] = { loc1: location_example, loc2: location2_example }
      allow(module_instance).to receive(:request_body).and_return(order_sign_request)
      practitioner_role_example.delete('practitioner')
      practitioner_role_example['location'] = [
        { 'reference' => location_example_reference_relative },
        { 'reference' => location2_example_reference_relative }
      ]

      module_instance.gather_data_for_request([], [practitioner_role_example])
      expect(module_instance.analyzed_resources.size).to eq(3)
      expect(module_instance.analyzed_resources[practitioner_role_example_reference_relative]).to be_present
      expect(module_instance.analyzed_resources[location_example_reference_relative]).to be_present
      expect(module_instance.analyzed_resources[location2_example_reference_relative]).to be_present
    end

    it 'finds references in single entry elements nested under multi-entry elements' do
      order_sign_request['prefetch'] =
        { practitioner: practitioner_example, loc1: location_example, loc2: location2_example }
      allow(module_instance).to receive(:request_body).and_return(order_sign_request)
      encounter_example.delete('serviceProvider')

      module_instance.gather_data_for_request([], [encounter_example])
      expect(module_instance.analyzed_resources.size).to eq(4)
      expect(module_instance.analyzed_resources[encounter_example_reference_relative]).to be_present
      expect(module_instance.analyzed_resources[location_example_reference_relative]).to be_present
      expect(module_instance.analyzed_resources[location2_example_reference_relative]).to be_present
      expect(module_instance.analyzed_resources[practitioner_example_reference_relative]).to be_present
    end

    it 'ignores references that are not literal' do
      practitioner_role_example['practitioner'] = {
        'identifier' => {
          'system' => 'http://hl7.org/fhir/sid/us-npi',
          'value' => '9941339108'
        }
      }

      module_instance.gather_data_for_request([], [practitioner_role_example])
      expect(module_instance.analyzed_resources.size).to eq(1)
      expect(module_instance.analyzed_resources[practitioner_role_example_reference_relative]).to be_present
    end
  end

  describe 'when fetching data' do
    it 'handles resource fetch failures' do
      order_sign_request['prefetch'] = { patient: patient_example }
      allow(module_instance).to receive(:request_body).and_return(order_sign_request)

      failed_request = stub_request(:get, practitioner_role_example_reference_absolute)
        .to_return(status: 401)

      module_instance.gather_data_for_request([practitioner_role_example_reference_relative,
                                               patient_example_reference_relative], [])

      expect(module_instance.analyzed_resources.size).to eq(2)
      expect(module_instance.analyzed_resources[patient_example_reference_relative]).to be_present
      expect(module_instance.analyzed_resources.key?(practitioner_role_example_reference_relative)).to be(true)
      expect(module_instance.analyzed_resources[practitioner_role_example_reference_relative]).to be_nil
      expect(failed_request).to have_been_made.once
    end

    it 'analyzes fetched resources and fetches found references' do
      allow(module_instance).to receive(:request_body).and_return(order_sign_request)

      pr_request = stub_request(:get, practitioner_role_example_reference_absolute)
        .to_return(status: 200, body: practitioner_role_example.to_json)
      p_request = stub_request(:get, practitioner_example_reference_absolute)
        .to_return(status: 200, body: practitioner_example.to_json)

      module_instance.gather_data_for_request([practitioner_role_example_reference_relative], [])

      expect(module_instance.analyzed_resources.size).to eq(2)
      expect(module_instance.analyzed_resources[practitioner_example_reference_relative]).to be_present
      expect(module_instance.analyzed_resources[practitioner_role_example_reference_relative]).to be_present
      expect(pr_request).to have_been_made.once
      expect(p_request).to have_been_made.once
    end

    it 'handles a non-JSON response body without raising' do
      allow(module_instance).to receive(:request_body).and_return(order_sign_request)

      stub_request(:get, patient_example_reference_absolute)
        .to_return(status: 200, body: 'not valid json')

      module_instance.gather_data_for_request([patient_example_reference_relative], [])
      expect(module_instance.analyzed_resources.key?(patient_example_reference_relative)).to be(true)
      expect(module_instance.analyzed_resources[patient_example_reference_relative]).to be_nil
    end
  end

  describe 'when fetching coverage resources' do
    it 'queries if no prefetch data present' do
      allow(module_instance).to receive(:request_body).and_return(order_sign_request)

      cov_request = stub_request(:get, coverage_search_url)
        .to_return(status: 200, body: crd_coverage_bundle.to_json)

      coverage = module_instance.request_coverage
      expect(coverage.is_a?(FHIR::Coverage)).to be(true)
      expect(coverage.id).to eq('coverage_example')
      expect(cov_request).to have_been_made.once
    end

    it 'queries if no prefetch data present but can handle finding nothing' do
      allow(module_instance).to receive(:request_body).and_return(order_sign_request)

      crd_coverage_bundle.entry.pop
      cov_request = stub_request(:get, coverage_search_url)
        .to_return(status: 200, body: crd_coverage_bundle.to_json)

      coverage = module_instance.request_coverage
      expect(coverage).to be_nil
      expect(cov_request).to have_been_made.once
    end

    it 'does not query if prefetch data present' do
      cov_request = stub_request(:get, coverage_search_url)
        .to_return(status: 200, body: crd_coverage_bundle.to_json)

      crd_coverage_bundle.entry.first.resource.id = 'prefetch_coverage'
      order_sign_request['prefetch'] = {
        'coverage' => JSON.parse(crd_coverage_bundle.to_json)
      }
      allow(module_instance).to receive(:request_body).and_return(order_sign_request)

      coverage = module_instance.request_coverage
      expect(coverage.is_a?(FHIR::Coverage)).to be(true)
      expect(coverage.id).to eq('prefetch_coverage')
      expect(cov_request).to_not have_been_made
    end

    it 'finds no coverage if the prefetch data is bad' do
      cov_request = stub_request(:get, coverage_search_url)
        .to_return(status: 200, body: crd_coverage_bundle.to_json)

      order_sign_request['prefetch'] = {
        'coverage' => JSON.parse(crd_coverage.to_json)
      }
      allow(module_instance).to receive(:request_body).and_return(order_sign_request)

      coverage = module_instance.request_coverage
      expect(coverage).to be_nil
      expect(cov_request).to_not have_been_made
    end
  end

  describe 'when identifying prefetched resources' do
    it 'handles requests with no prefetch' do
      allow(module_instance).to receive(:request_body).and_return(order_sign_request)
      expect(module_instance.prefetched_resources.is_a?(Hash)).to be(true)
      expect(module_instance.prefetched_resources.size).to be(0)
    end

    it 'ignores bad entries' do
      order_sign_request['prefetch'] = {
        good_resource: { 'resourceType' => 'Patient', 'id' => '123' },
        bad_empty: nil,
        bad_not_hash: 'test',
        bad_resource_no_type: { 'id' => '123' },
        bad_resource_no_id: { 'resourceType' => 'Patient' },
        bundle: {
          'resourceType' => 'Bundle',
          'entry' => [
            nil,
            'not_a_hash',
            {
              'not_resource' => 'wrong'
            },
            {
              'resource' => 'not a hash'
            },
            {
              'resource' => { 'resourceType' => 'no id' }
            },
            {
              'resource' => { 'id' => 'no resourceType' }
            },
            {
              'resource' => { 'resourceType' => 'Coverage', 'id' => '456' }
            }
          ]
        }
      }
      allow(module_instance).to receive(:request_body).and_return(order_sign_request)
      expect(module_instance.prefetched_resources.is_a?(Hash)).to be(true)
      expect(module_instance.prefetched_resources.size).to be(2)
      expect(module_instance.prefetched_resources['Patient/123']).to be_present
      expect(module_instance.prefetched_resources['Coverage/456']).to be_present
    end
  end

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

      it 'returns a hash keyed by relative reference for each location' do
        order_sign_request['prefetch'] = { 'locations' => JSON.parse(location_prefetch_bundle.to_json) }
        allow(module_instance).to receive(:request_body).and_return(order_sign_request)
        result = module_instance.prefetched_locations_and_parents_hash
        expect(result.size).to eq(2)
        expect(result[location_example_reference_relative]).to be_a(FHIR::Location)
        expect(result[location2_example_reference_relative]).to be_a(FHIR::Location)
      end

      it 'skips bundle entries without an id' do
        location_prefetch_bundle.entry << FHIR::Bundle::Entry.new(resource: FHIR::Location.new(name: 'no-id'))
        order_sign_request['prefetch'] = { 'locations' => JSON.parse(location_prefetch_bundle.to_json) }
        allow(module_instance).to receive(:request_body).and_return(order_sign_request)
        result = module_instance.prefetched_locations_and_parents_hash
        expect(result.size).to eq(2)
      end

      it 'deduplicates entries with the same relative reference' do
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
        expect(result[location_example_reference_relative]).to be_a(FHIR::Location)
        expect(result[location2_example_reference_relative]).to be_a(FHIR::Location)
        expect(parent_request).to have_been_made.once
      end
    end

    describe '#add_location_to_hash' do
      let(:location_hash) { {} }

      it 'does nothing when given a non-Location resource' do
        module_instance.add_location_to_hash(nil, location_hash)
        module_instance.add_location_to_hash('not a location', location_hash)
        expect(location_hash).to be_empty
      end

      it 'does nothing when the Location has no id' do
        module_instance.add_location_to_hash(FHIR::Location.new, location_hash)
        expect(location_hash).to be_empty
      end

      it 'adds a valid Location to the hash keyed by relative reference' do
        module_instance.add_location_to_hash(location_fhir, location_hash)
        expect(location_hash[location_example_reference_relative]).to eq(location_fhir)
      end

      it 'does not re-add a Location already present in the hash' do
        location_hash[location_example_reference_relative] = location_fhir
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
        expect(location_hash[location_example_reference_relative]).to eq(location_with_parent)
        expect(location_hash[location2_example_reference_relative]).to eq(location2_fhir)
        expect(loc_request).to have_been_made.once
      end
    end

    describe '#request_parent_locations' do
      it 'returns a hash of prefetched locations' do
        order_sign_request['prefetch'] = { 'locations' => JSON.parse(location_prefetch_bundle.to_json) }
        allow(module_instance).to receive(:request_body).and_return(order_sign_request)
        result = module_instance.request_parent_locations
        expect(result).to be_a(Hash)
        expect(result[location_example_reference_relative]).to be_a(FHIR::Location)
        expect(result[location2_example_reference_relative]).to be_a(FHIR::Location)
      end
    end
  end

  describe 'when fetching data for specific hooks' do
    it 'fetches expected resources for appointment-book example' do
      allow(module_instance).to receive(:request_body).and_return(appointment_book_request)

      pat_request = stub_request(:get, patient_example_reference_absolute)
        .to_return(status: 200, body: patient_example.to_json)
      p_request = stub_request(:get, practitioner_example_reference_absolute)
        .to_return(status: 200, body: practitioner_example.to_json)

      module_instance.gather_appointment_book_data
      expect(module_instance.analyzed_resources[practitioner_example_reference_relative]).to be_present
      expect(module_instance.analyzed_resources[patient_example_reference_relative]).to be_present
      expect(module_instance.analyzed_resources['Appointment/apt1']).to be_present
      expect(module_instance.analyzed_resources['Appointment/apt2']).to be_present
      expect(module_instance.analyzed_resources.size).to eq(4)
      expect(p_request).to have_been_made.once
      expect(pat_request).to have_been_made.once
    end

    it 'fetches expected resources for encounter-start example' do
      allow(module_instance).to receive(:request_body).and_return(encounter_start_request)

      pat_request = stub_request(:get, patient_example_reference_absolute)
        .to_return(status: 200, body: patient_example.to_json)
      p_request = stub_request(:get, practitioner_example_reference_absolute)
        .to_return(status: 200, body: practitioner_example.to_json)
      e_request = stub_request(:get, encounter_example_reference_absolute)
        .to_return(status: 200, body: encounter_example.to_json)
      l_request = stub_request(:get, location_example_reference_absolute)
        .to_return(status: 200, body: location_example.to_json)
      l2_request = stub_request(:get, location2_example_reference_absolute)
        .to_return(status: 200, body: location2_example.to_json)
      o_request = stub_request(:get, organization_example_reference_absolute)
        .to_return(status: 200, body: organization_example.to_json)

      module_instance.gather_encounter_start_data
      expect(module_instance.analyzed_resources[practitioner_example_reference_relative]).to be_present
      expect(module_instance.analyzed_resources[patient_example_reference_relative]).to be_present
      expect(module_instance.analyzed_resources[encounter_example_reference_relative]).to be_present
      expect(module_instance.analyzed_resources[location_example_reference_relative]).to be_present
      expect(module_instance.analyzed_resources[location2_example_reference_relative]).to be_present
      expect(module_instance.analyzed_resources[organization_example_reference_relative]).to be_present
      expect(module_instance.analyzed_resources.size).to eq(6)
      expect(p_request).to have_been_made.once
      expect(pat_request).to have_been_made.once
      expect(e_request).to have_been_made.once
      expect(l_request).to have_been_made.once
      expect(l2_request).to have_been_made.once
      expect(o_request).to have_been_made.once
    end

    it 'fetches expected resources for encounter-discharge example' do
      allow(module_instance).to receive(:request_body).and_return(encounter_discharge_request)

      pat_request = stub_request(:get, patient_example_reference_absolute)
        .to_return(status: 200, body: patient_example.to_json)
      p_request = stub_request(:get, practitioner_example_reference_absolute)
        .to_return(status: 200, body: practitioner_example.to_json)
      e_request = stub_request(:get, encounter_example_reference_absolute)
        .to_return(status: 200, body: encounter_example.to_json)
      l_request = stub_request(:get, location_example_reference_absolute)
        .to_return(status: 200, body: location_example.to_json)
      l2_request = stub_request(:get, location2_example_reference_absolute)
        .to_return(status: 200, body: location2_example.to_json)
      o_request = stub_request(:get, organization_example_reference_absolute)
        .to_return(status: 200, body: organization_example.to_json)

      module_instance.gather_encounter_discharge_data
      expect(module_instance.analyzed_resources[practitioner_example_reference_relative]).to be_present
      expect(module_instance.analyzed_resources[patient_example_reference_relative]).to be_present
      expect(module_instance.analyzed_resources[encounter_example_reference_relative]).to be_present
      expect(module_instance.analyzed_resources[location_example_reference_relative]).to be_present
      expect(module_instance.analyzed_resources[location2_example_reference_relative]).to be_present
      expect(module_instance.analyzed_resources[organization_example_reference_relative]).to be_present
      expect(module_instance.analyzed_resources.size).to eq(6)
      expect(p_request).to have_been_made.once
      expect(pat_request).to have_been_made.once
      expect(e_request).to have_been_made.once
      expect(l_request).to have_been_made.once
      expect(l2_request).to have_been_made.once
      expect(o_request).to have_been_made.once
    end

    it 'fetches expected resources for order-select example' do
      allow(module_instance).to receive(:request_body).and_return(order_select_request)

      pat_request = stub_request(:get, patient_example_reference_absolute)
        .to_return(status: 200, body: patient_example.to_json)
      p_request = stub_request(:get, practitioner_example_reference_absolute)
        .to_return(status: 200, body: practitioner_example.to_json)

      module_instance.gather_order_select_data
      expect(module_instance.analyzed_resources[practitioner_example_reference_relative]).to be_present
      expect(module_instance.analyzed_resources[patient_example_reference_relative]).to be_present
      expect(module_instance.analyzed_resources['MedicationRequest/smart-MedicationRequest-103']).to be_present
      expect(module_instance.analyzed_resources['NutritionOrder/pureeddiet-simple']).to be_present
      expect(module_instance.analyzed_resources.size).to eq(4)
      expect(p_request).to have_been_made.once
      expect(pat_request).to have_been_made.once
    end

    it 'fetches expected resources for order-sign example' do
      allow(module_instance).to receive(:request_body).and_return(order_sign_request)

      pat_request = stub_request(:get, patient_example_reference_absolute)
        .to_return(status: 200, body: patient_example.to_json)
      p_request = stub_request(:get, practitioner_example_reference_absolute)
        .to_return(status: 200, body: practitioner_example.to_json)

      module_instance.gather_order_sign_data
      expect(module_instance.analyzed_resources[practitioner_example_reference_relative]).to be_present
      expect(module_instance.analyzed_resources[patient_example_reference_relative]).to be_present
      expect(module_instance.analyzed_resources['MedicationRequest/smart-MedicationRequest-103']).to be_present
      expect(module_instance.analyzed_resources['NutritionOrder/pureeddiet-simple']).to be_present
      expect(module_instance.analyzed_resources.size).to eq(4)
      expect(p_request).to have_been_made.once
      expect(pat_request).to have_been_made.once
    end

    it 'fetches expected resources for order-dispatch example' do
      allow(module_instance).to receive(:request_body).and_return(order_dispatch_request)

      pat_request = stub_request(:get, patient_example_reference_absolute)
        .to_return(status: 200, body: patient_example.to_json)
      p_request = stub_request(:get, practitioner_example_reference_absolute)
        .to_return(status: 200, body: practitioner_example.to_json)
      sr_request = stub_request(:get, service_request_example_reference_absolute)
        .to_return(status: 200, body: location_example.to_json)

      module_instance.gather_order_dispatch_data

      expect(module_instance.analyzed_resources[practitioner_example_reference_relative]).to be_present
      expect(module_instance.analyzed_resources[patient_example_reference_relative]).to be_present
      expect(module_instance.analyzed_resources[service_request_example_reference_relative]).to be_present
      expect(module_instance.analyzed_resources['Task/example3']).to be_present
      expect(module_instance.analyzed_resources.size).to eq(4)
      expect(p_request).to have_been_made.once
      expect(pat_request).to have_been_made.once
      expect(sr_request).to have_been_made.once
    end
  end
end
