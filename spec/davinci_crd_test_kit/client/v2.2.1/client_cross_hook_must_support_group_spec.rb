require_relative '../../../../lib/davinci_crd_test_kit/client/v2.2.1/client_cross_hook_must_support_group'

RSpec.describe DaVinciCRDTestKit::V221::ClientCrossHookMustSupportGroup do
  let(:suite_id) { 'crd_client_v221' }
  let(:group) { described_class }
  let(:ig_version) { described_class::IG_VERSION }
  let(:conf3) { described_class::CONF_3 }
  let(:hook3) { described_class::HOOK_3 }

  # The must support tests, excluding the pre-existing coverage information card test.
  let(:must_support_tests) do
    group.tests.select { |test| test.id.to_s.end_with?(*definition_ids) }
  end

  let(:definition_ids) { described_class::TEST_DEFINITIONS.map { |definition| definition[:id].to_s } }

  it 'holds one test per request type, the supporting profiles test, and the coverage information test' do
    expect(described_class::TEST_DEFINITIONS.length).to eq(9)
    expect(group.tests.length).to eq(10)
  end

  it 'gives every test a unique id and title' do
    expect(group.tests.map(&:id).uniq.length).to eq(group.tests.length)
    expect(group.tests.map(&:title).uniq.length).to eq(group.tests.length)
  end

  describe 'requirement coverage' do
    it 'verifies conf-3 on every must support test' do
      must_support_tests.each do |test|
        expect(test.verifies_requirements.map(&:to_s)).to include(conf3), "#{test.title} is missing conf-3"
      end
    end

    it 'verifies hook-3 only on the order request types' do
      with_hook3 = must_support_tests.select { |test| test.verifies_requirements.map(&:to_s).include?(hook3) }

      expect(with_hook3.map { |test| test.id.to_s.split('-').last }).to contain_exactly(
        'crd_v221_vision_prescription_must_support',
        'crd_v221_service_request_must_support',
        'crd_v221_nutrition_order_must_support',
        'crd_v221_medication_request_must_support',
        'crd_v221_device_request_must_support',
        'crd_v221_communication_request_must_support'
      )
    end
  end

  describe 'test configuration' do
    it 'points every profile key at generated metadata whose resource type matches' do
      described_class::TEST_DEFINITIONS.each do |definition|
        definition[:profiles].each do |profile|
          profile[:profile_keys].each do |profile_key|
            metadata = DaVinciCRDTestKit::ProfileMetadata.for(ig_version, profile_key)

            expect(metadata.resource).to eq(profile[:resource_type]),
                                         "#{profile_key} constrains #{metadata.resource}, " \
                                         "but is configured under #{profile[:resource_type]}"
          end
        end
      end
    end

    it 'covers each request resource type exactly once across all tests' do
      resource_types = described_class::TEST_DEFINITIONS.flat_map do |definition|
        definition[:profiles].map { |profile| profile[:resource_type] }
      end

      expect(resource_types).to eq(resource_types.uniq)
      expect(resource_types).to include('VisionPrescription', 'ServiceRequest', 'NutritionOrder',
                                        'MedicationRequest', 'DeviceRequest', 'CommunicationRequest',
                                        'Appointment', 'Encounter', 'Coverage', 'Location',
                                        'Organization', 'Patient', 'Practitioner', 'PractitionerRole')
    end

    it 'checks Appointment against both Appointment profiles' do
      appointment = described_class::TEST_DEFINITIONS
        .find { |definition| definition[:id] == :crd_v221_appointment_must_support }

      expect(appointment[:profiles].first[:profile_keys])
        .to contain_exactly('appointment_with_order', 'appointment_without_order')
    end

    it 'groups the supporting profiles into a single test' do
      supporting = described_class::TEST_DEFINITIONS
        .find { |definition| definition[:id] == :crd_v221_supporting_profiles_must_support }

      expect(supporting[:profiles].length).to eq(6)
    end
  end

  describe 'descriptions' do
    it 'lists must support elements for every profile the test covers' do
      must_support_tests.each do |test|
        expect(test.description).to match(/^- `/), "#{test.title} lists no must support elements"
      end
    end

    it 'names each profile the supporting profiles test covers' do
      test = group.tests.find { |candidate| candidate.id.to_s.end_with?('crd_v221_supporting_profiles_must_support') }

      ['CRD Coverage', 'CRD Location', 'CRD Organization', 'CRD Patient', 'CRD Practitioner',
       'HRex PractitionerRole Profile'].each do |profile_name|
        expect(test.description).to include("### #{profile_name}")
      end
    end

    it 'points testers at the group where more requests can be demonstrated' do
      must_support_tests.each do |test|
        expect(test.description).to include('Additional Hook Invocations')
      end
    end
  end
end
