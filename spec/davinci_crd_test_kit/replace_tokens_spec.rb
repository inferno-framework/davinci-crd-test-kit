RSpec.describe DaVinciCRDTestKit::ReplaceTokens do
  let(:module_instance) do
    Class.new do
      include DaVinciCRDTestKit::ReplaceTokens
    end.new
  end
  let(:fhirpath_url) { 'https://example.com/fhirpath/evaluate' }

  let(:order_sign_request) do
    JSON.parse(File.read(File.join(__dir__, '..', 'fixtures', 'order_sign_hook_request.json')))
  end
  let(:fancy_structure_request) do
    JSON.parse(File.read(File.join(__dir__, '..', 'fixtures', 'fancy_structure_hook_request.json')))
  end

  describe 'when replacing in a string' do
    it 'handles no replacements' do
      target = 'Patient/123'
      module_instance.replace_tokens(target, order_sign_request)

      expect(target).to eq('Patient/123')
    end

    it 'replaces single tokens' do
      target = 'Patient/{{context.patientId}}'
      module_instance.replace_tokens(target, order_sign_request)

      expect(target).to eq('Patient/example')
    end

    it 'replaces multiple tokens' do
      target = 'This is a silly example: {{context.patientId}}, {{fhirServer}}, {{fhirAuthorization.access_token}}'
      module_instance.replace_tokens(target, order_sign_request)

      expect(target).to eq('This is a silly example: example, https://example/r4, SAMPLE_TOKEN')
    end

    it 'replaces with the empty string if nothing found' do
      target = 'Patient/{{context.patientxId}}'
      module_instance.replace_tokens(target, order_sign_request)

      expect(target).to eq('Patient/')
    end

    it 'treats an object as if nothing found' do
      target = 'Here is a token replaced with an object: {{context}} (nothing)'
      module_instance.replace_tokens(target, order_sign_request)

      expect(target).to eq('Here is a token replaced with an object:  (nothing)')
    end

    it 'returns a comma-delimited list if multiple things found' do
      target = 'Patient?_id={{context.list.id}}'
      module_instance.replace_tokens(target, fancy_structure_request)

      expect(target).to eq('Patient?_id=123,456')
    end

    it 'handles missing values via compacting' do
      target = 'Patient?_id={{context.non_uniform_list.id}}'
      module_instance.replace_tokens(target, fancy_structure_request)

      expect(target).to eq('Patient?_id=456,')
    end
  end

  describe 'when replacing in a Hash' do
    it 'performs replacements on each value' do
      hash = {
        '{{tricky}}': 'Patient?_id={{context.list.id}}',
        patient: 'Patient/{{context.patientId}}'
      }
      module_instance.replace_tokens(hash, fancy_structure_request)

      expect(hash[:'{{tricky}}']).to eq('Patient?_id=123,456')
      expect(hash[:patient]).to eq('Patient/example')
    end
  end

  describe 'when replacing in an Array' do
    it 'performs replacements on each value' do
      array = [
        'Patient?_id={{context.list.id}}',
        'Patient/{{context.patientId}}'
      ]

      module_instance.replace_tokens(array, fancy_structure_request)

      expect(array.length).to eq(2)
      expect(array[0]).to eq('Patient?_id=123,456')
      expect(array[1]).to eq('Patient/example')
    end
  end
end
