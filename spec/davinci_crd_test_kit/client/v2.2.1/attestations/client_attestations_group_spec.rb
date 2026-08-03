require_relative '../../../../../lib/davinci_crd_test_kit/client/v2.2.1/client_attestations_group'

RSpec.describe DaVinciCRDTestKit::V221::CRDClientAttestationsGroup do
  let(:suite_id) { 'crd_client_v221' }
  let(:group) { described_class }

  # The following list of requirements is derived from the requirements verified by each test in the group.
  let(:expected_requirements) do
    [
      'hl7.fhir.us.davinci-crd_2.2.1@sec-1',
      'hl7.fhir.us.davinci-crd_2.2.1@impl-1',
      'hl7.fhir.us.davinci-crd_2.2.1@resp-49',
      'hl7.fhir.us.davinci-crd_2.2.1@conf-10',
      'hl7.fhir.us.davinci-crd_2.2.1@conf-12',
      'hl7.fhir.us.davinci-crd_2.2.1@conf-13',
      'hl7.fhir.us.davinci-crd_2.2.1@found-33',
      'hl7.fhir.us.davinci-crd_2.2.1@sec-7',
      'hl7.fhir.us.davinci-crd_2.2.1@conf-3',
      'hl7.fhir.us.davinci-crd_2.2.1@hook-7',
      'hl7.fhir.us.davinci-crd_2.2.1@hook-8',
      'hl7.fhir.us.davinci-crd_2.2.1@resp-48',
      'hl7.fhir.us.davinci-crd_2.2.1@dev-26',
      'hl7.fhir.us.davinci-crd_2.2.1@dev-28',
      'hl7.fhir.us.davinci-crd_2.2.1@dev-30',
      'hl7.fhir.us.davinci-crd_2.2.1@dev-32',
      'cds-hooks_3.0.0-ballot@51',
      'hl7.fhir.us.davinci-crd_2.2.1@found-37',
      'hl7.fhir.us.davinci-crd_2.2.1@hook-3',
      'cds-hooks_3.0.0-ballot@42',
      'cds-hooks_3.0.0-ballot@63',
      'cds-hooks_3.0.0-ballot@64',
      'cds-hooks_3.0.0-ballot@173',
      'hl7.fhir.us.davinci-crd_2.2.1@conf-6'
    ]
  end

  def attestation_input(test)
    test.available_inputs.values.find { |input| input.type == 'radio' }
  end

  def note_input(test)
    test.available_inputs.values.find { |input| input.type == 'textarea' }
  end

  it 'has one test per unique attestation title' do
    expect(group.tests.length).to eq(12)
    expect(group.tests.map(&:title).uniq.length).to eq(12)
  end

  it 'covers each attestation requirement exactly once' do
    covered = group.tests.flat_map(&:verifies_requirements).map(&:to_s)

    expect(covered).to match_array(expected_requirements)
  end

  describe 'each attestation test' do
    it 'is marked as an attestation' do
      expect(group.tests.reject(&:attestation?)).to be_empty
    end

    it 'collects a yes/no answer defaulting to no' do
      group.tests.each do |test|
        input = attestation_input(test)

        expect(input).to_not be_nil, "#{test.title} has no radio input"
        expect(input.default).to eq('false'), "#{test.title} does not default to No"
        expect(input.options[:list_options]).to eq(
          [{ label: 'Yes', value: 'true' }, { label: 'No', value: 'false' }]
        )
      end
    end

    it 'collects an optional note' do
      group.tests.each do |test|
        input = note_input(test)

        expect(input).to_not be_nil, "#{test.title} has no notes input"
        expect(input.optional).to be(true), "#{test.title} notes input is not optional"
      end
    end

    it 'points testers at the specification requirements rather than restating them' do
      group.tests.each do |test|
        description = test.description.strip
        input_description = attestation_input(test).description.strip

        expect(description).to start_with('During this test, the tester will confirm that'),
                               "#{test.title} description does not open with the standard prefix"
        expect(description).to include('View Specification Requirements'),
                               "#{test.title} description does not point at the requirements"
        expect(input_description).to start_with('I attest that'),
                                     "#{test.title} input description does not open with 'I attest that'"
        expect(input_description).to_not match(%r{https://}),
                                         "#{test.title} input description should not contain links"
      end
    end

    it 'carries the shared input instructions' do
      group.tests.each do |test|
        expect(test.input_instructions).to eq(group.input_instructions),
                                           "#{test.title} does not use the shared attestation input instructions"
      end
    end
  end

  describe 'attestation results' do
    let(:test) { group.tests.first }
    let(:attestation_name) { attestation_input(test).name.to_sym }
    let(:note_name) { note_input(test).name.to_sym }

    it 'passes when the tester answers Yes' do
      result = run(test, attestation_name => 'true')

      expect(result.result).to eq('pass')
    end

    it 'passes when the tester answers Yes and provides a note' do
      result = run(test, attestation_name => 'true', note_name => 'Verified during on-site review.')

      expect(result.result).to eq('pass')
    end

    it 'fails when the tester answers No' do
      result = run(test, attestation_name => 'false')

      expect(result.result).to eq('fail')
    end
  end
end
