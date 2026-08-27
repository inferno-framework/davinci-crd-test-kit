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

  it 'holds one test per resource type plus the coverage information test' do
    expect(described_class::TEST_DEFINITIONS.length).to eq(14)
    expect(group.tests.length).to eq(15)
  end

  # Each test issues its own attestation, so a tester answers for one resource type at a time
  it 'checks exactly one resource type per test' do
    described_class::TEST_DEFINITIONS.each do |definition|
      expect(definition[:profiles].length).to eq(1), "#{definition[:id]} batches multiple resource types"
    end
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

    it 'gives each supporting profile its own test' do
      supporting_ids = [:crd_v221_coverage_must_support, :crd_v221_location_must_support,
                        :crd_v221_organization_must_support, :crd_v221_patient_must_support,
                        :crd_v221_practitioner_must_support, :crd_v221_practitioner_role_must_support]

      expect(definition_ids).to include(*supporting_ids.map(&:to_s))
    end
  end

  describe 'descriptions' do
    it 'lists must support elements for every profile the test covers' do
      must_support_tests.each do |test|
        expect(test.description).to match(/^- `/), "#{test.title} lists no must support elements"
      end
    end

    it 'names the profile each supporting profile test covers' do
      {
        crd_v221_coverage_must_support: 'CRD Coverage',
        crd_v221_location_must_support: 'CRD Location',
        crd_v221_organization_must_support: 'CRD Organization',
        crd_v221_patient_must_support: 'CRD Patient',
        crd_v221_practitioner_must_support: 'CRD Practitioner',
        crd_v221_practitioner_role_must_support: 'HRex PractitionerRole Profile'
      }.each do |test_id, profile_name|
        test = group.tests.find { |candidate| candidate.id.to_s.end_with?(test_id.to_s) }

        expect(test).to_not be_nil, "#{test_id} not found"
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
