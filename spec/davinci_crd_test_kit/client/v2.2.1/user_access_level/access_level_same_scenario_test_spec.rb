require_relative '../../../../../lib/davinci_crd_test_kit/client/v2.2.1/user_access_level/access_level_same_scenario_test' # rubocop:disable Layout/LineLength
require_relative '../../../../../lib/davinci_crd_test_kit/cross_suite/tags'

RSpec.describe DaVinciCRDTestKit::V221::AccessLevelSameScenarioTest do
  let(:suite_id) { 'crd_client_v221' }
  let(:test) { described_class }
  let(:result) { repo_create(:result, test_session_id: test_session.id) }
  let(:results_repo) { Inferno::Repositories::Results.new }

  let(:patient_id) { 'pat-1' }
  let(:fhir_server) { 'https://example.org/fhir' }
  let(:draft_order) { { 'resourceType' => 'MedicationRequest', 'id' => 'med-1' } }

  let(:full_body) do
    {
      'hook' => 'order-sign',
      'hookInstance' => 'full-instance',
      'fhirServer' => 'https://full.example.org/fhir',
      'context' => {
        'patientId' => patient_id,
        'draftOrders' => { 'resourceType' => 'Bundle', 'entry' => [{ 'resource' => draft_order }] }
      }
    }
  end
  let(:limited_body) do
    JSON.parse(full_body.to_json).tap do |body|
      body['hookInstance'] = 'limited-instance'
      body['fhirServer'] = 'https://limited.example.org/fhir'
    end
  end

  def create_hook_request(tag, body)
    repo_create(
      :request,
      direction: 'incoming',
      url: "https://example.com/cds-services/#{body['hook']}-service",
      result:,
      test_session_id: test_session.id,
      request_body: body.is_a?(Hash) ? body.to_json : body,
      status: 200,
      headers: [],
      tags: [tag]
    )
  end

  def run_both(full, limited)
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_FULL_GROUP_TAG, full)
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_LIMITED_GROUP_TAG, limited)
    run(test)
  end

  def messages_of_type(result, type)
    results_repo.current_results_for_test_session_and_runnables(test_session.id, [test])
      .find { |r| r.id == result.id }
      .messages.select { |message| message.type == type }.map(&:message).join("\n")
  end

  def error_messages(result)
    messages_of_type(result, 'error')
  end

  def warning_messages(result)
    messages_of_type(result, 'warning')
  end

  # -- resource builders -------------------------------------------------------------------------

  def med_order(id, code)
    { 'resourceType' => 'MedicationRequest', 'id' => id,
      'medicationCodeableConcept' => {
        'coding' => [{ 'system' => 'http://www.nlm.nih.gov/research/umls/rxnorm', 'code' => code }]
      } }
  end

  def service_order(id, code)
    { 'resourceType' => 'ServiceRequest', 'id' => id,
      'code' => { 'coding' => [{ 'system' => 'http://snomed.info/sct', 'code' => code }] } }
  end

  def appointment(id, service_code, start)
    { 'resourceType' => 'Appointment', 'id' => id,
      'serviceType' => [{ 'coding' => [{ 'system' => 'http://example.org/service', 'code' => service_code }] }],
      'start' => start }
  end

  def encounter(id, class_code, start)
    { 'resourceType' => 'Encounter', 'id' => id,
      'class' => { 'system' => 'http://terminology.hl7.org/CodeSystem/v3-ActCode', 'code' => class_code },
      'period' => { 'start' => start } }
  end

  # -- request builders --------------------------------------------------------------------------

  def order_sign_body(instance, orders)
    { 'hook' => 'order-sign', 'hookInstance' => instance, 'fhirServer' => fhir_server,
      'context' => { 'patientId' => patient_id,
                     'draftOrders' => { 'resourceType' => 'Bundle',
                                        'entry' => orders.map { |order| { 'resource' => order } } } } }
  end

  def appointment_book_body(instance, appointments)
    { 'hook' => 'appointment-book', 'hookInstance' => instance, 'fhirServer' => fhir_server,
      'context' => { 'patientId' => patient_id,
                     'appointments' => { 'resourceType' => 'Bundle',
                                         'entry' => appointments.map { |appt| { 'resource' => appt } } } } }
  end

  def encounter_start_body(instance, encounter_id, prefetch: {})
    { 'hook' => 'encounter-start', 'hookInstance' => instance, 'fhirServer' => fhir_server,
      'prefetch' => prefetch,
      'context' => { 'patientId' => patient_id, 'encounterId' => encounter_id } }
  end

  def order_dispatch_body(instance, dispatched_orders, prefetch: {})
    { 'hook' => 'order-dispatch', 'hookInstance' => instance, 'fhirServer' => fhir_server,
      'prefetch' => prefetch,
      'context' => { 'patientId' => patient_id, 'performer' => 'Practitioner/prac-1',
                     'dispatchedOrders' => dispatched_orders } }
  end

  # -- shared checks -----------------------------------------------------------------------------

  it 'skips when the full-access hook request was not successful' do
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_LIMITED_GROUP_TAG, limited_body)
    result = run(test)
    expect(result.result).to eq('skip')
    expect(result.result_message).to include('Full-access hook request was not successful')
  end

  it 'skips when the limited-access hook request was not successful' do
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_FULL_GROUP_TAG, full_body)
    result = run(test)
    expect(result.result).to eq('skip')
    expect(result.result_message).to include('Limited-access hook request was not successful')
  end

  it 'passes when both requests reference the same hook, patient, and draft orders' do
    expect(run_both(full_body, limited_body).result).to eq('pass')
  end

  it 'passes even when the fhirServer and hookInstance differ between the two requests' do
    expect(full_body['fhirServer']).to_not eq(limited_body['fhirServer'])
    expect(run_both(full_body, limited_body).result).to eq('pass')
  end

  it 'fails when the two requests invoke different hooks' do
    limited_body['hook'] = 'order-select'
    result = run_both(full_body, limited_body)
    expect(result.result).to eq('fail')
    expect(error_messages(result)).to include('must invoke the same hook')
    expect(error_messages(result)).to include("'order-sign' hook")
    expect(error_messages(result)).to include("'order-select' hook")
  end

  it 'fails when the two requests are for different patients' do
    limited_body['context']['patientId'] = 'pat-2'
    result = run_both(full_body, limited_body)
    expect(result.result).to eq('fail')
    expect(error_messages(result)).to include('different patients')
    expect(error_messages(result)).to include('"pat-1"')
    expect(error_messages(result)).to include('"pat-2"')
  end

  it 'fails when the hook does not identify any order, appointment, or encounter' do
    body_without_context = { 'hook' => 'order-sign', 'hookInstance' => 'full-instance',
                             'context' => { 'patientId' => patient_id } }
    result = run_both(body_without_context, body_without_context.merge('hookInstance' => 'limited-instance'))
    expect(result.result).to eq('fail')
    expect(error_messages(result)).to include('could not identify the order, appointment, or encounter')
  end

  it 'fails when a hook request body is not valid JSON' do
    result = run_both('not valid json', limited_body)
    expect(result.result).to eq('fail')
    expect(result.result_message).to include('Unable to parse')
  end

  # -- order hooks -------------------------------------------------------------------------------

  it 'passes when the draft orders differ but carry the same order code' do
    full = order_sign_body('full-instance', [med_order('med-1', '1049502')])
    limited = order_sign_body('limited-instance', [med_order('med-2', '1049502')])

    expect(run_both(full, limited).result).to eq('pass')
  end

  it 'fails when the draft orders differ and carry different order codes' do
    full = order_sign_body('full-instance', [med_order('med-1', '1049502')])
    limited = order_sign_body('limited-instance', [med_order('med-2', '9999999')])

    result = run_both(full, limited)
    expect(result.result).to eq('fail')
    expect(error_messages(result)).to include('whose details also differ')
    expect(error_messages(result)).to include('MedicationRequest/med-1')
    expect(error_messages(result)).to include('MedicationRequest/med-2')
  end

  it 'matches orders that point to a medication instance rather than carrying a code' do
    referencing_order = lambda do |id|
      { 'resourceType' => 'MedicationRequest', 'id' => id,
        'medicationReference' => { 'reference' => 'Medication/med-abc' } }
    end
    full = order_sign_body('full-instance', [referencing_order.call('med-1')])
    limited = order_sign_body('limited-instance', [referencing_order.call('med-2')])

    expect(run_both(full, limited).result).to eq('pass')
  end

  it 'warns without failing when the draft orders differ and carry no comparable details' do
    full = order_sign_body('full-instance', [{ 'resourceType' => 'MedicationRequest', 'id' => 'med-1' }])
    limited = order_sign_body('limited-instance', [{ 'resourceType' => 'MedicationRequest', 'id' => 'med-2' }])

    result = run_both(full, limited)
    expect(result.result).to eq('pass')
    expect(warning_messages(result)).to include('could not compare their details')
    expect(warning_messages(result)).to include('MedicationRequest/med-1')
  end

  # -- appointment-book --------------------------------------------------------------------------

  it 'passes for appointment-book requests that reference the same appointment' do
    appt = appointment('apt-1', 'wellness', '2026-09-22T09:00:00Z')
    full = appointment_book_body('full-instance', [appt])
    limited = appointment_book_body('limited-instance', [appt])

    expect(run_both(full, limited).result).to eq('pass')
  end

  it 'passes when the appointments differ but share a service type and date' do
    full = appointment_book_body('full-instance', [appointment('apt-1', 'wellness', '2026-09-22T09:00:00Z')])
    limited = appointment_book_body('limited-instance', [appointment('apt-2', 'wellness', '2026-09-22T14:30:00Z')])

    expect(run_both(full, limited).result).to eq('pass')
  end

  it 'fails when the appointments differ in service type' do
    full = appointment_book_body('full-instance', [appointment('apt-1', 'wellness', '2026-09-22T09:00:00Z')])
    limited = appointment_book_body('limited-instance', [appointment('apt-2', 'surgery', '2026-09-22T09:00:00Z')])

    result = run_both(full, limited)
    expect(result.result).to eq('fail')
    expect(error_messages(result)).to include('whose details also differ')
  end

  # -- encounter hooks ---------------------------------------------------------------------------

  it 'passes for encounter-start requests that reference the same encounter' do
    full = encounter_start_body('full-instance', 'enc-1')
    limited = encounter_start_body('limited-instance', 'enc-1')

    expect(run_both(full, limited).result).to eq('pass')
  end

  it 'passes when the encounters differ but the prefetched encounters share a class and date' do
    full = encounter_start_body('full-instance', 'enc-1',
                                prefetch: { 'encounter' => encounter('enc-1', 'AMB', '2026-09-22T09:00:00Z') })
    limited = encounter_start_body('limited-instance', 'enc-2',
                                   prefetch: { 'encounter' => encounter('enc-2', 'AMB', '2026-09-22T16:00:00Z') })

    expect(run_both(full, limited).result).to eq('pass')
  end

  it 'fails when the prefetched encounters differ in class' do
    full = encounter_start_body('full-instance', 'enc-1',
                                prefetch: { 'encounter' => encounter('enc-1', 'AMB', '2026-09-22T09:00:00Z') })
    limited = encounter_start_body('limited-instance', 'enc-2',
                                   prefetch: { 'encounter' => encounter('enc-2', 'IMP', '2026-09-22T09:00:00Z') })

    result = run_both(full, limited)
    expect(result.result).to eq('fail')
    expect(error_messages(result)).to include('whose details also differ')
    expect(error_messages(result)).to include('Encounter/enc-1')
  end

  it 'warns without failing when the encounters differ and were not prefetched' do
    full = encounter_start_body('full-instance', 'enc-1')
    limited = encounter_start_body('limited-instance', 'enc-2')

    result = run_both(full, limited)
    expect(result.result).to eq('pass')
    expect(warning_messages(result)).to include('could not compare their details')
    expect(warning_messages(result)).to include('Encounter/enc-1')
    expect(warning_messages(result)).to include('Encounter/enc-2')
  end

  # -- order-dispatch ----------------------------------------------------------------------------

  it 'passes for order-dispatch requests that dispatch the same orders' do
    full = order_dispatch_body('full-instance', ['ServiceRequest/sr-1'])
    limited = order_dispatch_body('limited-instance', ['ServiceRequest/sr-1'])

    expect(run_both(full, limited).result).to eq('pass')
  end

  it 'passes when the dispatched orders differ but the prefetched orders share a code' do
    full = order_dispatch_body('full-instance', ['ServiceRequest/sr-1'],
                               prefetch: { 'order' => service_order('sr-1', '24623002') })
    limited = order_dispatch_body('limited-instance', ['ServiceRequest/sr-2'],
                                  prefetch: { 'order' => service_order('sr-2', '24623002') })

    expect(run_both(full, limited).result).to eq('pass')
  end

  it 'fails when the prefetched dispatched orders carry different codes' do
    full = order_dispatch_body('full-instance', ['ServiceRequest/sr-1'],
                               prefetch: { 'order' => service_order('sr-1', '24623002') })
    limited = order_dispatch_body('limited-instance', ['ServiceRequest/sr-2'],
                                  prefetch: { 'order' => service_order('sr-2', '76145000') })

    result = run_both(full, limited)
    expect(result.result).to eq('fail')
    expect(error_messages(result)).to include('whose details also differ')
  end

  it 'does not read order-dispatch context from the v2.0.1 `order` field' do
    full = { 'hook' => 'order-dispatch', 'hookInstance' => 'full-instance',
             'context' => { 'patientId' => patient_id, 'order' => 'ServiceRequest/sr-1' } }
    limited = JSON.parse(full.to_json).merge('hookInstance' => 'limited-instance')

    result = run_both(full, limited)
    expect(result.result).to eq('fail')
    expect(error_messages(result)).to include('could not identify the order, appointment, or encounter')
  end
end
