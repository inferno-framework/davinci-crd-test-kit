RSpec.describe DaVinciCRDTestKit::V221::SupportedUSCoreVersionsTest do
  let(:suite_id) { 'crd_server' }
  let(:runnable) { described_class }
  let(:result) { repo_create(:result, test_session_id: test_session.id) }
  let(:results_repo) { Inferno::Repositories::Results.new }

  let(:patient_resource) do
    {
      resourceType: 'Patient',
      id: 'example-patient'
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

  it 'passes when a single successful hook request demonstrates all required US Core versions' do
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

    allow_any_instance_of(runnable).to receive(:resource_is_valid?) do |_instance, resource:, profile_url:, **_kwargs|
      case resource.resourceType
      when 'Patient'
        profile_url.include?('|3.1.1') || profile_url.include?('|6.1.0')
      when 'ServiceRequest'
        profile_url.include?('|7.0.0')
      else
        false
      end
    end

    test_result = run(runnable)

    expect(test_result.result).to eq('pass')
  end

  it 'ignores unsuccessful hook requests when evaluating US Core version support' do
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
      tags: [DaVinciCRDTestKit::ORDER_SIGN_TAG],
      status: 200
    )

    allow_any_instance_of(runnable).to receive(:resource_is_valid?) do |_instance, resource:, profile_url:, **_kwargs|
      case resource.resourceType
      when 'Patient'
        profile_url.include?('|3.1.1') || profile_url.include?('|6.1.0')
      when 'ServiceRequest'
        profile_url.include?('|7.0.0')
      else
        false
      end
    end

    test_result = run(runnable)

    expect(test_result.result).to eq('pass')
  end

  it 'fails when at least one required US Core version is not demonstrated' do
    create_hook_request(
      body: {
        hook: 'order-sign',
        hookInstance: SecureRandom.uuid,
        prefetch: {
          patient: patient_resource
        }
      },
      tags: [DaVinciCRDTestKit::ORDER_SIGN_TAG]
    )

    allow_any_instance_of(runnable).to receive(:resource_is_valid?) do |_instance, resource:, profile_url:, **_kwargs|
      resource.resourceType == 'Patient' && (
        profile_url.include?('|3.1.1') || profile_url.include?('|6.1.0')
      )
    end

    test_result = run(runnable)

    expect(test_result.result).to eq('fail')
    expect(test_result.result_message).to eq('Support for one or more required US Core versions was not demonstrated.')
    expect(result_messages).to include('Support for US Core 7.0.0 was not demonstrated.')
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
end
