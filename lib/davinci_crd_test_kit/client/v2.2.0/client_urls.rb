require_relative '../client_base_urls'

module DaVinciCRDTestKit
  module V220
    module ClientURLs
      include ClientBaseURLs

      def suite_id
        DaVinciCRDTestKit::V220::CRDClientSuite.id
      end
    end
  end
end
