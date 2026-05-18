require_relative '../client_base_urls'

module DaVinciCRDTestKit
  module V221
    module ClientURLs
      include ClientBaseURLs

      SUITE_ID = 'crd_client_v221'.freeze

      def self.base_url
        "#{Inferno::Application['base_url']}/custom/#{SUITE_ID}"
      end

      def self.discovery_url
        "#{base_url}#{DaVinciCRDTestKit::DISCOVERY_PATH}"
      end

      def self.prefetch_subset_discovery_url
        "#{base_url}#{DaVinciCRDTestKit::PREFETCH_DISCOVERY_PATH}"
      end

      def suite_id
        SUITE_ID
      end
    end
  end
end
