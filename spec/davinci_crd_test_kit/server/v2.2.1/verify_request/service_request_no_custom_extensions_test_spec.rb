RSpec.describe DaVinciCRDTestKit::V221::ServiceRequestNoCustomExtensionsTest do
  let(:suite_id) { 'crd_server' }
  let(:runnable) { described_class }
  let(:result) { repo_create(:result, test_session_id: test_session.id) }
  let(:results_repo) { Inferno::Repositories::Results.new }

  let(:patient_resource) do
    {
      resourceType: 'Patient',
      id: 'example-patient',
      extension: [
        {
          url: 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-sex',
          valueCode: '248152002'
        }
      ]
    }
  end

  let(:patient_resource_with_custom_extension) do
    {
      resourceType: 'Patient',
      id: 'example-patient-2',
      extension: [
        {
          url: 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-sex-custom',
          valueCode: '248152002'
        }
      ]
    }
  end

  let(:service_request_resource) do
    {
      resourceType: 'ServiceRequest',
      id: 'example-service-request'
    }
  end

  def create_hook_request(body:, tags:, status: 200)
    repo_create(
      :request,
      result:,
      tags:,
      status:,
      request_body: body.to_json
    )
  end

  def result_messages
    results_repo.current_results_for_test_session_and_runnables(test_session.id, [runnable])
      .first
      .messages
      .map(&:message)
  end

  it 'skips when no hook requests were received' do
    test_result = run(runnable)

    expect(test_result.result).to eq('skip')
    expect(test_result.result_message).to match(/No requests were made in a previous test as expected/)
  end

  it 'skips when successful hook requests contain no embedded FHIR resources' do
    create_hook_request(
      body: {
        hook: 'order-sign',
        hookInstance: SecureRandom.uuid,
        context: {
          patientId: 'example-patient'
        }
      },
      tags: [DaVinciCRDTestKit::ORDER_SIGN_TAG]
    )

    test_result = run(runnable)

    expect(test_result.result).to eq('skip')
    expect(test_result.result_message).to match(/No embedded FHIR resources were found/)
  end

  it 'skips when all hook requests were unsuccessful' do
    create_hook_request(
      body: {
        hook: 'order-sign',
        hookInstance: SecureRandom.uuid,
        prefetch: {
          patient: patient_resource
        }
      },
      tags: [DaVinciCRDTestKit::ORDER_SIGN_TAG],
      status: 500
    )

    test_result = run(runnable)

    expect(test_result.result).to eq('skip')
    expect(test_result.result_message).to match(/All service requests were unsuccessful/)
  end

  it 'passes when a single hook request contains no custom extensions' do
    create_hook_request(
      body: {
        hook: 'order-sign',
        hookInstance: SecureRandom.uuid,
        context: {
          draftOrders: {
            resourceType: 'Bundle',
            type: 'collection',
            entry: [
              {
                resource: service_request_resource
              }
            ]
          }
        },
        prefetch: {
          patient: patient_resource
        }
      },
      tags: [DaVinciCRDTestKit::ORDER_SIGN_TAG]
    )

    create_hook_request(
      body: {
        hook: 'order-sign',
        hookInstance: SecureRandom.uuid,
        context: {
          draftOrders: {
            resourceType: 'Bundle',
            type: 'collection',
            entry: [
              {
                resource: service_request_resource
              }
            ]
          }
        },
        prefetch: {
          patient: patient_resource_with_custom_extension
        }
      },
      tags: [DaVinciCRDTestKit::ORDER_SIGN_TAG]
    )

    test_result = run(runnable)

    expect(test_result.result).to eq('pass')
  end

  it 'skips if every hook request contains custom extensions' do
    create_hook_request(
      body: {
        hook: 'order-sign',
        hookInstance: SecureRandom.uuid,
        context: {
          draftOrders: {
            resourceType: 'Bundle',
            type: 'collection',
            entry: [
              {
                resource: service_request_resource
              }
            ]
          }
        },
        prefetch: {
          patient: patient_resource_with_custom_extension
        }
      },
      tags: [DaVinciCRDTestKit::ORDER_SIGN_TAG]
    )

    test_result = run(runnable)

    expect(test_result.result).to eq('skip')
    expect(test_result.result_message).to include('http://hl7.org/fhir/us/core/StructureDefinition/us-core-sex-custom')
  end
end
