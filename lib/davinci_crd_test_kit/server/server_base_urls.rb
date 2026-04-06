require_relative '../cross_suite/base_urls'

module DaVinciCRDTestKit
  FHIR_ROUTE = '/fhir'.freeze
  FHIR_INSTANCE_ROUTE = "#{FHIR_ROUTE}/:resource_type/:resource_id".freeze
  FHIR_RESOURCE_TYPE_ROUTE = "#{FHIR_ROUTE}/:resource_type".freeze
  FHIR_SEARCH_POST_ROUTE = "#{FHIR_ROUTE}/:resource_type/_search".freeze

  module ServerBaseURLs
    include BaseURLs

    def fhir_url
      base_url + FHIR_ROUTE
    end

    # alias for OIDC from SMART client tests
    def client_fhir_base_url
      fhir_url
    end

    def instance_url
      base_url + INSTANCE_ROUTE
    end

    def search_url
      base_url + RESOURCE_TYPE_ROUTE
    end
  end
end
