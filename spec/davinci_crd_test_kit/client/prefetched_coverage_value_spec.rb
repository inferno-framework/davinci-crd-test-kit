require_relative '../../../lib/davinci_crd_test_kit/client/prefetched_coverage_value'

RSpec.describe DaVinciCRDTestKit::PrefetchedCoverageValue do
  let(:coverage) { { 'resourceType' => 'Coverage', 'id' => 'cov-1' } }
  let(:coverage_bundle) { { 'resourceType' => 'Bundle', 'entry' => [{ 'resource' => coverage }] } }

  it 'uses the complete service key when both keys hold objects' do
    other = { 'resourceType' => 'Bundle', 'entry' => [] }
    expect(described_class.find({ 'coverage' => coverage_bundle, 'cov' => other })).to eq(coverage_bundle)
  end

  it 'uses the subset service key when the complete service key is empty or not an object' do
    [nil, {}, [], '', 'Coverage/1', [coverage]].each do |bad_value|
      expect(described_class.find({ 'coverage' => bad_value, 'cov' => coverage_bundle }))
        .to eq(coverage_bundle), "for #{bad_value.inspect}"
    end
  end

  it 'returns nil when neither key holds an object' do
    expect(described_class.find({ 'coverage' => 'Coverage/1', 'cov' => [] })).to be_nil
  end

  it 'returns nil when the prefetch is missing or not an object' do
    expect(described_class.find(nil)).to be_nil
    expect(described_class.find(['coverage'])).to be_nil
  end
end
