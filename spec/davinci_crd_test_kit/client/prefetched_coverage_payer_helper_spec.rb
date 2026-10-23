require_relative '../../../lib/davinci_crd_test_kit/client/prefetched_coverage_payer_helper'

RSpec.describe DaVinciCRDTestKit::PrefetchedCoveragePayerHelper do
  let(:helper) { Class.new { include DaVinciCRDTestKit::PrefetchedCoveragePayerHelper }.new }
  let(:coverage) { { 'resourceType' => 'Coverage', 'id' => 'cov-1' } }
  let(:coverage_bundle) { { 'resourceType' => 'Bundle', 'entry' => [{ 'resource' => coverage }] } }

  def request_to(url)
    Struct.new(:url).new(url)
  end

  describe '#prefetch_target' do
    it 'identifies a request to the subset prefetch server' do
      request = request_to('https://inferno.example/custom/crd_client_v221/prefetch-subset/cds-services/order-sign-subset')
      expect(helper.prefetch_target(request)).to eq(:subset)
    end

    it 'identifies a request to the complete prefetch server' do
      request = request_to('https://inferno.example/custom/crd_client_v221/cds-services/order-sign-service')
      expect(helper.prefetch_target(request)).to eq(:complete)
    end
  end

  describe '#coverage_payer_reference' do
    it 'returns the reference of the first payer' do
      coverage = { 'payor' => [{ 'reference' => 'Organization/a' }, { 'reference' => 'Organization/b' }] }
      expect(helper.coverage_payer_reference(coverage)).to eq('Organization/a')
    end

    it 'returns nil when the payer is missing or not a reference object holding a string' do
      [nil, [], 'Organization/a', ['Organization/a'], [{}], [{ 'reference' => 7 }]].each do |payor|
        expect(helper.coverage_payer_reference({ 'payor' => payor })).to be_nil, "for #{payor.inspect}"
      end
    end
  end

  describe '#prefetched_coverages' do
    it 'returns a Coverage prefetched on its own' do
      expect(helper.prefetched_coverages({ 'prefetch' => { 'coverage' => coverage } })).to eq([coverage])
    end

    it 'returns every Coverage in a prefetched Bundle, skipping malformed entries and other types' do
      second = { 'resourceType' => 'Coverage', 'id' => 'cov-2' }
      bundle = {
        'resourceType' => 'Bundle',
        'entry' => [{ 'resource' => coverage }, 'not an entry', { 'resource' => 'Coverage/1' },
                    { 'resource' => { 'resourceType' => 'Patient' } }, { 'resource' => second }]
      }
      expect(helper.prefetched_coverages({ 'prefetch' => { 'cov' => bundle } })).to eq([coverage, second])
    end

    it 'returns nothing when no coverage was prefetched' do
      expect(helper.prefetched_coverages({})).to eq([])
    end
  end

  describe '#first_prefetched_coverage' do
    it 'returns a Coverage prefetched on its own' do
      expect(helper.first_prefetched_coverage({ 'prefetch' => { 'coverage' => coverage } })).to eq(coverage)
    end

    it 'returns the first Coverage in a prefetched Bundle, skipping malformed entries and other types' do
      bundle = {
        'resourceType' => 'Bundle',
        'entry' => ['not an entry', { 'resource' => 'Coverage/1' }, { 'resource' => { 'resourceType' => 'Patient' } },
                    { 'resource' => coverage }]
      }
      expect(helper.first_prefetched_coverage({ 'prefetch' => { 'coverage' => bundle } })).to eq(coverage)
    end

    it 'returns nil when the Bundle has no Coverage' do
      bundle = { 'resourceType' => 'Bundle', 'entry' => [{ 'resource' => { 'resourceType' => 'Patient' } }] }
      expect(helper.first_prefetched_coverage({ 'prefetch' => { 'coverage' => bundle } })).to be_nil
    end

    it 'returns nil when no coverage was prefetched' do
      expect(helper.first_prefetched_coverage({ 'prefetch' => {} })).to be_nil
    end
  end
end
