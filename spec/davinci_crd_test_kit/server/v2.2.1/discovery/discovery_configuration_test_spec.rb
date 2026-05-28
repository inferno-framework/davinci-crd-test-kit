RSpec.describe DaVinciCRDTestKit::V221::DiscoveryConfigurationTest do
  let(:suite_id) { 'crd_client' }
  let(:runnable) { described_class }
  let(:cds_services) do
    {
      'services' => [
        {
          'hook' => 'appointment-book',
          'title' => 'Appointment Booking CDS Service',
          'description' => 'An example of a CDS Service that is invoked when user of a CRD Client books an appointment',
          'id' => 'appointment-book-service',
          'prefetch' => {
            'user' => '{{context.userId}}',
            'patient' => 'Patient/{{context.patientId}}'
          }
        }
      ]
    }
  end
  let(:valid_config_option) do
    {
      'code' => 'coverage-info',
      'type' => 'boolean',
      'name' => 'Coverage Information',
      'description' => 'Placeholder Coverage Info Description',
      'default' => false
    }
  end
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:first_error_message) do
    results_repo.current_results_for_test_session_and_runnables(test_session.id, [runnable])
      .first
      .messages.select { |message| message.type == 'error' }
      .first
  end

  it 'passes if all primary hook services contain configuration options' do
    cds_services['services'].first['extension'] =
      {
        'davinci-crd.configuration-options' => [valid_config_option]
      }

    result = run(runnable, cds_services: cds_services.to_json)

    expect(result.result).to eq('pass'), result.result_message
  end

  it 'passes if secondary hook services do not contain configuration options' do
    cds_services['services'] << cds_services['services'].first.dup
    cds_services['services'].first['extension'] =
      {
        'davinci-crd.configuration-options' => [valid_config_option]
      }
    cds_services['services'].last['hook'] = 'encounter-start'

    result = run(runnable, cds_services: cds_services.to_json)

    expect(result.result).to eq('pass'), result.result_message
  end

  it 'omits if no primary hook services are found' do
    cds_services['services'].first['hook'] = 'encounter-start'

    result = run(runnable, cds_services: cds_services.to_json)

    expect(result.result).to eq('omit'), result.result_message
  end

  it 'fails if a primary hook service does not have a coverage-info option' do
    valid_config_option['code'] = 'claim'
    cds_services['services'].first['extension'] =
      {
        'davinci-crd.configuration-options' => [valid_config_option]
      }

    result = run(runnable, cds_services: cds_services.to_json)

    expect(result.result).to eq('fail'), result.result_message
    expect(first_error_message.message).to match(/does not contain a `coverage-info`/)
  end

  it 'fails if a primary hook service does not have a configuration option' do
    result = run(runnable, cds_services: cds_services.to_json)

    expect(result.result).to eq('fail'), result.result_message
    expect(first_error_message.message).to match(/The following services do not contain any/)
  end

  it 'fails if a configuration option does not contain a required field' do
    config_option = valid_config_option
    config_option.delete 'description'

    cds_services['services'].first['extension'] =
      {
        'davinci-crd.configuration-options' => [config_option]
      }

    result = run(runnable, cds_services: cds_services.to_json)

    expect(result.result).to eq('fail'), result.result_message
    expect(first_error_message.message).to match(/does not contain `description` field/)
  end

  it 'fails if a configuration option field is the incorrect type' do
    config_option = valid_config_option
    config_option['description'] = ['bad description']

    cds_services['services'].first['extension'] =
      {
        'davinci-crd.configuration-options' => [config_option]
      }

    result = run(runnable, cds_services: cds_services.to_json)

    expect(result.result).to eq('fail'), result.result_message
    expect(first_error_message.message).to match(/field `description` to be a String, but found Array/)
  end

  it 'fails if configuration options contain duplicate values' do
    cds_services['services'].first['extension'] =
      {
        'davinci-crd.configuration-options' => [valid_config_option, valid_config_option]
      }

    result = run(runnable, cds_services: cds_services.to_json)

    expect(result.result).to eq('fail'), result.result_message
    expect(result.result_message).to match(/contain invalid configuration options/)
    expect(first_error_message.message).to match(/`appointment-book` contain duplicate values for `code`:/)
  end

  it 'ignores services in the ignore list' do
    cds_services['services'].first['extension'] =
      {
        'davinci-crd.configuration-options' => [valid_config_option]
      }
    bad_config_option = valid_config_option.dup
    bad_config_option.delete 'description'
    cds_services['services'] << cds_services['services'].first.dup
    cds_services['services'].last['id'] = 'id_to_ignore'
    cds_services['services'].last['extension'] =
      {
        'davinci-crd.configuration-options' => [bad_config_option]
      }

    result = run(
      runnable,
      cds_services: cds_services.to_json,
      crd_discovery_service_ignore_list: 'id1, id_to_ignore, id3'
    )

    expect(result.result).to eq('pass'), result.result_message
  end

  it 'fails if the coverage-info configuration option is not type boolean' do
    config_option = valid_config_option
    config_option['type'] = 'integer'

    cds_services['services'].first['extension'] =
      {
        'davinci-crd.configuration-options' => [config_option]
      }

    result = run(runnable, cds_services: cds_services.to_json)

    expect(result.result).to eq('fail'), result.result_message
    expect(first_error_message.message).to match(/is not of type boolean/)
  end
end
