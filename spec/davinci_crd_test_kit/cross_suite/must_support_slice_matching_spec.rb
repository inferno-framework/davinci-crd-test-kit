require_relative '../../../lib/davinci_crd_test_kit/cross_suite/must_support_slice_matching'

RSpec.describe DaVinciCRDTestKit::MustSupportSliceMatching do
  let(:core_logic) { Inferno::DSL::MustSupportAssessment::InternalMustSupportLogic }
  let(:crd_logic) { DaVinciCRDTestKit::MustSupportLogic }
  let(:metadata_class) { Struct.new(:must_supports) }

  let(:participant_type_system) { 'http://terminology.hl7.org/CodeSystem/v3-ParticipationType' }
  let(:patient_slice) do
    {
      slice_id: 'Appointment.participant:Patient',
      slice_name: 'Patient',
      path: 'participant',
      discriminator: { type: 'referenceTarget', path: 'type', resource_type: 'Patient' }
    }
  end
  let(:performer_slice) do
    {
      slice_id: 'Appointment.participant:PrimaryPerformer',
      slice_name: 'PrimaryPerformer',
      path: 'participant',
      discriminator: { type: 'patternCodeableConcept', path: 'type', code: 'PPRF', system: participant_type_system }
    }
  end

  def metadata_with(slices: [], elements: [])
    metadata_class.new({ elements:, slices:, extensions: [], recursive_elements: [] })
  end

  def missing(logic_class, resources, metadata)
    logic_class.new.perform_must_support_test_with_metadata(Array.wrap(resources), metadata)
  end

  def appointment(*participants)
    FHIR::Appointment.new(status: 'booked', participant: participants)
  end

  def participant(reference:, type_code: nil)
    type = type_code && [FHIR::CodeableConcept.new(coding: [{ system: participant_type_system, code: type_code }])]
    FHIR::Appointment::Participant.new(actor: { reference: }, type:, status: 'accepted')
  end

  it 'leaves the inferno_core assessment class unchanged for other test kits' do
    expect(core_logic.ancestors).to_not include(described_class)
    expect(crd_logic.ancestors).to include(described_class)
  end

  describe 'requiredBinding values covering a whole code system' do
    let(:x12_system) { 'https://codesystem.x12.org/005010/1365' }
    let(:category_slice) do
      {
        slice_id: 'Appointment.serviceCategory:x12',
        slice_name: 'x12',
        path: 'serviceCategory',
        discriminator: { type: 'requiredBinding', path: '', values: [{ system: x12_system }] }
      }
    end
    let(:metadata) { metadata_with(slices: [category_slice]) }

    def with_category(system, code)
      appointment.tap do |resource|
        resource.serviceCategory = [FHIR::CodeableConcept.new(coding: [{ system:, code: }])]
      end
    end

    it 'matches any code from the bound system' do
      expect(missing(crd_logic, with_category(x12_system, '3'), metadata)).to be_empty
    end

    it 'does not match a code from another system' do
      expect(missing(crd_logic, with_category('http://example.org/other', '3'), metadata))
        .to eq(['Appointment.serviceCategory:x12'])
    end

    it 'is not matched by inferno_core, which needs a code on every value' do
      expect(missing(core_logic, with_category(x12_system, '3'), metadata))
        .to eq(['Appointment.serviceCategory:x12'])
    end

    it 'still matches enumerated system and code pairs alongside whole systems' do
      enumerated = { system: 'http://terminology.hl7.org/CodeSystem/v3-ActCode', code: 'AMB' }
      category_slice[:discriminator][:values] << enumerated

      expect(missing(crd_logic, with_category(enumerated[:system], 'AMB'), metadata)).to be_empty
      expect(missing(crd_logic, with_category(enumerated[:system], 'EMER'), metadata))
        .to eq(['Appointment.serviceCategory:x12'])
    end
  end

  describe 'referenceTarget slices' do
    let(:metadata) { metadata_with(slices: [patient_slice]) }

    it 'matches a participant whose actor references the target resource type' do
      expect(missing(crd_logic, appointment(participant(reference: 'Patient/123')), metadata)).to be_empty
    end

    it 'matches an absolute reference to the target resource type' do
      resource = appointment(participant(reference: 'http://example.org/fhir/Patient/123'))

      expect(missing(crd_logic, resource, metadata)).to be_empty
    end

    it 'does not match a participant whose actor references another resource type' do
      expect(missing(crd_logic, appointment(participant(reference: 'Practitioner/123')), metadata))
        .to eq(['Appointment.participant:Patient'])
    end

    it 'does not match a participant with no actor' do
      resource = appointment(FHIR::Appointment::Participant.new(status: 'accepted'))

      expect(missing(crd_logic, resource, metadata)).to eq(['Appointment.participant:Patient'])
    end

    it 'is not matched by inferno_core, which has no referenceTarget discriminator' do
      expect(missing(core_logic, appointment(participant(reference: 'Patient/123')), metadata))
        .to eq(['Appointment.participant:Patient'])
    end

    it 'finds the slice when a must support element path names it' do
      element = { path: 'participant:Patient.actor' }
      metadata = metadata_with(slices: [patient_slice], elements: [element])
      resource = appointment(participant(reference: 'Practitioner/1'), participant(reference: 'Patient/1'))

      expect(missing(crd_logic, resource, metadata)).to be_empty
      expect(missing(crd_logic, appointment(participant(reference: 'Practitioner/1')), metadata))
        .to contain_exactly('participant:Patient.actor', 'Appointment.participant:Patient')
    end
  end

  describe 'patternCodeableConcept slices whose discriminator path repeats' do
    let(:element) { { path: 'participant:PrimaryPerformer.actor' } }
    let(:metadata) { metadata_with(slices: [performer_slice], elements: [element]) }

    it 'finds the slice by any coding across the repeating CodeableConcepts' do
      resource = appointment(participant(reference: 'Patient/1', type_code: 'SBJ'),
                             participant(reference: 'Practitioner/1', type_code: 'PPRF'))

      expect(missing(crd_logic, resource, metadata)).to be_empty
    end

    it 'reports the element when no participant carries the pattern' do
      resource = appointment(participant(reference: 'Practitioner/1', type_code: 'ATND'))

      expect(missing(crd_logic, resource, metadata))
        .to contain_exactly('participant:PrimaryPerformer.actor', 'Appointment.participant:PrimaryPerformer')
    end

    it 'is not matched by inferno_core, which expects a single CodeableConcept at the path' do
      resource = appointment(participant(reference: 'Practitioner/1', type_code: 'PPRF'))

      expect(missing(core_logic, resource, metadata)).to eq(['participant:PrimaryPerformer.actor'])
    end
  end
end
