RSpec.describe DaVinciCRDTestKit::V221::DiscoveryStandardPrefetchExpressionsTest do
  let(:suite_id) { 'crd_client' }
  let(:runnable) { described_class }
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:standard_encounter_start_service) do
    {
      'hook' => 'encounter-start',
      'title' => 'Encounter Start CDS Service',
      'description' => 'An example of a CDS Service invoked when a user starts an encounter',
      'id' => 'encounter-start-service',
      'prefetch' => {
        'pat' => 'Patient/{{context.patientId}}',
        'enc' => 'Encounter/{{context.encounterId}}',
        'cov' => 'Coverage?patient={{context.patientId}}&status=active',
        'roles' => 'PractitionerRole?_id={{%enc.participant.individual.resolve().ofType(PractitionerRole).id}}',
        'pracs' => 'Practitioner?_id={{%roles.entry.resource.practitioner.resolve().id|' \
                   '%enc.participant.individual.resolve().ofType(Practitioner).id}}',
        'orgs' => 'Organization?_id={{%roles.entry.resource.organization.resolve().id|' \
                  '%enc.serviceProvider.resolve().ofType(Organization).id}}',
        'locs' => 'Location?_id={{%roles.entry.resource.location.resolve().id|%enc.location.location.resolve().id}}'
      }
    }
  end
  let(:standard_order_sign_service) do
    {
      'hook' => 'order-sign',
      'title' => 'Order Sign CDS Service',
      'description' => 'An example of a CDS Service invoked when a user signs an order',
      'id' => 'order-sign-service',
      'prefetch' => {
        'pat' => 'Patient/{{context.patientId}}',
        'enc' => 'Encounter/{{context.encounterId}}',
        'cov' => 'Coverage?patient={{context.patientId}}&status=active',
        'devs' => 'Device?_id={{context.draftOrders.entry.resource.ofType(DeviceRequest).code.resolve().id}}',
        'meds' => 'Medication?_id={{context.draftOrders.entry.resource.ofType(MedicationRequest).' \
                  'medication.resolve().id}}',
        'roles' => 'PractitionerRole?_id={{%enc.participant.individual.resolve().ofType(PractitionerRole).id|' \
                   'context.draftOrders.entry.resource.sender.resolve().ofType(PractitionerRole).id|' \
                   'context.draftOrders.entry.resource.recipient.resolve().ofType(PractitionerRole).id|' \
                   'context.draftOrders.entry.resource.requester.resolve().ofType(PractitionerRole).id|' \
                   'context.draftOrders.entry.resource.performer.resolve().ofType(PractitionerRole).id|' \
                   'context.draftOrders.entry.resource.orderer.resolve().ofType(PractitionerRole).id|' \
                   'context.draftOrders.entry.resource.prescriber.resolve().ofType(PractitionerRole).id}}',
        'pracs' => 'Practitioner?_id={{%roles.entry.resource.practitioner.resolve().id|' \
                   '%enc.participant.individual.resolve().ofType(Practitioner).id|' \
                   'context.draftOrders.entry.resource.sender.resolve().ofType(Practitioner).id|' \
                   'context.draftOrders.entry.resource.recipient.resolve().ofType(Practitioner).id|' \
                   'context.draftOrders.entry.resource.requester.resolve().ofType(Practitioner).id|' \
                   'context.draftOrders.entry.resource.performer.resolve().ofType(Practitioner).id|' \
                   'context.draftOrders.entry.resource.orderer.resolve().ofType(Practitioner).id|' \
                   'context.draftOrders.entry.resource.prescriber.resolve().ofType(Practitioner).id}}',
        'orgs' => 'Organization?_id={{%roles.entry.resource.organization.resolve().id|' \
                  '%enc.serviceProvider.resolve().ofType(Organization).id|' \
                  'context.draftOrders.entry.resource.dispenseRequest.performer.resolve().id|' \
                  'context.draftOrders.entry.resource.sender.resolve().ofType(Organization).id|' \
                  'context.draftOrders.entry.resource.recipient.resolve().ofType(Organization).id|' \
                  'context.draftOrders.entry.resource.performer.resolve().ofType(Organization).id}}',
        'locs' => 'Location?_id={{%roles.entry.resource.location.resolve().id|%enc.location.location.resolve().id|' \
                  'context.draftOrders.entry.resource.locationReference.resolve().id}}'
      }
    }
  end

  def warning_messages
    results_repo.current_results_for_test_session_and_runnables(test_session.id, [runnable])
      .first
      .messages
      .select { |message| message.type == 'warning' }
  end

  def info_messages
    results_repo.current_results_for_test_session_and_runnables(test_session.id, [runnable])
      .first
      .messages
      .select { |message| message.type == 'info' }
  end

  it 'passes without warnings when advertised prefetch expressions match standard expressions for the hook' do
    cds_services = { 'services' => [standard_encounter_start_service, standard_order_sign_service] }.to_json

    result = run(runnable, cds_services:)

    expect(result.result).to eq('pass'), result.result_message
    expect(warning_messages).to be_empty
  end

  it 'warns when an advertised prefetch expression is not standard for the hook' do
    service = standard_encounter_start_service.merge(
      'prefetch' => standard_encounter_start_service['prefetch'].merge(
        'enc' => 'Encounter/{{context.encounterId}}',
        'roles' => 'PractitionerRole?_id={{%enc.participant.individual.resolve().ofType(PractitionerRole).id}}',
        'locs' => 'Location?_id={{%roles.entry.resource.location.resolve().id}}'
      )
    )

    result = run(runnable, cds_services: { 'services' => [service] }.to_json)

    expect(result.result).to eq('pass'), result.result_message
    expect(warning_messages.length).to eq(1)
    expect(warning_messages.first.message)
      .to include('Service `encounter-start-service` advertises prefetch expression')
    expect(warning_messages.first.message).to include('prefetch field `locs`')
  end

  it 'does not warn about ignored services' do
    ignored_service = standard_encounter_start_service.merge(
      'id' => 'ignored-service',
      'prefetch' => {
        'customCoverage' => 'Coverage?beneficiary={{context.patientId}}&status=active'
      }
    )

    result = run(
      runnable,
      cds_services: { 'services' => [standard_encounter_start_service, ignored_service] }.to_json,
      crd_discovery_service_ignore_list: 'ignored-service'
    )

    expect(result.result).to eq('pass'), result.result_message
    expect(warning_messages).to be_empty
    expect(info_messages.first&.message).to match(/Ignoring service `ignored-service`/)
  end

  it 'skips if no services advertise prefetch support' do
    service = standard_encounter_start_service.dup
    service.delete('prefetch')

    result = run(runnable, cds_services: { 'services' => [service] }.to_json)

    expect(result.result).to eq('skip'), result.result_message
    expect(result.result_message).to match(/No CRD services advertised prefetch support/)
  end
end
