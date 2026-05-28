require_relative '../../../lib/davinci_crd_test_kit/cross_suite/prefetch_profile_validation'

RSpec.describe DaVinciCRDTestKit::PrefetchProfileValidation do
  let(:module_instance) do
    Class.new do
      include DaVinciCRDTestKit::PrefetchProfileValidation

      attr_reader :messages, :resource_is_valid_calls
      attr_writer :issues_to_return

      def initialize
        @messages = []
        @resource_is_valid_calls = []
      end

      def add_message(type, message)
        @messages << { type:, message: }
      end

      def resource_is_valid?(resource:, profile_url:, validator_response_details: [], add_messages_to_runnable: true) # rubocop:disable Lint/UnusedMethodArgument
        @resource_is_valid_calls << { resource:, profile_url: }
        @issues_to_return&.each { |issue| validator_response_details << issue }
      end
    end.new
  end

  let(:patient_resource) do
    JSON.parse(File.read(File.join(__dir__, '..', '..', 'fixtures', 'crd_patient_example.json')))
  end

  let(:practitioner_resource) do
    JSON.parse(File.read(File.join(__dir__, '..', '..', 'fixtures', 'crd_practitioner_example.json')))
  end

  let(:issue_struct) { Struct.new(:severity, :message) }
  let(:error_issue) { issue_struct.new('error', 'something went wrong') }
  let(:warning_issue) { issue_struct.new('warning', 'heads up') }

  let(:patient_bundle) do
    { 'resourceType' => 'Bundle',
      'entry' => [{ 'resource' => patient_resource }, { 'resource' => practitioner_resource }] }
  end

  describe '#check_prefetch_profiles' do
    it 'skips nil prefetch values' do
      module_instance.check_prefetch_profiles({ 'patient' => nil }, 0)

      expect(module_instance.resource_is_valid_calls).to be_empty
      expect(module_instance.messages).to be_empty
    end

    it 'validates each non-nil prefetch value' do
      module_instance.check_prefetch_profiles({ 'patient' => patient_resource,
                                                'practitioner' => practitioner_resource }, 0)

      expect(module_instance.resource_is_valid_calls.size).to eq(2)
    end

    it 'skips prefetch values without a resourceType (not FHIR resources)' do
      module_instance.check_prefetch_profiles({ 'patient' => { 'not' => 'FHIR' } }, 0)

      expect(module_instance.resource_is_valid_calls).to be_empty
    end

    it 'skips resources with no associated CRD profile' do
      module_instance.check_prefetch_profiles({ 'sd' => { 'resourceType' => 'StructureDefinition' } }, 0)

      expect(module_instance.resource_is_valid_calls).to be_empty
    end
  end

  describe 'Bundle handling' do
    it 'validates each entry in the bundle individually' do
      module_instance.check_prefetch_profiles({ 'patient' => patient_bundle }, 0)

      expect(module_instance.resource_is_valid_calls.size).to eq(2)
    end

    it 'skips bundle entries without a resource' do
      bundle = { 'resourceType' => 'Bundle', 'entry' => [{ 'resource' => nil }, { 'resource' => patient_resource }] }
      module_instance.check_prefetch_profiles({ 'patient' => bundle }, 0)

      expect(module_instance.resource_is_valid_calls.size).to eq(1)
    end
  end

  describe 'error message format' do
    it 'includes the request number and prefetch template key for single resource issues' do
      module_instance.issues_to_return = [error_issue]
      module_instance.check_prefetch_profiles({ 'patient' => patient_resource }, 0)

      expect(module_instance.messages.first[:message])
        .to eq("(Request 1) Prefetch Template 'patient' validation issue - something went wrong")
    end

    it 'includes the bundle entry number for issues within a bundle' do
      module_instance.issues_to_return = [error_issue]
      module_instance.check_prefetch_profiles({ 'patient' => patient_bundle }, 0)

      messages = module_instance.messages.map { |m| m[:message] }
      expect(messages.first).to include('Bundle entry 1')
      expect(messages.last).to include('Bundle entry 2')
    end

    it 'passes the issue severity through to add_message' do
      module_instance.issues_to_return = [warning_issue]
      module_instance.check_prefetch_profiles({ 'patient' => patient_resource }, 0)

      expect(module_instance.messages.first[:type]).to eq('warning')
    end
  end

  describe 'resource_is_valid? call' do
    it 'passes the correct CRD profile URL for the resource type' do
      module_instance.check_prefetch_profiles({ 'patient' => patient_resource }, 0)

      call = module_instance.resource_is_valid_calls.first
      expect(call[:profile_url])
        .to eq('http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-patient|2.2.1')
    end
  end
end
