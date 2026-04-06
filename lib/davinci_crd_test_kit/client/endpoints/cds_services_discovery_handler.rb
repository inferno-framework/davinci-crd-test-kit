module DaVinciCRDTestKit
  class CDSServicesDiscoveryHandler
    def self.call(...)
      new.call(...)
    end

    def self.cds_services(version = 'v2.0.1')
      cds_services_array[version] ||=
        File.read(File.join(__dir__, '..', version, "cds-services-#{version.gsub('.', '')}.json"))
    end

    def self.cds_services_array
      @cds_services_array ||= {}
    end

    def call(env)
      # Check authorization header
      suite = env['PATH_INFO'].split('/')[-2] # /custom/<suite>/cds-services
      version_no_dots = suite.split('_')[2] # crd_client_<version>
      version_no_dots = 'v201' if version_no_dots.blank?
      version = "#{version_no_dots[0..1]}.#{version_no_dots[2]}.#{version_no_dots[3]}" # v###
      [200, { 'Content-Type' => 'application/json' }, [self.class.cds_services(version)]]
    end
  end
end
