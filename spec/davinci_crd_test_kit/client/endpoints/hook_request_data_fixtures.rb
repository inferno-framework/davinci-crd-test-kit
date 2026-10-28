require_relative '../../../../lib/davinci_crd_test_kit/cross_suite/tags'

# Fixtures for specs of the modules that read data while a hook request is processed. The module
# under test is mixed into a bare object whose request body each example stubs.
RSpec.shared_context 'with hook request data fixtures' do
  let(:module_instance) do
    data_module = described_class
    Class.new do
      include data_module

      def request_body
        nil
      end

      def include_in_cross_hook_analysis?
        false
      end
    end.new
  end

  let(:fhir_server) { 'https://example/r4' }
  let(:patient_example_reference_relative) { 'Patient/example' }
  let(:patient_example_reference_absolute) { "#{fhir_server}/#{patient_example_reference_relative}" }
  let(:patient_example) do
    JSON.parse(File.read(File.join(__dir__, '..', '..', '..', 'fixtures', 'crd_patient_example.json')))
  end
  let(:organization_example_reference_relative) { 'Organization/example' }
  let(:organization_example_reference_absolute) { "#{fhir_server}/#{organization_example_reference_relative}" }
  let(:organization_example) do
    JSON.parse(File.read(File.join(__dir__, '..', '..', '..', 'fixtures', 'crd_organization_example.json')))
  end
  let(:practitioner_example_reference_relative) { 'Practitioner/example' }
  let(:practitioner_example_reference_absolute) { "#{fhir_server}/#{practitioner_example_reference_relative}" }
  let(:practitioner_example) do
    JSON.parse(File.read(File.join(__dir__, '..', '..', '..', 'fixtures', 'crd_practitioner_example.json')))
  end
  let(:practitioner_role_example_reference_relative) { 'PractitionerRole/example' }
  let(:practitioner_role_example_reference_absolute) do
    "#{fhir_server}/#{practitioner_role_example_reference_relative}"
  end
  let(:practitioner_role_example) do
    JSON.parse(File.read(File.join(__dir__, '..', '..', '..', 'fixtures', 'crd_practitioner_role_example.json')))
  end
  let(:location_example_reference_relative) { 'Location/example' }
  let(:location_example_reference_absolute) do
    "#{fhir_server}/#{location_example_reference_relative}"
  end
  let(:location_example) do
    JSON.parse(File.read(File.join(__dir__, '..', '..', '..', 'fixtures', 'crd_location_example.json')))
  end
  let(:location2_example_reference_relative) { 'Location/example2' }
  let(:location2_example_reference_absolute) do
    "#{fhir_server}/#{location2_example_reference_relative}"
  end
  let(:location2_example) do
    loc = JSON.parse(File.read(File.join(__dir__, '..', '..', '..', 'fixtures', 'crd_location_example.json')))
    loc['id'] = 'example2'
    loc
  end
  let(:encounter_example_reference_relative) { 'Encounter/example' }
  let(:encounter_example_reference_absolute) do
    "#{fhir_server}/#{encounter_example_reference_relative}"
  end
  let(:encounter_example) do
    JSON.parse(File.read(File.join(__dir__, '..', '..', '..', 'fixtures', 'crd_encounter_example.json')))
  end
  let(:service_request_example_reference_relative) { 'ServiceRequest/example' }
  let(:service_request_example_reference_absolute) do
    "#{fhir_server}/#{service_request_example_reference_relative}"
  end
  let(:service_request_example) do
    JSON.parse(File.read(File.join(__dir__, '..', '..', '..', 'fixtures', 'crd_service_request_example.json')))
  end
  let(:crd_coverage) do
    JSON.parse(File.read(File.join(
                           __dir__, '..', '..', '..', 'fixtures', 'crd_coverage_example.json'
                         )))
  end
  let(:crd_coverage_bundle) do
    bundle = FHIR::Bundle.new(type: 'searchset')
    bundle.entry.append(FHIR::Bundle::Entry.new(
                          fullUrl: 'https://example.com/base/Coverage/coverage_example',
                          resource: FHIR.from_contents(crd_coverage.to_json)
                        ))
    bundle
  end
  let(:coverage_search_url) { "#{fhir_server}/Coverage?patient=example&status=active" }
  let(:appointment_book_request) do
    JSON.parse(File.read(File.join(__dir__, '..', '..', '..', 'fixtures', 'appointment_book_hook_request.json')))
  end
  let(:encounter_start_request) do
    JSON.parse(File.read(File.join(__dir__, '..', '..', '..', 'fixtures', 'encounter_start_hook_request.json')))
  end
  let(:encounter_discharge_request) do
    JSON.parse(File.read(File.join(__dir__, '..', '..', '..', 'fixtures', 'encounter_discharge_hook_request.json')))
  end
  let(:order_select_request) do
    JSON.parse(File.read(File.join(__dir__, '..', '..', '..', 'fixtures', 'order_select_hook_request.json')))
  end
  let(:order_sign_request) do
    JSON.parse(File.read(File.join(__dir__, '..', '..', '..', 'fixtures', 'order_sign_hook_request.json')))
  end
  let(:order_dispatch_request) do
    JSON.parse(File.read(File.join(__dir__, '..', '..', '..', 'fixtures', 'order_dispatch_hook_request.json')))
  end

  before do
    allow(module_instance).to(receive(:persist_query_request))
  end
end
