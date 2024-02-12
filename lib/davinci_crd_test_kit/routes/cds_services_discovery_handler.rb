module DaVinciCRDTestKit
  module Routes
    class CDSServicesDiscoveryHandler
      def self.call(...)
        new.call(...)
      end

      def self.cds_services
        @cds_services ||= File.read(File.join(__dir__, 'cds-services.json'))
      end

      def call(_env)
        # Check authorization header
        [200, { 'Content-Type' => 'application/json' }, [self.class.cds_services]]
      end
    end
  end
end
