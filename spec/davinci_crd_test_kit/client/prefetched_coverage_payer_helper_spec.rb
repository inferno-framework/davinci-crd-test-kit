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

  describe '#prefetched_coverage_value' do
    it 'uses the complete service key when both keys hold objects' do
      other = { 'resourceType' => 'Bundle', 'entry' => [] }
      expect(helper.prefetched_coverage_value({ 'prefetch' => { 'coverage' => coverage_bundle, 'cov' => other } }))
        .to eq(coverage_bundle)
    end

    it 'uses the subset service key when the complete service key is empty or not an object' do
      [nil, {}, [], '', 'Coverage/1', [coverage]].each do |bad_value|
        body = { 'prefetch' => { 'coverage' => bad_value, 'cov' => coverage_bundle } }
        expect(helper.prefetched_coverage_value(body)).to eq(coverage_bundle), "for #{bad_value.inspect}"
      end
    end

    it 'returns nil when neither key holds an object' do
      expect(helper.prefetched_coverage_value({ 'prefetch' => { 'coverage' => 'Coverage/1', 'cov' => [] } }))
        .to be_nil
    end

    it 'returns nil when the prefetch is missing or not an object' do
      expect(helper.prefetched_coverage_value({})).to be_nil
      expect(helper.prefetched_coverage_value({ 'prefetch' => ['coverage'] })).to be_nil
    end
  end

  describe '#prefetched_coverage' do
    it 'returns a Coverage prefetched on its own' do
      expect(helper.prefetched_coverage({ 'prefetch' => { 'coverage' => coverage } })).to eq(coverage)
    end

    it 'returns the first Coverage in a prefetched Bundle, skipping malformed entries and other types' do
      bundle = {
        'resourceType' => 'Bundle',
        'entry' => ['not an entry', { 'resource' => 'Coverage/1' }, { 'resource' => { 'resourceType' => 'Patient' } },
                    { 'resource' => coverage }]
      }
      expect(helper.prefetched_coverage({ 'prefetch' => { 'coverage' => bundle } })).to eq(coverage)
    end

    it 'returns nil when the Bundle has no Coverage' do
      bundle = { 'resourceType' => 'Bundle', 'entry' => [{ 'resource' => { 'resourceType' => 'Patient' } }] }
      expect(helper.prefetched_coverage({ 'prefetch' => { 'coverage' => bundle } })).to be_nil
    end

    it 'returns nil when no coverage was prefetched' do
      expect(helper.prefetched_coverage({ 'prefetch' => {} })).to be_nil
    end
  end
end
