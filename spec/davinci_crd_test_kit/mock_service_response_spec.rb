require_relative '../../lib/davinci_crd_test_kit/cross_suite/tags'

RSpec.describe DaVinciCRDTestKit::MockServiceResponse do
  describe 'v201' do
    let(:mocked_response_creator_v201) do
      Class.new do
        include DaVinciCRDTestKit::MockServiceResponse

        def ig_version
          'v201'
        end

        def selected_response_types
          @selected_response_types ||= [
            'request_form_completion'
          ]
        end

        def request_body
          @request_body ||=
            JSON.parse(File.read(File.join(__dir__, '..', 'fixtures', 'order_sign_hook_request.json')))
              .merge({
                       'prefetch' => {
                         'coverage' =>
                          JSON.parse(File.read(File.join(__dir__, '..', 'fixtures', 'crd_coverage_example.json')))
                       }
                     })
        end

        def hook_name
          DaVinciCRDTestKit::ORDER_SIGN_TAG
        end
      end.new
    end

    it 'form completion task has two inputs' do
      response = mocked_response_creator_v201.build_mock_hook_response
      expect(response['cards'].size).to eq(1)
      task = response.dig('cards', 0, 'suggestions', 0, 'actions', 1, 'resource')
      expect(task).to be_present
      expect(task['resourceType']).to eq('Task')
      expect(task['input'].size).to eq(2)
    end
  end

  describe 'v220' do
    let(:mocked_response_creator_v220) do
      Class.new do
        include DaVinciCRDTestKit::MockServiceResponse

        def ig_version
          'v220'
        end

        def selected_response_types
          @selected_response_types ||= [
            'request_form_completion'
          ]
        end

        def request_body
          @request_body ||=
            JSON.parse(File.read(File.join(__dir__, '..', 'fixtures', 'order_sign_hook_request.json')))
              .merge({
                       'prefetch' => {
                         'coverage' =>
                          JSON.parse(File.read(File.join(__dir__, '..', 'fixtures', 'crd_coverage_example.json')))
                       }
                     })
        end

        def hook_name
          DaVinciCRDTestKit::ORDER_SIGN_TAG
        end
      end.new
    end

    it 'form completion task has two inputs' do
      response = mocked_response_creator_v220.build_mock_hook_response
      expect(response['cards'].size).to eq(1)
      task = response.dig('cards', 0, 'suggestions', 0, 'actions', 1, 'resource')
      expect(task).to be_present
      expect(task['resourceType']).to eq('Task')
      expect(task['input'].size).to eq(1)
    end
  end
end
