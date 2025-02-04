require 'request_helper'

RSpec.describe DaVinciCRDTestKit::Routes::CDSServicesDiscoveryHandler, :request do
  let(:router) { Inferno::Web::Router }

  describe 'GET /cds-services' do
    it 'returns JSON with required fields' do
      get '/custom/crd_client/cds-services'

      expect(last_response).to be_ok
      expect(last_response.headers['Content-Type']).to eq('application/json')

      response_json = JSON.parse(last_response.body)

      expect(response_json).to include('services')
      expect(response_json['services']).to be_an(Array)

      services = response_json['services']
      expect(services).to be_an(Array)

      services.all? do |service|
        expect(service).to include('hook', 'description', 'id')
      end
    end
  end
end
