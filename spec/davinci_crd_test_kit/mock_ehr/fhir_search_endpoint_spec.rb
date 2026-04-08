# ---------------------------------------------------------------------------
# Integration tests — exercises the full HTTP endpoint via FHIRRequestTest
# ---------------------------------------------------------------------------
RSpec.describe DaVinciCRDTestKit::V201::ServerInvokeHookTest, :request do
  let(:suite_id) { 'crd_server' }
  let(:runnable) do
    Class.new(described_class) do
      input :inferno_base_url
    end
  end
  let(:test_session_id) { '12345' }
  let(:token) do
    DaVinciCRDTestKit::MockEHR::FHIRRequestHandler.session_id_to_token(test_session_id)
  end
  let(:base_url) { 'http://example.com' }
  let(:discovery_url) { 'http://example.com/cds-services' }
  let(:inferno_base_url) { 'http://inferno.com' }
  let(:service_ids) { 'appointment-book-service' }
  let(:service_request_body) do
    json = File.read(File.join(__dir__, '..', '..', 'fixtures', 'appointment_book_hook_request.json'))
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
    get(qs.present? ? "#{endpoint_path}?#{qs}" : endpoint_path)

    FHIR.from_contents(last_response.body)
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
end
