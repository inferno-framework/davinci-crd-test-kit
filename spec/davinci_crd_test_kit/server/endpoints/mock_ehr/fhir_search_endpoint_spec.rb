# ---------------------------------------------------------------------------
# Integration tests — exercises the full HTTP endpoint via FHIRRequestTest
# ---------------------------------------------------------------------------
RSpec.describe DaVinciCRDTestKit::V201::ServerInvokeHookTest, :request do
  let(:suite_id) { 'crd_server_v221' }
  let(:runnable) do
    Class.new(described_class) do
      input :inferno_base_url
    end
  end
  let(:test_session_id) { '12345' }
  let(:token) do
    DaVinciCRDTestKit::MockEHR::FHIRRequestHandler.session_id_to_token(test_session_id)
  end
  let(:base_url) { 'http://example.org' }
  let(:discovery_url) { 'http://example.com/cds-services' }
  let(:inferno_base_url) { 'http://inferno.com' }
  let(:service_ids) { 'appointment-book-service' }
  let(:service_request_body) do
    json = File.read(File.join(__dir__, '..', '..', '..', '..', 'fixtures', 'appointment_book_hook_request.json'))
    JSON.parse(json)
  end
  let(:service_request_bodies) { [service_request_body].to_json }
  let(:encryption_method) { 'ES384' }
  # A Patient with known, searchable field values.
  let(:patient) do
    FHIR::Patient.new(
      id: 'patient-search-1',
      gender: 'female',
      birthDate: '1987-02-20',
      name: [
        FHIR::HumanName.new(family: 'Smith', given: %w[John A.], suffix: ['MD']),
        FHIR::HumanName.new(family: 'Jones', given: ['John'])
      ],
      identifier: [
        FHIR::Identifier.new(system: 'http://example.org/mrn', value: 'MRN-12345')
      ],
      address: [
        FHIR::Address.new(city: 'Springfield', state: 'IL', postalCode: '62701', country: 'US')
      ]
    )
  end

  # An Encounter with a closed day-precision period and other typed fields.
  # Note: FHIR::Encounter.new ignores :local_class in the initializer hash;
  # it must be set via the accessor after construction.
  let(:encounter) do
    enc = FHIR::Encounter.new(
      id: 'encounter-search-1',
      status: 'finished',
      type: [
        FHIR::CodeableConcept.new(
          coding: [FHIR::Coding.new(system: 'http://snomed.info/sct', code: '270427003')]
        )
      ],
      subject: FHIR::Reference.new(reference: 'Patient/patient-search-1'),
      identifier: [
        FHIR::Identifier.new(system: 'http://example.org/visits', value: 'V-001')
      ],
      period: FHIR::Period.new(start: '2024-01-10', end: '2024-01-20')
    )
    enc.local_class = FHIR::Coding.new(
      system: 'http://terminology.hl7.org/CodeSystem/v3-ActCode',
      code: 'AMB'
    )
    enc
  end

  let(:bundle) do
    b = FHIR::Bundle.new
    b.entry << FHIR::Bundle::Entry.new(resource: patient)
    b.entry << FHIR::Bundle::Entry.new(resource: encounter)
    b.to_json
  end

  let(:patient_endpoint)   { "/custom/#{suite_id}/fhir/Patient" }
  let(:encounter_endpoint) { "/custom/#{suite_id}/fhir/Encounter" }

  before do
    allow_any_instance_of(DaVinciCRDTestKit::Jobs::InvokeHook) # hook invocations
      .to receive(:perform).and_return(nil)
    allow_any_instance_of(runnable).to receive(:test_session_id).and_return(test_session_id)
  end

  # Starts a waiting test run and issues a GET search request against the mock EHR.
  # Returns the parsed FHIR Bundle response.
  def search(endpoint_path, params = {})
    result = run(runnable, base_url:, inferno_base_url:, service_ids:, encryption_method:, service_request_bodies:,
                           mock_ehr_bundle: bundle)
    expect(result.result).to eq('wait')
    header 'Authorization', "Bearer #{token}"

    qs = params.map { |k, v| "#{k}=#{URI.encode_www_form_component(v.to_s)}" }.join('&')
    request_url = qs.present? ? "#{endpoint_path}?#{qs}" : endpoint_path
    get(request_url)

    response = FHIR.from_contents(last_response.body)
    expect(response.link.find { |link| link.relation == 'self' }&.url)
      .to eq(URI.decode_www_form_component("#{base_url}#{request_url}"))

    response
  end

  # Like search but returns only the self-link URL without asserting it matches
  # the full request URL — needed when unsupported params should be excluded.
  def self_link_for_search(endpoint_path, params = {})
    result = run(runnable, base_url:, inferno_base_url:, service_ids:, encryption_method:,
                           service_request_bodies:, mock_ehr_bundle: bundle)
    expect(result.result).to eq('wait')
    header 'Authorization', "Bearer #{token}"

    qs = params.map { |k, v| "#{k}=#{URI.encode_www_form_component(v.to_s)}" }.join('&')
    get(qs.present? ? "#{endpoint_path}?#{qs}" : endpoint_path)

    FHIR.from_contents(last_response.body).link.find { |l| l.relation == 'self' }&.url
  end

  # -------------------------------------------------------------------------
  # Helpers for common assertions
  # -------------------------------------------------------------------------
  def expect_one_result(response, id)
    expect(last_response.status).to eq(200)
    expect(response.resourceType).to eq('Bundle')
    expect(response.entry.size).to eq(1)
    expect(response.entry.first.resource.id).to eq(id)
  end

  def expect_no_results(response)
    expect(last_response.status).to eq(200)
    expect(response.entry).to be_empty
  end

  # =========================================================================
  # code / else-branch search (Patient.gender)
  # =========================================================================
  describe 'code search — Patient.gender' do
    it 'matches the exact code value' do
      expect_one_result(search(patient_endpoint, gender: 'female'), 'patient-search-1')
    end

    it 'does not match a different code value' do
      expect_no_results(search(patient_endpoint, gender: 'male'))
    end
  end

  # =========================================================================
  # string search (Patient.name.family)
  # =========================================================================
  describe 'string search — Patient.name.family' do
    it 'matches on a prefix' do
      expect_one_result(search(patient_endpoint, family: 'Smi'), 'patient-search-1')
    end

    it 'is case-insensitive' do
      expect_one_result(search(patient_endpoint, family: 'smith'), 'patient-search-1')
    end

    it 'matches the full value' do
      expect_one_result(search(patient_endpoint, family: 'Smith'), 'patient-search-1')
    end

    it 'does not match an infix (non-prefix substring)' do
      expect_no_results(search(patient_endpoint, family: 'mit'))
    end

    it 'does not match a value from a different family name' do
      expect_no_results(search(patient_endpoint, family: 'Brown'))
    end
  end

  # =========================================================================
  # HumanName search (Patient.name)
  # =========================================================================
  describe 'HumanName search — Patient.name' do
    it 'matches on a family-name prefix' do
      expect_one_result(search(patient_endpoint, name: 'Smi'), 'patient-search-1')
    end

    it 'matches on a given-name prefix' do
      expect_one_result(search(patient_endpoint, name: 'Joh'), 'patient-search-1')
    end

    it 'matches on a suffix prefix' do
      expect_one_result(search(patient_endpoint, name: 'MD'), 'patient-search-1')
    end

    it 'is case-insensitive' do
      expect_one_result(search(patient_endpoint, name: 'smi'), 'patient-search-1')
    end

    it 'does not match when no name component starts with the value' do
      expect_no_results(search(patient_endpoint, name: 'Xyz'))
    end
  end

  # =========================================================================
  # CodeableConcept search (Encounter.type)
  # =========================================================================
  describe 'CodeableConcept search — Encounter.type' do
    it 'matches by code alone' do
      expect_one_result(search(encounter_endpoint, type: '270427003'), 'encounter-search-1')
    end

    it 'matches by system|code' do
      expect_one_result(
        search(encounter_endpoint, type: 'http://snomed.info/sct|270427003'),
        'encounter-search-1'
      )
    end

    it 'does not match a wrong code' do
      expect_no_results(search(encounter_endpoint, type: '999999'))
    end

    it 'does not match a right code paired with the wrong system' do
      expect_no_results(search(encounter_endpoint, type: 'http://wrong.system|270427003'))
    end
  end

  # =========================================================================
  # Coding search (Encounter.class)
  # =========================================================================
  describe 'Coding search — Encounter.class' do
    it 'matches by code alone' do
      expect_one_result(search(encounter_endpoint, class: 'AMB'), 'encounter-search-1')
    end

    it 'matches by system|code' do
      expect_one_result(
        search(encounter_endpoint, class: 'http://terminology.hl7.org/CodeSystem/v3-ActCode|AMB'),
        'encounter-search-1'
      )
    end

    it 'is case-insensitive on the code' do
      expect_one_result(search(encounter_endpoint, class: 'amb'), 'encounter-search-1')
    end

    it 'does not match a different code' do
      expect_no_results(search(encounter_endpoint, class: 'IMP'))
    end

    it 'does not match the right code with the wrong system' do
      expect_no_results(
        search(encounter_endpoint, class: 'http://wrong.system|AMB')
      )
    end
  end

  # =========================================================================
  # Identifier search (Encounter.identifier)
  # =========================================================================
  describe 'Identifier search — Encounter.identifier' do
    it 'matches by value alone' do
      expect_one_result(search(encounter_endpoint, identifier: 'V-001'), 'encounter-search-1')
    end

    it 'matches by system|value' do
      expect_one_result(
        search(encounter_endpoint, identifier: 'http://example.org/visits|V-001'),
        'encounter-search-1'
      )
    end

    it 'does not match a wrong value' do
      expect_no_results(search(encounter_endpoint, identifier: 'V-999'))
    end

    it 'does not match the right value paired with the wrong system' do
      expect_no_results(search(encounter_endpoint, identifier: 'http://wrong.system|V-001'))
    end
  end

  # =========================================================================
  # Patient / subject reference search (Encounter.subject)
  # =========================================================================
  describe 'patient/subject reference search — Encounter.patient' do
    it 'matches with a plain patient id' do
      expect_one_result(search(encounter_endpoint, patient: 'patient-search-1'), 'encounter-search-1')
    end

    it 'matches with the Patient/<id> relative-reference format' do
      expect_one_result(
        search(encounter_endpoint, patient: 'Patient/patient-search-1'),
        'encounter-search-1'
      )
    end

    it 'does not match a different patient id' do
      expect_no_results(search(encounter_endpoint, patient: 'patient-99'))
    end
  end

  # =========================================================================
  # date search against a date-type field (Patient.birthDate = 1987-02-20)
  # =========================================================================
  describe 'date search — Patient.birthDate (1987-02-20)' do
    context 'when implicit eq (no comparator)' do
      it 'matches the exact date' do
        expect_one_result(search(patient_endpoint, birthdate: '1987-02-20'), 'patient-search-1')
      end

      it 'matches with month precision (1987-02 contains Feb 20)' do
        expect_one_result(search(patient_endpoint, birthdate: '1987-02'), 'patient-search-1')
      end

      it 'matches with year precision (1987 contains Feb 20)' do
        expect_one_result(search(patient_endpoint, birthdate: '1987'), 'patient-search-1')
      end

      it 'does not match a different day' do
        expect_no_results(search(patient_endpoint, birthdate: '1987-02-21'))
      end

      it 'does not match a different month' do
        expect_no_results(search(patient_endpoint, birthdate: '1987-03'))
      end

      it 'does not match a different year' do
        expect_no_results(search(patient_endpoint, birthdate: '1988'))
      end
    end

    context 'when gt (greater than)' do
      it 'matches when target is one day after the search date' do
        expect_one_result(search(patient_endpoint, birthdate: 'gt1987-02-19'), 'patient-search-1')
      end

      it 'does not match when target equals the search date' do
        expect_no_results(search(patient_endpoint, birthdate: 'gt1987-02-20'))
      end

      it 'does not match when target is before the search date' do
        expect_no_results(search(patient_endpoint, birthdate: 'gt1987-02-21'))
      end
    end

    context 'when lt (less than)' do
      it 'matches when target is one day before the search date' do
        expect_one_result(search(patient_endpoint, birthdate: 'lt1987-02-21'), 'patient-search-1')
      end

      it 'does not match when target equals the search date' do
        expect_no_results(search(patient_endpoint, birthdate: 'lt1987-02-20'))
      end

      it 'does not match when target is after the search date' do
        expect_no_results(search(patient_endpoint, birthdate: 'lt1987-02-19'))
      end
    end

    context 'when ge (greater than or equal)' do
      it 'matches when target equals the search date' do
        expect_one_result(search(patient_endpoint, birthdate: 'ge1987-02-20'), 'patient-search-1')
      end

      it 'matches when target is after the search date' do
        expect_one_result(search(patient_endpoint, birthdate: 'ge1987-02-19'), 'patient-search-1')
      end

      it 'does not match when target is before the search date' do
        expect_no_results(search(patient_endpoint, birthdate: 'ge1987-02-21'))
      end
    end

    context 'when le (less than or equal)' do
      it 'matches when target equals the search date' do
        expect_one_result(search(patient_endpoint, birthdate: 'le1987-02-20'), 'patient-search-1')
      end

      it 'matches when target is before the search date' do
        expect_one_result(search(patient_endpoint, birthdate: 'le1987-02-21'), 'patient-search-1')
      end

      it 'does not match when target is after the search date' do
        expect_no_results(search(patient_endpoint, birthdate: 'le1987-02-19'))
      end
    end

    context 'when ne (not equal)' do
      it 'does not match the same date' do
        expect_no_results(search(patient_endpoint, birthdate: 'ne1987-02-20'))
      end

      it 'does not match the containing month' do
        expect_no_results(search(patient_endpoint, birthdate: 'ne1987-02'))
      end

      it 'matches a different day' do
        expect_one_result(search(patient_endpoint, birthdate: 'ne1987-02-21'), 'patient-search-1')
      end

      it 'matches a different month' do
        expect_one_result(search(patient_endpoint, birthdate: 'ne1987-03'), 'patient-search-1')
      end
    end

    context 'when sa (starts after)' do
      it 'matches when the target day starts the day after the search range ends' do
        expect_one_result(search(patient_endpoint, birthdate: 'sa1987-02-19'), 'patient-search-1')
      end

      it 'does not match when the target and search are the same day' do
        expect_no_results(search(patient_endpoint, birthdate: 'sa1987-02-20'))
      end

      it 'does not match when the target is before the search date' do
        expect_no_results(search(patient_endpoint, birthdate: 'sa1987-02-21'))
      end
    end

    context 'when eb (ends before)' do
      it 'matches when the target day ends the day before the search range starts' do
        expect_one_result(search(patient_endpoint, birthdate: 'eb1987-02-21'), 'patient-search-1')
      end

      it 'does not match when the target and search are the same day' do
        expect_no_results(search(patient_endpoint, birthdate: 'eb1987-02-20'))
      end

      it 'does not match when the target is after the search date' do
        expect_no_results(search(patient_endpoint, birthdate: 'eb1987-02-19'))
      end
    end

    context 'when ap (approximately)' do
      it 'matches the same day' do
        expect_one_result(search(patient_endpoint, birthdate: 'ap1987-02-20'), 'patient-search-1')
      end

      it 'does not match a month that contains the target (search endpoints fall outside target day range)' do
        # ap checks whether search range endpoints fall inside the target range.
        # A month (Feb 1–Feb 28) has endpoints outside a single day (Feb 20), so no match.
        expect_no_results(search(patient_endpoint, birthdate: 'ap1987-02'))
      end

      it 'does not match a different day' do
        expect_no_results(search(patient_endpoint, birthdate: 'ap1987-02-21'))
      end
    end
  end

  # =========================================================================
  # Period search (Encounter.date → Encounter.period = 2024-01-10 .. 2024-01-20)
  # =========================================================================
  describe 'Period search — Encounter.date (period 2024-01-10 to 2024-01-20)' do
    context 'when implicit eq (no comparator — search must fully contain period)' do
      it 'does not match a day inside the period (day cannot contain 10-day period)' do
        expect_no_results(search(encounter_endpoint, date: '2024-01-15'))
      end

      it 'matches a month that fully contains the period' do
        expect_one_result(search(encounter_endpoint, date: '2024-01'), 'encounter-search-1')
      end

      it 'does not match a day outside the period' do
        expect_no_results(search(encounter_endpoint, date: '2024-01-21'))
      end

      it 'does not match a month that only partially covers the period' do
        # 2024-02 starts after the period ends
        expect_no_results(search(encounter_endpoint, date: '2024-02'))
      end
    end

    context 'when gt (range above search overlaps target)' do
      it 'matches when the period extends past the search date' do
        expect_one_result(search(encounter_endpoint, date: 'gt2024-01-15'), 'encounter-search-1')
      end

      it 'does not match when the period ends exactly on the search date' do
        expect_no_results(search(encounter_endpoint, date: 'gt2024-01-20'))
      end

      it 'does not match when the period ends before the search date' do
        expect_no_results(search(encounter_endpoint, date: 'gt2024-01-21'))
      end
    end

    context 'when lt (range below search overlaps target)' do
      it 'matches when the period starts before the search date' do
        expect_one_result(search(encounter_endpoint, date: 'lt2024-01-15'), 'encounter-search-1')
      end

      it 'does not match when the period starts exactly on the search date' do
        expect_no_results(search(encounter_endpoint, date: 'lt2024-01-10'))
      end

      it 'does not match when the period starts after the search date' do
        expect_no_results(search(encounter_endpoint, date: 'lt2024-01-09'))
      end
    end

    context 'when ge (greater than or equal)' do
      it 'matches when the period extends past the search date (via gt)' do
        expect_one_result(search(encounter_endpoint, date: 'ge2024-01-15'), 'encounter-search-1')
      end

      it 'matches at the period start boundary (via gt: period end > search end)' do
        expect_one_result(search(encounter_endpoint, date: 'ge2024-01-10'), 'encounter-search-1')
      end

      it 'does not match when the period ends before the search date' do
        expect_no_results(search(encounter_endpoint, date: 'ge2024-01-21'))
      end
    end

    context 'when le (less than or equal)' do
      it 'matches when the period starts before the search date (via lt)' do
        expect_one_result(search(encounter_endpoint, date: 'le2024-01-15'), 'encounter-search-1')
      end

      it 'matches at the period end boundary (via lt: period start < search start)' do
        expect_one_result(search(encounter_endpoint, date: 'le2024-01-20'), 'encounter-search-1')
      end

      it 'does not match when the period starts after the search date' do
        expect_no_results(search(encounter_endpoint, date: 'le2024-01-09'))
      end
    end

    context 'when ne (not equal)' do
      it 'matches when the search is outside the period' do
        expect_one_result(search(encounter_endpoint, date: 'ne2024-01-25'), 'encounter-search-1')
      end

      it 'does not match when the search month fully contains the period' do
        expect_no_results(search(encounter_endpoint, date: 'ne2024-01'))
      end
    end

    context 'when sa (target starts after search range)' do
      it 'matches when the period starts the day after the search date range' do
        # search=2024-01-09 → search ends Jan 9 23:59:59; period starts Jan 10 00:00
        expect_one_result(search(encounter_endpoint, date: 'sa2024-01-09'), 'encounter-search-1')
      end

      it 'does not match when the period starts on the search date' do
        expect_no_results(search(encounter_endpoint, date: 'sa2024-01-10'))
      end

      it 'does not match when the period starts before the search date' do
        expect_no_results(search(encounter_endpoint, date: 'sa2024-01-15'))
      end
    end

    context 'when eb (target ends before search range)' do
      it 'matches when the period ends the day before the search date range' do
        # search=2024-01-21 → search starts Jan 21 00:00; period ends Jan 20 23:59:59
        expect_one_result(search(encounter_endpoint, date: 'eb2024-01-21'), 'encounter-search-1')
      end

      it 'does not match when the period ends on the search date' do
        expect_no_results(search(encounter_endpoint, date: 'eb2024-01-20'))
      end

      it 'does not match when the period ends after the search date' do
        expect_no_results(search(encounter_endpoint, date: 'eb2024-01-15'))
      end
    end

    context 'when ap (approximately — search overlaps period)' do
      it 'matches when search equals the period start' do
        expect_one_result(search(encounter_endpoint, date: 'ap2024-01-10'), 'encounter-search-1')
      end

      it 'matches when search equals the period end' do
        expect_one_result(search(encounter_endpoint, date: 'ap2024-01-20'), 'encounter-search-1')
      end

      it 'matches when search falls inside the period' do
        expect_one_result(search(encounter_endpoint, date: 'ap2024-01-15'), 'encounter-search-1')
      end

      it 'does not match when search is the day after the period ends' do
        expect_no_results(search(encounter_endpoint, date: 'ap2024-01-21'))
      end

      it 'does not match when search is the day before the period starts' do
        expect_no_results(search(encounter_endpoint, date: 'ap2024-01-09'))
      end
    end
  end

  # =========================================================================
  # Multiple search parameters (AND logic)
  # =========================================================================
  describe 'multiple search parameters (AND logic)' do
    it 'returns a result only when all parameters match' do
      expect_one_result(
        search(encounter_endpoint, patient: 'patient-search-1', status: 'finished'),
        'encounter-search-1'
      )
    end

    it 'returns no results when any parameter does not match' do
      expect_no_results(
        search(encounter_endpoint, patient: 'patient-search-1', status: 'in-progress')
      )
    end

    it 'returns no results when all parameters are individually valid but for different resources' do
      expect_no_results(
        search(encounter_endpoint, patient: 'patient-99', status: 'finished')
      )
    end
  end

  # =========================================================================
  # Empty result
  # =========================================================================
  describe 'search with no matching resources' do
    it 'returns an empty searchset bundle' do
      response = search(patient_endpoint, gender: 'other')
      expect(last_response.status).to eq(200)
      expect(response.resourceType).to eq('Bundle')
      expect(response.entry).to be_empty
    end
  end

  # =========================================================================
  # search.mode values
  # =========================================================================
  describe 'search.mode on bundle entries' do
    it "sets mode='match' on all directly matched resources" do
      response = search(patient_endpoint, gender: 'female')
      expect(response.entry).to_not be_empty
      expect(response.entry.all? { |e| e.search&.mode == 'match' }).to be true
    end

    it "sets mode='include' on resources returned via _include" do
      medication = FHIR::Medication.new(id: 'med-1')
      medication_dispense = FHIR::MedicationDispense.new(
        id: 'med-dispense-1',
        status: 'completed',
        subject: FHIR::Reference.new(reference: 'Patient/patient-search-1'),
        medicationReference: FHIR::Reference.new(reference: 'Medication/med-1')
      )
      med_bundle = FHIR::Bundle.new
      med_bundle.entry << FHIR::Bundle::Entry.new(resource: patient)
      med_bundle.entry << FHIR::Bundle::Entry.new(resource: medication)
      med_bundle.entry << FHIR::Bundle::Entry.new(resource: medication_dispense)

      result = run(runnable, base_url:, inferno_base_url:, service_ids:, encryption_method:,
                             service_request_bodies:, mock_ehr_bundle: med_bundle.to_json)
      expect(result.result).to eq('wait')
      header 'Authorization', "Bearer #{token}"
      get "/custom/#{suite_id}/fhir/MedicationDispense?patient=patient-search-1" \
          '&_include=MedicationDispense%3Amedication'

      response = FHIR.from_contents(last_response.body)
      include_entry = response.entry.find { |e| e.resource.resourceType == 'Medication' }
      expect(include_entry).to_not be_nil
      expect(include_entry.search&.mode).to eq('include')
    end

    it "sets mode='include' on resources returned via _revinclude" do
      provenance = FHIR::Provenance.new(
        id: 'provenance-1',
        target: [FHIR::Reference.new(reference: 'Patient/patient-search-1')],
        recorded: '2024-01-10T12:00:00Z'
      )
      prov_bundle = FHIR::Bundle.new
      prov_bundle.entry << FHIR::Bundle::Entry.new(resource: patient)
      prov_bundle.entry << FHIR::Bundle::Entry.new(resource: encounter)
      prov_bundle.entry << FHIR::Bundle::Entry.new(resource: provenance)

      result = run(runnable, base_url:, inferno_base_url:, service_ids:, encryption_method:,
                             service_request_bodies:, mock_ehr_bundle: prov_bundle.to_json)
      expect(result.result).to eq('wait')
      header 'Authorization', "Bearer #{token}"
      get "/custom/#{suite_id}/fhir/Patient?gender=female&_revinclude=Provenance%3Atarget"

      response = FHIR.from_contents(last_response.body)
      revinclude_entry = response.entry.find { |e| e.resource.resourceType == 'Provenance' }
      expect(revinclude_entry).to_not be_nil
      expect(revinclude_entry.search&.mode).to eq('include')
    end
  end

  # =========================================================================
  # No search parameters (resource-type-only search)
  # =========================================================================
  describe 'search with no search parameters' do
    it 'returns all resources of the requested type' do
      response = search(patient_endpoint)
      expect(last_response.status).to eq(200)
      expect(response.resourceType).to eq('Bundle')
      expect(response.entry.size).to eq(1)
      expect(response.entry.first.resource.resourceType).to eq('Patient')
      expect(response.entry.first.resource.id).to eq('patient-search-1')
    end

    it 'does not return resources of a different type' do
      response = search(patient_endpoint)
      expect(response.entry.none? { |e| e.resource.resourceType == 'Encounter' }).to be true
    end
  end

  # =========================================================================
  # Self-link construction
  # =========================================================================
  describe 'self-link construction' do
    let(:medication_dispense_endpoint) { "/custom/#{suite_id}/fhir/MedicationDispense" }

    context 'with search parameters' do
      it 'includes supported search params' do
        self_link = self_link_for_search(patient_endpoint, gender: 'female')
        expect(self_link).to eq("#{base_url}#{patient_endpoint}?gender=female")
      end

      it 'excludes unsupported (unknown) params' do
        self_link = self_link_for_search(patient_endpoint, gender: 'female', unknown_param: 'foo')
        expect(self_link).to eq("#{base_url}#{patient_endpoint}?gender=female")
      end

      it 'produces no query string when all params are unsupported' do
        self_link = self_link_for_search(patient_endpoint, unknown_param: 'foo')
        expect(self_link).to eq("#{base_url}#{patient_endpoint}")
      end
    end

    context 'with _include parameter' do
      it 'includes _include when the value is a supported include param' do
        self_link = self_link_for_search(medication_dispense_endpoint,
                                         patient: 'patient-search-1',
                                         _include: 'MedicationDispense:medication')
        expect(self_link).to include('patient=patient-search-1')
        expect(self_link).to include('_include=MedicationDispense:medication')
      end

      it 'excludes _include when the value is not a supported include param' do
        self_link = self_link_for_search(patient_endpoint, gender: 'female', _include: 'Patient:not-real')
        expect(self_link).to eq("#{base_url}#{patient_endpoint}?gender=female")
      end
    end

    context 'with _revinclude parameter' do
      it 'includes _revinclude=Provenance:target' do
        self_link = self_link_for_search(patient_endpoint, gender: 'female', _revinclude: 'Provenance:target')
        expect(self_link).to include('gender=female')
        expect(self_link).to include('_revinclude=Provenance:target')
      end

      it 'excludes _revinclude when the value is not Provenance:target' do
        self_link = self_link_for_search(patient_endpoint, gender: 'female', _revinclude: 'Observation:subject')
        expect(self_link).to eq("#{base_url}#{patient_endpoint}?gender=female")
      end
    end
  end

  # =========================================================================
  # _include search (MedicationDispense:medication)
  # =========================================================================
  describe '_include search — MedicationDispense:medication' do
    let(:medication) { FHIR::Medication.new(id: 'med-1') }

    let(:medication_dispense) do
      FHIR::MedicationDispense.new(
        id: 'med-dispense-1',
        status: 'completed',
        subject: FHIR::Reference.new(reference: 'Patient/patient-search-1'),
        medicationReference: FHIR::Reference.new(reference: 'Medication/med-1')
      )
    end

    let(:bundle) do
      b = FHIR::Bundle.new
      b.entry << FHIR::Bundle::Entry.new(resource: patient)
      b.entry << FHIR::Bundle::Entry.new(resource: medication)
      b.entry << FHIR::Bundle::Entry.new(resource: medication_dispense)
      b.to_json
    end

    let(:medication_dispense_endpoint) { "/custom/#{suite_id}/fhir/MedicationDispense" }

    it 'includes the referenced Medication alongside the matching MedicationDispense' do
      response = search(medication_dispense_endpoint, patient: 'patient-search-1',
                                                      _include: 'MedicationDispense:medication')
      expect(last_response.status).to eq(200)
      match_entries = response.entry.select { |e| e.search&.mode == 'match' }
      include_entries = response.entry.select { |e| e.search&.mode == 'include' }
      expect(match_entries.size).to eq(1)
      expect(match_entries.first.resource.id).to eq('med-dispense-1')
      expect(include_entries.size).to eq(1)
      expect(include_entries.first.resource.resourceType).to eq('Medication')
      expect(include_entries.first.resource.id).to eq('med-1')
    end

    it 'does not return included resources when no resources match the base search' do
      response = search(medication_dispense_endpoint, patient: 'unknown-patient',
                                                      _include: 'MedicationDispense:medication')
      expect(last_response.status).to eq(200)
      expect(response.entry).to be_empty
    end

    it 'does not include the Medication when no _include param is sent' do
      response = search(medication_dispense_endpoint, patient: 'patient-search-1')
      expect(last_response.status).to eq(200)
      expect(response.entry.size).to eq(1)
      expect(response.entry.first.resource.resourceType).to eq('MedicationDispense')
      expect(response.entry.first.search.mode).to eq('match')
    end

    context 'when multiple matching dispenses reference the same medication' do
      let(:medication_dispense2) do
        FHIR::MedicationDispense.new(
          id: 'med-dispense-2',
          status: 'in-progress',
          subject: FHIR::Reference.new(reference: 'Patient/patient-search-1'),
          medicationReference: FHIR::Reference.new(reference: 'Medication/med-1')
        )
      end

      let(:bundle) do
        b = FHIR::Bundle.new
        b.entry << FHIR::Bundle::Entry.new(resource: patient)
        b.entry << FHIR::Bundle::Entry.new(resource: medication)
        b.entry << FHIR::Bundle::Entry.new(resource: medication_dispense)
        b.entry << FHIR::Bundle::Entry.new(resource: medication_dispense2)
        b.to_json
      end

      it 'includes the shared referenced Medication only once' do
        response = search(medication_dispense_endpoint, patient: 'patient-search-1',
                                                        _include: 'MedicationDispense:medication')
        match_entries = response.entry.select { |e| e.search&.mode == 'match' }
        include_entries = response.entry.select { |e| e.search&.mode == 'include' }
        expect(match_entries.size).to eq(2)
        expect(include_entries.size).to eq(1)
        expect(include_entries.first.resource.id).to eq('med-1')
      end
    end
  end

  # =========================================================================
  # _revinclude search (Provenance:target)
  # =========================================================================
  describe '_revinclude search — Provenance:target' do
    let(:provenance) do
      FHIR::Provenance.new(
        id: 'provenance-1',
        target: [FHIR::Reference.new(reference: 'Patient/patient-search-1')],
        recorded: '2024-01-10T12:00:00Z'
      )
    end

    let(:bundle) do
      b = FHIR::Bundle.new
      b.entry << FHIR::Bundle::Entry.new(resource: patient)
      b.entry << FHIR::Bundle::Entry.new(resource: encounter)
      b.entry << FHIR::Bundle::Entry.new(resource: provenance)
      b.to_json
    end

    it 'includes Provenance resources that target a matching resource' do
      response = search(patient_endpoint, gender: 'female', _revinclude: 'Provenance:target')
      expect(last_response.status).to eq(200)
      match_entries = response.entry.select { |e| e.search&.mode == 'match' }
      include_entries = response.entry.select { |e| e.search&.mode == 'include' }
      expect(match_entries.size).to eq(1)
      expect(match_entries.first.resource.id).to eq('patient-search-1')
      expect(include_entries.size).to eq(1)
      expect(include_entries.first.resource.resourceType).to eq('Provenance')
      expect(include_entries.first.resource.id).to eq('provenance-1')
    end

    it 'does not include Provenance when no resources match the base search' do
      response = search(patient_endpoint, gender: 'other', _revinclude: 'Provenance:target')
      expect(last_response.status).to eq(200)
      expect(response.entry).to be_empty
    end

    it 'does not revinclude Provenance that targets only non-matched resources' do
      # Provenance targets Patient but we are searching Encounters — Patient is not in match set
      response = search(encounter_endpoint, patient: 'patient-search-1', _revinclude: 'Provenance:target')
      expect(last_response.status).to eq(200)
      include_entries = response.entry.select { |e| e.search&.mode == 'include' }
      expect(include_entries).to be_empty
    end

    it 'does not return Provenance when the _revinclude param is absent' do
      response = search(patient_endpoint, gender: 'female')
      expect(last_response.status).to eq(200)
      expect(response.entry.size).to eq(1)
      expect(response.entry.first.resource.resourceType).to eq('Patient')
    end

    context 'when multiple Provenance resources target the same matched resource' do
      let(:provenance2) do
        FHIR::Provenance.new(
          id: 'provenance-2',
          target: [FHIR::Reference.new(reference: 'Patient/patient-search-1')],
          recorded: '2024-02-01T09:00:00Z'
        )
      end

      let(:bundle) do
        b = FHIR::Bundle.new
        b.entry << FHIR::Bundle::Entry.new(resource: patient)
        b.entry << FHIR::Bundle::Entry.new(resource: encounter)
        b.entry << FHIR::Bundle::Entry.new(resource: provenance)
        b.entry << FHIR::Bundle::Entry.new(resource: provenance2)
        b.to_json
      end

      it 'includes all Provenance resources that target the matched resource' do
        response = search(patient_endpoint, gender: 'female', _revinclude: 'Provenance:target')
        include_entries = response.entry.select { |e| e.search&.mode == 'include' }
        expect(include_entries.size).to eq(2)
        expect(include_entries.map { |e| e.resource.id }).to contain_exactly('provenance-1', 'provenance-2')
      end
    end
  end

  # =========================================================================
  # Response headers
  # =========================================================================
  describe 'response headers' do
    it 'sets Content-Type to application/fhir+json' do
      search(patient_endpoint, gender: 'female')
      expect(last_response.headers['Content-Type']).to include('application/fhir+json')
    end

    it 'sets Access-Control-Allow-Origin to *' do
      search(patient_endpoint, gender: 'female')
      expect(last_response.headers['Access-Control-Allow-Origin']).to eq('*')
    end
  end

  # =========================================================================
  # Authorization
  # =========================================================================
  describe 'authorization' do
    it 'returns an error when the Authorization header is missing' do
      result = run(runnable, base_url:, inferno_base_url:, service_ids:, encryption_method:,
                             service_request_bodies:, mock_ehr_bundle: bundle)
      expect(result.result).to eq('wait')
      get patient_endpoint
      expect(last_response.status).to be >= 400
    end
  end
end
