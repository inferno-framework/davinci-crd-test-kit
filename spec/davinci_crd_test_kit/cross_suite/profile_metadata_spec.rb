require_relative '../../../lib/davinci_crd_test_kit/cross_suite/profile_metadata'

RSpec.describe DaVinciCRDTestKit::ProfileMetadata do
  let(:ig_version) { 'v2.2.1' }

  let(:profile_keys) do
    %w[
      vision_prescription service_request nutrition_order medication_request device_request
      communication_request appointment_with_order appointment_without_order encounter
      coverage location organization patient practitioner practitioner_role
    ]
  end

  describe '.for' do
    it 'loads every generated profile' do
      profile_keys.each do |profile_key|
        metadata = described_class.for(ig_version, profile_key)

        expect(metadata.resource).to be_present, "#{profile_key} has no resource"
        expect(metadata.profile_url).to start_with('http'), "#{profile_key} has no profile url"
        expect(metadata.profile_name).to be_present, "#{profile_key} has no profile name"
      end
    end

    it 'always provides every must support sub-key, since the assessment reads them unconditionally' do
      profile_keys.each do |profile_key|
        must_supports = described_class.for(ig_version, profile_key).must_supports

        expect(must_supports.keys).to include(:elements, :slices, :extensions, :recursive_elements),
                                      "#{profile_key} is missing a must support key"
      end
    end

    it 'finds at least one must support element for every profile' do
      profile_keys.each do |profile_key|
        expect(described_class.for(ig_version, profile_key).must_support_strings).to_not be_empty,
                                                                                         "#{profile_key} has none"
      end
    end

    it 'preserves extensions and elements through differential extraction' do
      metadata = described_class.for(ig_version, 'service_request')

      expect(metadata.must_supports[:extensions].map { |extension| extension[:id] })
        .to include('ServiceRequest.extension:Coverage-Information',
                    'ServiceRequest.performerType.extension:codeOptions')
      expect(metadata.must_support_strings).to include('locationCode', 'reasonCode')
    end

    it 'preserves slices whose required binding resolves to codes' do
      slices = described_class.for(ig_version, 'appointment_without_order').must_supports[:slices]

      expect(slices.map { |slice| slice[:slice_id] })
        .to include('Appointment.serviceCategory:encounterType', 'Appointment.serviceCategory:serviceType')
    end

    it 'excludes required binding slices that no resource could ever satisfy' do
      profile_keys.each do |profile_key|
        described_class.for(ig_version, profile_key).must_supports[:slices].each do |slice|
          next unless slice.dig(:discriminator, :type) == 'requiredBinding'

          expect(slice.dig(:discriminator, :values)).to_not be_empty,
                                                            "#{profile_key}: #{slice[:slice_id]} can never match"
        end
      end
    end

    it 'keeps the element a dropped slice constrains' do
      metadata = described_class.for(ig_version, 'service_request')

      expect(metadata.must_supports[:slices].map { |slice| slice[:slice_id] })
        .to_not include('ServiceRequest.locationCode.coding:nubc')
      expect(metadata.must_support_strings).to include('locationCode')
    end

    it 'strips stray whitespace from profile titles' do
      name = described_class.for(ig_version, 'practitioner_role').profile_name

      expect(name).to eq(name.strip)
      expect(name).to eq('HRex PractitionerRole Profile')
    end

    it 'caches repeated loads' do
      first_load = described_class.for(ig_version, 'patient')
      second_load = described_class.for(ig_version, 'patient')

      expect(second_load).to be(first_load)
    end
  end

  describe '.merged' do
    it 'returns the single profile untouched when given one key' do
      merged = described_class.merged(ig_version, ['service_request'])

      expect(merged).to be(described_class.for(ig_version, 'service_request'))
    end

    it 'unions the must supports of both Appointment profiles' do
      with_order = described_class.for(ig_version, 'appointment_with_order')
      without_order = described_class.for(ig_version, 'appointment_without_order')
      merged = described_class.merged(ig_version, %w[appointment_with_order appointment_without_order])

      expect(merged.resource).to eq('Appointment')
      expect(merged.must_support_strings)
        .to match_array((with_order.must_support_strings + without_order.must_support_strings).uniq)
    end

    it 'keeps elements that only one of the profiles requires' do
      merged = described_class.merged(ig_version, %w[appointment_with_order appointment_without_order])
      without_order = described_class.for(ig_version, 'appointment_without_order')

      expect(without_order.must_support_strings).to_not include('basedOn')
      expect(merged.must_support_strings).to include('basedOn')
    end

    it 'de-duplicates elements the profiles share' do
      merged = described_class.merged(ig_version, %w[appointment_with_order appointment_without_order])

      expect(merged.must_support_strings).to eq(merged.must_support_strings.uniq)
    end

    it 'refuses to merge profiles constraining different resource types' do
      expect { described_class.merged(ig_version, %w[patient coverage]) }
        .to raise_error(/differing resource types/)
    end
  end
end
