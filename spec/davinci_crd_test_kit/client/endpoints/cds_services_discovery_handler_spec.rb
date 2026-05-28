require 'request_helper'

RSpec.describe DaVinciCRDTestKit::CDSServicesDiscoveryHandler, :request do
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

    it 'returns JSON with required fields for v221' do
      get '/custom/crd_client_v221/cds-services'

      expect(last_response).to be_ok
      expect(last_response.headers['Content-Type']).to eq('application/json')

      response_json = JSON.parse(last_response.body)

      expect(response_json).to include('services')
      expect(response_json['services']).to be_an(Array)

      services = response_json['services']
      expect(services).to be_an(Array)

      services.all? do |service|
        expect(service).to include('hook', 'description', 'id')
        expect(service.dig('extension', 'davinci-crd.configuration-options')).to include(
          a_hash_including(
            'code' => 'coverage-info',
            'type' => 'boolean',
            'name' => 'Coverage Information',
            'default' => true
          )
        )
      end
    end
  end

  describe 'GET /prefetch-subset/cds-services' do
    it 'returns the prefetch-subset services JSON for v221' do
      get '/custom/crd_client_v221/prefetch-subset/cds-services'

      expect(last_response).to be_ok
      expect(last_response.headers['Content-Type']).to eq('application/json')

      response_json = JSON.parse(last_response.body)

      expect(response_json).to include('services')
      services = response_json['services']
      expect(services).to be_an(Array)

      services.all? do |service|
        expect(service).to include('hook', 'description', 'id')
      end
    end

    it 'returns different content than the full cds-services endpoint' do
      get '/custom/crd_client_v221/cds-services'
      full_body = last_response.body

      get '/custom/crd_client_v221/prefetch-subset/cds-services'
      subset_body = last_response.body

      expect(subset_body).to_not eq(full_body)
    end
  end
end
