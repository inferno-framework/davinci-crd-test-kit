require_relative '../client_base_urls'

module DaVinciCRDTestKit
  module V221
    module ClientURLs
      include ClientBaseURLs

      def suite_id
        DaVinciCRDTestKit::V221::CRDClientSuite.id
      end
    end
  end
end
