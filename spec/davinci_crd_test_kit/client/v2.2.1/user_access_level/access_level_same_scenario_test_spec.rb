require_relative '../../../../../lib/davinci_crd_test_kit/client/v2.2.1/user_access_level/access_level_same_scenario_test' # rubocop:disable Layout/LineLength
require_relative '../../../../../lib/davinci_crd_test_kit/cross_suite/tags'

RSpec.describe DaVinciCRDTestKit::V221::AccessLevelSameScenarioTest do
  let(:suite_id) { 'crd_client_v221' }
  let(:test) { described_class }
  let(:result) { repo_create(:result, test_session_id: test_session.id) }

  let(:patient_id) { 'pat-1' }
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

  it 'skips when no full-access hook request has been received' do
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_LIMITED_GROUP_TAG, limited_body)
    result = run(test)
    expect(result.result).to eq('skip')
    expect(result.result_message).to match(/No full-access hook request/)
  end

  it 'skips when no limited-access hook request has been received' do
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_FULL_GROUP_TAG, full_body)
    result = run(test)
    expect(result.result).to eq('skip')
    expect(result.result_message).to match(/No limited-access hook request/)
  end

  it 'passes when both requests reference the same hook, patient, and draft orders' do
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_FULL_GROUP_TAG, full_body)
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_LIMITED_GROUP_TAG, limited_body)
    expect(run(test).result).to eq('pass')
  end

  it 'passes even when the fhirServer and hookInstance differ between the two requests' do
    expect(full_body['fhirServer']).to_not eq(limited_body['fhirServer'])
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_FULL_GROUP_TAG, full_body)
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_LIMITED_GROUP_TAG, limited_body)
    expect(run(test).result).to eq('pass')
  end

  it 'fails when the two requests invoke different hooks' do
    limited_body['hook'] = 'order-select'
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_FULL_GROUP_TAG, full_body)
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_LIMITED_GROUP_TAG, limited_body)
    result = run(test)
    expect(result.result).to eq('fail')
    expect(result.result_message).to match(/must invoke the same hook/)
    expect(result.result_message).to include("'order-sign' hook")
    expect(result.result_message).to include("'order-select' hook")
  end

  it 'fails when the two requests are for different patients' do
    limited_body['context']['patientId'] = 'pat-2'
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_FULL_GROUP_TAG, full_body)
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_LIMITED_GROUP_TAG, limited_body)
    result = run(test)
    expect(result.result).to eq('fail')
    expect(result.result_message).to match(/different patients/)
    expect(result.result_message).to include('"pat-1"')
    expect(result.result_message).to include('"pat-2"')
  end

  it 'fails when the two requests reference different draft orders' do
    limited_body['context']['draftOrders']['entry'].first['resource']['id'] = 'med-2'
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_FULL_GROUP_TAG, full_body)
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_LIMITED_GROUP_TAG, limited_body)
    result = run(test)
    expect(result.result).to eq('fail')
    expect(result.result_message).to match(/do not reference the same order/)
    expect(result.result_message).to include('MedicationRequest/med-1')
    expect(result.result_message).to include('MedicationRequest/med-2')
  end

  it 'passes for appointment-book requests that reference the same appointment' do
    appointment = { 'resourceType' => 'Appointment', 'id' => 'apt-1' }
    full_appointment_body = {
      'hook' => 'appointment-book',
      'hookInstance' => 'full-instance',
      'context' => {
        'patientId' => patient_id,
        'appointments' => { 'resourceType' => 'Bundle', 'entry' => [{ 'resource' => appointment }] }
      }
    }
    limited_appointment_body = JSON.parse(full_appointment_body.to_json)
    limited_appointment_body['hookInstance'] = 'limited-instance'

    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_FULL_GROUP_TAG, full_appointment_body)
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_LIMITED_GROUP_TAG, limited_appointment_body)
    expect(run(test).result).to eq('pass')
  end

  it 'passes for encounter-start requests that reference the same encounter' do
    full_encounter_body = {
      'hook' => 'encounter-start',
      'hookInstance' => 'full-instance',
      'context' => { 'patientId' => patient_id, 'encounterId' => 'enc-1' }
    }
    limited_encounter_body = JSON.parse(full_encounter_body.to_json)
    limited_encounter_body['hookInstance'] = 'limited-instance'

    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_FULL_GROUP_TAG, full_encounter_body)
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_LIMITED_GROUP_TAG, limited_encounter_body)
    expect(run(test).result).to eq('pass')
  end

  it 'fails for encounter-start requests that reference different encounters' do
    full_encounter_body = {
      'hook' => 'encounter-start',
      'hookInstance' => 'full-instance',
      'context' => { 'patientId' => patient_id, 'encounterId' => 'enc-1' }
    }
    limited_encounter_body = JSON.parse(full_encounter_body.to_json)
    limited_encounter_body['hookInstance'] = 'limited-instance'
    limited_encounter_body['context']['encounterId'] = 'enc-2'

    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_FULL_GROUP_TAG, full_encounter_body)
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_LIMITED_GROUP_TAG, limited_encounter_body)
    result = run(test)
    expect(result.result).to eq('fail')
    expect(result.result_message).to match(/do not reference the same order/)
    expect(result.result_message).to include('enc-1')
    expect(result.result_message).to include('enc-2')
  end

  it 'passes for order-dispatch requests that reference the same order' do
    full_dispatch_body = {
      'hook' => 'order-dispatch',
      'hookInstance' => 'full-instance',
      'context' => { 'patientId' => patient_id, 'order' => 'ServiceRequest/sr-1' }
    }
    limited_dispatch_body = JSON.parse(full_dispatch_body.to_json)
    limited_dispatch_body['hookInstance'] = 'limited-instance'

    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_FULL_GROUP_TAG, full_dispatch_body)
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_LIMITED_GROUP_TAG, limited_dispatch_body)
    expect(run(test).result).to eq('pass')
  end

  it 'fails when a hook request body is not valid JSON' do
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_FULL_GROUP_TAG, 'not valid json')
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_LIMITED_GROUP_TAG, limited_body)
    result = run(test)
    expect(result.result).to eq('fail')
    expect(result.result_message).to match(/Unable to parse/)
  end
end
