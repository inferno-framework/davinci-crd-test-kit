# Unit tests for the pure logic methods on FHIRSearchEndpoint (no HTTP stack needed).
RSpec.describe DaVinciCRDTestKit::MockEHR::FHIRSearchEndpoint do
  let(:endpoint) { described_class.allocate }

  # Build a simple DateTime range from XML-schema strings (nil values allowed).
  def dt_range(start_str, end_str = nil)
    {
      start: start_str ? DateTime.xmlschema(start_str) : nil,
      end: end_str ? DateTime.xmlschema(end_str) : nil
    }
  end

  context 'when executing search logic' do
    # ---------------------------------------------------------------------------
    # #date?
    # ---------------------------------------------------------------------------
    describe '#date?' do
      it 'matches YYYY' do
        expect(endpoint.date?('2024')).to be true
      end

      it 'matches YYYY-MM' do
        expect(endpoint.date?('2024-01')).to be true
      end

      it 'matches YYYY-MM-DD' do
        expect(endpoint.date?('2024-01-15')).to be true
      end

      it 'does not match a full datetime string' do
        expect(endpoint.date?('2024-01-15T10:00:00+00:00')).to be false
      end

      it 'does not match nil' do
        expect(endpoint.date?(nil)).to be false
      end

      it 'does not match an empty string' do
        expect(endpoint.date?('')).to be false
      end
    end

    # ---------------------------------------------------------------------------
    # #get_fhir_datetime_range
    # ---------------------------------------------------------------------------
    describe '#get_fhir_datetime_range' do
      it 'builds a year-precision range that spans the whole calendar year' do
        range = endpoint.get_fhir_datetime_range('2024')
        expect(range[:start]).to eq(DateTime.xmlschema('2024-01-01'))
        expect(range[:end]).to   eq(DateTime.xmlschema('2025-01-01') - 1.second)
      end

      it 'builds a month-precision range that spans the whole calendar month' do
        range = endpoint.get_fhir_datetime_range('2024-03')
        expect(range[:start]).to eq(DateTime.xmlschema('2024-03-01'))
        expect(range[:end]).to   eq(DateTime.xmlschema('2024-04-01') - 1.second)
      end

      it 'handles February in a leap year correctly' do
        range = endpoint.get_fhir_datetime_range('2024-02')
        expect(range[:start]).to eq(DateTime.xmlschema('2024-02-01'))
        expect(range[:end]).to   eq(DateTime.xmlschema('2024-03-01') - 1.second)
      end

      it 'handles February in a non-leap year correctly' do
        range = endpoint.get_fhir_datetime_range('2023-02')
        expect(range[:start]).to eq(DateTime.xmlschema('2023-02-01'))
        expect(range[:end]).to   eq(DateTime.xmlschema('2023-03-01') - 1.second)
      end

      it 'builds a day-precision range that spans the whole calendar day' do
        range = endpoint.get_fhir_datetime_range('2024-01-15')
        expect(range[:start]).to eq(DateTime.xmlschema('2024-01-15'))
        expect(range[:end]).to   eq(DateTime.xmlschema('2024-01-16') - 1.second)
      end

      it 'handles end-of-month day boundary' do
        range = endpoint.get_fhir_datetime_range('2024-01-31')
        expect(range[:start]).to eq(DateTime.xmlschema('2024-01-31'))
        expect(range[:end]).to   eq(DateTime.xmlschema('2024-02-01') - 1.second)
      end

      it 'builds a point range (start == end) for a full datetime' do
        range = endpoint.get_fhir_datetime_range('2024-01-15T10:30:00+00:00')
        expect(range[:start]).to eq(range[:end])
        expect(range[:start]).to eq(DateTime.xmlschema('2024-01-15T10:30:00+00:00'))
      end

      it 'handles a datetime at midnight (boundary of day)' do
        range = endpoint.get_fhir_datetime_range('2024-01-15T00:00:00+00:00')
        expect(range[:start]).to eq(range[:end])
      end
    end

    # ---------------------------------------------------------------------------
    # #get_fhir_period_range
    # ---------------------------------------------------------------------------
    describe '#get_fhir_period_range' do
      it 'converts a day-precision period with both start and end' do
        period = FHIR::Period.new(start: '2024-01-10', end: '2024-01-20')
        range = endpoint.get_fhir_period_range(period)
        expect(range[:start]).to eq(DateTime.xmlschema('2024-01-10'))
        expect(range[:end]).to   eq(DateTime.xmlschema('2024-01-21') - 1.second)
      end

      it 'returns a nil start when the period has no start value' do
        period = FHIR::Period.new(end: '2024-01-20')
        range = endpoint.get_fhir_period_range(period)
        expect(range[:start]).to be_nil
        expect(range[:end]).to_not be_nil
      end

      it 'returns a nil end when the period has no end value (open-ended)' do
        period = FHIR::Period.new(start: '2024-01-10')
        range = endpoint.get_fhir_period_range(period)
        expect(range[:start]).to_not be_nil
        expect(range[:end]).to be_nil
      end

      it 'returns both nil for an empty period' do
        period = FHIR::Period.new
        range = endpoint.get_fhir_period_range(period)
        expect(range[:start]).to be_nil
        expect(range[:end]).to be_nil
      end

      it 'treats a full-datetime period end as a point (no expansion)' do
        period = FHIR::Period.new(start: '2024-01-10T08:00:00+00:00', end: '2024-01-20T17:00:00+00:00')
        range = endpoint.get_fhir_period_range(period)
        expect(range[:start]).to eq(DateTime.xmlschema('2024-01-10T08:00:00+00:00'))
        expect(range[:end]).to   eq(DateTime.xmlschema('2024-01-20T17:00:00+00:00'))
      end

      it 'expands a month-precision period end to the last instant of that month' do
        period = FHIR::Period.new(start: '2024-01-10', end: '2024-02')
        range = endpoint.get_fhir_period_range(period)
        expect(range[:end]).to eq(DateTime.xmlschema('2024-03-01') - 1.second)
      end

      it 'expands a year-precision period end to the last instant of that year' do
        period = FHIR::Period.new(start: '2024-01-10', end: '2024')
        range = endpoint.get_fhir_period_range(period)
        expect(range[:end]).to eq(DateTime.xmlschema('2025-01-01') - 1.second)
      end
    end

    # ---------------------------------------------------------------------------
    # #fhir_date_comparer
    # ---------------------------------------------------------------------------
    describe '#fhir_date_comparer' do
      # Reusable day-precision ranges expressed as {start, end} hashes
      # rubocop:disable RSpec/IndexedLet,Naming/VariableNumber
      let(:jan_15)          { dt_range('2024-01-15T00:00:00+00:00', '2024-01-15T23:59:59+00:00') }
      let(:jan_16)          { dt_range('2024-01-16T00:00:00+00:00', '2024-01-16T23:59:59+00:00') }
      let(:jan_10_to_20)    { dt_range('2024-01-10T00:00:00+00:00', '2024-01-20T23:59:59+00:00') }
      let(:jan_10_to_15)    { dt_range('2024-01-10T00:00:00+00:00', '2024-01-15T23:59:59+00:00') }
      let(:jan_15_to_20)    { dt_range('2024-01-15T00:00:00+00:00', '2024-01-20T23:59:59+00:00') }
      let(:open_end)        { dt_range('2024-01-15T00:00:00+00:00', nil) }   # no upper bound
      let(:open_start)      { dt_range(nil, '2024-01-15T23:59:59+00:00') }   # no lower bound
      # rubocop:enable RSpec/IndexedLet,Naming/VariableNumber

      # ------------------------------------------------------------------
      describe 'eq — search range fully contains target range' do
        it 'matches when target is the same range as search' do
          expect(endpoint.fhir_date_comparer(jan_15, jan_15, 'eq')).to be true
        end

        it 'matches when target is strictly narrower than search' do
          expect(endpoint.fhir_date_comparer(jan_10_to_20, jan_15, 'eq')).to be true
        end

        it 'does not match when target starts before search' do
          expect(endpoint.fhir_date_comparer(jan_15, jan_10_to_20, 'eq')).to be false
        end

        it 'does not match when target ends after search' do
          expect(endpoint.fhir_date_comparer(jan_15, jan_15_to_20, 'eq')).to be false
        end

        it 'does not match when target has a nil start (open-started)' do
          expect(endpoint.fhir_date_comparer(jan_15, open_start, 'eq')).to be false
        end

        it 'does not match when target has a nil end (open-ended)' do
          expect(endpoint.fhir_date_comparer(jan_15, open_end, 'eq')).to be false
        end
      end

      # ------------------------------------------------------------------
      describe 'ne — search range does NOT fully contain target range' do
        it 'does not match when ranges are equal (eq would hold)' do
          expect(endpoint.fhir_date_comparer(jan_15, jan_15, 'ne')).to be false
        end

        it 'does not match when search fully contains target (eq would hold)' do
          expect(endpoint.fhir_date_comparer(jan_10_to_20, jan_15, 'ne')).to be false
        end

        it 'matches when target has a nil start' do
          expect(endpoint.fhir_date_comparer(jan_15, open_start, 'ne')).to be true
        end

        it 'matches when target has a nil end' do
          expect(endpoint.fhir_date_comparer(jan_15, open_end, 'ne')).to be true
        end

        it 'matches when target starts before search start' do
          expect(endpoint.fhir_date_comparer(jan_15, jan_10_to_20, 'ne')).to be true
        end

        it 'matches when target ends after search end' do
          expect(endpoint.fhir_date_comparer(jan_15, jan_15_to_20, 'ne')).to be true
        end
      end

      # ------------------------------------------------------------------
      describe 'gt — range above search overlaps with target' do
        it 'matches when target end is strictly after search end' do
          expect(endpoint.fhir_date_comparer(jan_15, jan_15_to_20, 'gt')).to be true
        end

        it 'matches when target has no end (open-ended future)' do
          expect(endpoint.fhir_date_comparer(jan_15, open_end, 'gt')).to be true
        end

        it 'does not match when target end equals search end (boundary)' do
          expect(endpoint.fhir_date_comparer(jan_15, jan_10_to_15, 'gt')).to be false
        end

        it 'does not match when target end is before search end' do
          expect(endpoint.fhir_date_comparer(jan_15_to_20, jan_15, 'gt')).to be false
        end

        it 'matches via extend_end when target end exactly equals search end' do
          # With extend_end the boundary is widened by 1 second, enabling equality to count.
          expect(endpoint.fhir_date_comparer(jan_15, jan_10_to_15, 'gt', extend_end: true)).to be true
        end
      end

      # ------------------------------------------------------------------
      describe 'lt — range below search overlaps with target' do
        it 'matches when target start is strictly before search start' do
          expect(endpoint.fhir_date_comparer(jan_15, jan_10_to_15, 'lt')).to be true
        end

        it 'matches when target has no start (open-started past)' do
          expect(endpoint.fhir_date_comparer(jan_15, open_start, 'lt')).to be true
        end

        it 'does not match when target start equals search start (boundary)' do
          expect(endpoint.fhir_date_comparer(jan_15, jan_15, 'lt')).to be false
        end

        it 'does not match when target start is after search start' do
          expect(endpoint.fhir_date_comparer(jan_15, jan_15_to_20, 'lt')).to be false
        end

        it 'matches via extend_start when target start exactly equals search start' do
          expect(endpoint.fhir_date_comparer(jan_15, jan_15_to_20, 'lt', extend_start: true)).to be true
        end

        it 'does not match when target has no upper bound and search start equals target start' do
          # open_end starts at the same instant as jan_15; search_start == target_start → not strictly greater
          expect(endpoint.fhir_date_comparer(jan_15, open_end, 'lt')).to be false
        end
      end

      # ------------------------------------------------------------------
      describe 'ge — target end is at or after search range start' do
        it 'matches when target extends past search' do
          expect(endpoint.fhir_date_comparer(jan_15, jan_15_to_20, 'ge')).to be true
        end

        it 'matches when target is fully contained within search' do
          expect(endpoint.fhir_date_comparer(jan_10_to_20, jan_15, 'ge')).to be true
        end

        it 'does not match when target ends before search starts' do
          # search=jan_16, target=jan_10_to_15 → target ends Jan 15 23:59:59 < search starts Jan 16 00:00
          expect(endpoint.fhir_date_comparer(jan_16, jan_10_to_15, 'ge')).to be false
        end

        it 'matches when target has no lower bound and search end equals target end' do
          # open_start ends at Jan 15 23:59:59 >= search starts Jan 15 00:00 → true
          expect(endpoint.fhir_date_comparer(jan_15, open_start, 'ge')).to be true
        end
      end

      # ------------------------------------------------------------------
      describe 'le — target start is at or before search range end' do
        it 'matches when target starts before search' do
          expect(endpoint.fhir_date_comparer(jan_15, jan_10_to_15, 'le')).to be true
        end

        it 'matches when target is fully contained within search' do
          expect(endpoint.fhir_date_comparer(jan_10_to_20, jan_15, 'le')).to be true
        end

        it 'does not match when target starts after search ends' do
          # search=jan_10_to_15, target=jan_16 → target starts Jan 16 00:00 > search ends Jan 15 23:59:59
          expect(endpoint.fhir_date_comparer(jan_10_to_15, jan_16, 'le')).to be false
        end

        it 'matches when target has no upper bound and search end equals target start' do
          # open_end starts Jan 15 00:00 <= search ends Jan 15 23:59:59 → true
          expect(endpoint.fhir_date_comparer(jan_15, open_end, 'le')).to be true
        end
      end

      # ------------------------------------------------------------------
      describe 'sa — target starts after (range above search contains target)' do
        it 'matches when target start is strictly after search end' do
          # jan_15 ends at 23:59:59; jan_16 starts at 00:00:00 next day
          expect(endpoint.fhir_date_comparer(jan_15, jan_16, 'sa')).to be true
        end

        it 'does not match when target start is within search range' do
          # search ends Jan 15 23:59:59; target starts Jan 15 00:00:00 — not after
          expect(endpoint.fhir_date_comparer(jan_15, jan_15, 'sa')).to be false
        end

        it 'does not match when target has a nil start' do
          expect(endpoint.fhir_date_comparer(jan_15, open_start, 'sa')).to be false
        end

        it 'does not match when target is completely before search' do
          expect(endpoint.fhir_date_comparer(jan_16, jan_15, 'sa')).to be false
        end

        it 'does not match when target has no upper bound and search end equals target start (same day)' do
          # open_end starts at Jan 15 00:00; search ends at Jan 15 23:59:59
          # sa requires search_end STRICTLY LESS THAN target_start — fails when both are on the same day
          expect(endpoint.fhir_date_comparer(jan_15, open_end, 'sa')).to be false
        end
      end

      # ------------------------------------------------------------------
      describe 'eb — target ends before (range below search contains target)' do
        it 'matches when target end is strictly before search start' do
          # jan_16 starts 00:00; jan_15 ends 23:59:59 — target end is before search start
          expect(endpoint.fhir_date_comparer(jan_16, jan_15, 'eb')).to be true
        end

        it 'does not match when target end falls within search range' do
          # search starts Jan 15 00:00; target ends Jan 15 23:59:59 — 00:00 is not > 23:59:59
          expect(endpoint.fhir_date_comparer(jan_15, jan_15, 'eb')).to be false
        end

        it 'does not match when target has a nil end' do
          expect(endpoint.fhir_date_comparer(jan_15, open_end, 'eb')).to be false
        end

        it 'does not match when target is completely after search' do
          expect(endpoint.fhir_date_comparer(jan_15, jan_16, 'eb')).to be false
        end
      end

      # ------------------------------------------------------------------
      describe 'ap — ranges approximately overlap' do
        it 'matches when search start falls within target range' do
          expect(endpoint.fhir_date_comparer(jan_15, jan_10_to_20, 'ap')).to be true
        end

        it 'matches when search end falls within target range' do
          # search=jan_10_to_15, target=jan_15_to_20 — search end (Jan 15) is inside target
          expect(endpoint.fhir_date_comparer(jan_10_to_15, jan_15_to_20, 'ap')).to be true
        end

        it 'does not match when search is entirely before target' do
          expect(endpoint.fhir_date_comparer(jan_15, jan_16, 'ap')).to be false
        end

        it 'does not match when search is entirely after target' do
          expect(endpoint.fhir_date_comparer(jan_16, jan_15, 'ap')).to be false
        end

        it 'matches when target has nil start and search end is before target end' do
          target  = dt_range(nil, '2024-01-20T23:59:59+00:00')
          search  = dt_range('2024-01-10T00:00:00+00:00', '2024-01-10T23:59:59+00:00')
          expect(endpoint.fhir_date_comparer(search, target, 'ap')).to be true
        end

        it 'does not match when target has nil start but search end is past target end' do
          target = dt_range(nil, '2024-01-09T23:59:59+00:00')
          expect(endpoint.fhir_date_comparer(jan_15, target, 'ap')).to be false
        end

        it 'matches when target has nil end and search start is after target start' do
          target = dt_range('2024-01-10T00:00:00+00:00', nil)
          expect(endpoint.fhir_date_comparer(jan_15, target, 'ap')).to be true
        end

        it 'does not match when target has nil end but search end is before target start' do
          target = dt_range('2024-01-20T00:00:00+00:00', nil)
          expect(endpoint.fhir_date_comparer(jan_15, target, 'ap')).to be false
        end

        it 'matches when target has no upper bound and search is a day starting at target start' do
          # ap (nil-end branch): search_end > target_start?
          # jan_15 ends 23:59:59; open_end starts 00:00:00 → 23:59:59 > 00:00:00 → true
          expect(endpoint.fhir_date_comparer(jan_15, open_end, 'ap')).to be true
        end

        it 'does not match when target has no upper bound and search is a point datetime at exactly target start' do
          # ap (nil-end branch): search_end > target_start?
          # A point datetime (start == end == Jan 15 00:00:00) means search_end == target_start → NOT strictly greater
          point_at_start = dt_range('2024-01-15T00:00:00+00:00', '2024-01-15T00:00:00+00:00')
          expect(endpoint.fhir_date_comparer(point_at_start, open_end, 'ap')).to be false
        end
      end
    end

    # ---------------------------------------------------------------------------
    # #validate_datetime_search — searching a date/dateTime/instant field
    # ---------------------------------------------------------------------------
    describe '#validate_datetime_search' do
      # Patient.birthDate = '1987-02-20' serves as the canonical target throughout.
      let(:target_day)      { '1987-02-20' }
      let(:target_datetime) { '1987-02-20T12:00:00+00:00' }

      context 'without a comparator prefix (implicit eq)' do
        it 'matches an exact day' do
          expect(endpoint.validate_datetime_search('1987-02-20', target_day)).to be true
        end

        it 'matches a month that contains the target day' do
          expect(endpoint.validate_datetime_search('1987-02', target_day)).to be true
        end

        it 'matches a year that contains the target day' do
          expect(endpoint.validate_datetime_search('1987', target_day)).to be true
        end

        it 'does not match a different day' do
          expect(endpoint.validate_datetime_search('1987-02-21', target_day)).to be false
        end

        it 'does not match a different month' do
          expect(endpoint.validate_datetime_search('1987-03', target_day)).to be false
        end

        it 'does not match a different year' do
          expect(endpoint.validate_datetime_search('1988', target_day)).to be false
        end

        it 'day search contains a target datetime that falls in that day' do
          expect(endpoint.validate_datetime_search('1987-02-20', target_datetime)).to be true
        end

        it 'day search does not contain a target datetime from another day' do
          expect(endpoint.validate_datetime_search('1987-02-21', target_datetime)).to be false
        end
      end

      context 'with gt (greater than)' do
        it 'matches when target is strictly after the search date' do
          expect(endpoint.validate_datetime_search('gt1987-02-19', target_day)).to be true
        end

        it 'does not match when target equals the search date (eq boundary)' do
          expect(endpoint.validate_datetime_search('gt1987-02-20', target_day)).to be false
        end

        it 'does not match when target is before the search date' do
          expect(endpoint.validate_datetime_search('gt1987-02-21', target_day)).to be false
        end

        it 'matches with month precision when target month is after search month' do
          expect(endpoint.validate_datetime_search('gt1987-01', target_day)).to be true
        end
      end

      context 'with lt (less than)' do
        it 'matches when target is strictly before the search date' do
          expect(endpoint.validate_datetime_search('lt1987-02-21', target_day)).to be true
        end

        it 'does not match when target equals the search date' do
          expect(endpoint.validate_datetime_search('lt1987-02-20', target_day)).to be false
        end

        it 'does not match when target is after the search date' do
          expect(endpoint.validate_datetime_search('lt1987-02-19', target_day)).to be false
        end
      end

      context 'with ge (greater than or equal)' do
        it 'matches when target equals the search date' do
          expect(endpoint.validate_datetime_search('ge1987-02-20', target_day)).to be true
        end

        it 'matches when target is after the search date' do
          expect(endpoint.validate_datetime_search('ge1987-02-19', target_day)).to be true
        end

        it 'does not match when target is before the search date' do
          expect(endpoint.validate_datetime_search('ge1987-02-21', target_day)).to be false
        end
      end

      context 'with le (less than or equal)' do
        it 'matches when target equals the search date' do
          expect(endpoint.validate_datetime_search('le1987-02-20', target_day)).to be true
        end

        it 'matches when target is before the search date' do
          expect(endpoint.validate_datetime_search('le1987-02-21', target_day)).to be true
        end

        it 'does not match when target is after the search date' do
          expect(endpoint.validate_datetime_search('le1987-02-19', target_day)).to be false
        end
      end

      context 'with ne (not equal)' do
        it 'does not match the exact same day' do
          expect(endpoint.validate_datetime_search('ne1987-02-20', target_day)).to be false
        end

        it 'matches a different day' do
          expect(endpoint.validate_datetime_search('ne1987-02-21', target_day)).to be true
        end

        it 'matches a different month' do
          expect(endpoint.validate_datetime_search('ne1987-03', target_day)).to be true
        end

        it 'does not match the containing month (month range contains the target day)' do
          expect(endpoint.validate_datetime_search('ne1987-02', target_day)).to be false
        end
      end

      context 'with sa (starts after)' do
        it 'matches when the whole target day starts after the search range' do
          # sa1987-02-19 → search ends Feb 19 23:59:59; target starts Feb 20 00:00:00
          expect(endpoint.validate_datetime_search('sa1987-02-19', target_day)).to be true
        end

        it 'does not match when target starts within the search day range' do
          expect(endpoint.validate_datetime_search('sa1987-02-20', target_day)).to be false
        end

        it 'does not match when target is before the search date' do
          expect(endpoint.validate_datetime_search('sa1987-02-21', target_day)).to be false
        end
      end

      context 'with eb (ends before)' do
        it 'matches when the whole target day ends before the search range starts' do
          # eb1987-02-21 → search starts Feb 21 00:00:00; target ends Feb 20 23:59:59
          expect(endpoint.validate_datetime_search('eb1987-02-21', target_day)).to be true
        end

        it 'does not match when target ends within the search day range' do
          expect(endpoint.validate_datetime_search('eb1987-02-20', target_day)).to be false
        end

        it 'does not match when target is after the search date' do
          expect(endpoint.validate_datetime_search('eb1987-02-19', target_day)).to be false
        end
      end

      context 'with ap (approximately)' do
        it 'matches when search range and target range are the same day' do
          expect(endpoint.validate_datetime_search('ap1987-02-20', target_day)).to be true
        end

        it 'does not match when search month contains the target day (search endpoints outside target range)' do
          # ap checks whether SEARCH endpoints fall within the target range.
          # A month-wide search (Feb 1–Feb 28) has endpoints outside a single day (Feb 20).
          expect(endpoint.validate_datetime_search('ap1987-02', target_day)).to be false
        end

        it 'does not match when search is a different day' do
          expect(endpoint.validate_datetime_search('ap1987-02-21', target_day)).to be false
        end
      end

      context 'when datetime search value against a date-precision target (extend_start/extend_end)' do
        it 'gt: a datetime at the last instant of a day matches the next day (target)' do
          # search gt1987-02-19T23:59:59+00:00 — search end = Feb 19 23:59:59
          # target Feb 20 — target end = Feb 20 23:59:59; strictly greater → match
          expect(endpoint.validate_datetime_search('gt1987-02-19T23:59:59+00:00', target_day)).to be true
        end

        it 'gt: a datetime exactly at the target date end still matches via extend_end' do
          # search end = 1987-02-20T23:59:59; target end = 1987-02-20T23:59:59
          # Without extend_end: not strictly less; with extend_end (search not a date, target is date): match
          expect(endpoint.validate_datetime_search('gt1987-02-20T23:59:59+00:00', target_day)).to be true
        end

        it 'lt: a datetime at midnight of the next day matches the previous day (target)' do
          # search lt1987-02-21T00:00:00+00:00 — search start = Feb 21 00:00
          # target Feb 20 — target start = Feb 20 00:00; search start > target start → match
          expect(endpoint.validate_datetime_search('lt1987-02-21T00:00:00+00:00', target_day)).to be true
        end

        it 'lt: a datetime exactly at the target date start still matches via extend_start' do
          # search start = 1987-02-20T00:00:00; target start = 1987-02-20T00:00:00
          # Without extend_start: not strictly greater; with extend_start: match
          expect(endpoint.validate_datetime_search('lt1987-02-20T00:00:00+00:00', target_day)).to be true
        end
      end
    end

    # ---------------------------------------------------------------------------
    # #validate_period_search — searching a Period-type field
    # ---------------------------------------------------------------------------
    describe '#validate_period_search' do
      # Encounter.period = '2024-01-10' .. '2024-01-20'
      let(:closed_period)     { FHIR::Period.new(start: '2024-01-10', end: '2024-01-20') }
      let(:open_end_period)   { FHIR::Period.new(start: '2024-01-10') }
      let(:open_start_period) { FHIR::Period.new(end: '2024-01-20') }
      let(:empty_period)      { FHIR::Period.new }

      context 'without a comparator prefix (implicit eq)' do
        # eq semantics: the SEARCH range must fully contain the TARGET range.
        # A single day cannot contain a multi-day period, so these return false.
        it 'does not match a day that falls inside but does not contain the period' do
          expect(endpoint.validate_period_search('2024-01-15', closed_period)).to be false
        end

        it 'does not match the day that equals the period start (period wider than search)' do
          expect(endpoint.validate_period_search('2024-01-10', closed_period)).to be false
        end

        it 'does not match the day that equals the period end (period wider than search)' do
          expect(endpoint.validate_period_search('2024-01-20', closed_period)).to be false
        end

        it 'does not match a day outside the period' do
          expect(endpoint.validate_period_search('2024-01-21', closed_period)).to be false
        end

        it 'matches a month that fully contains the period' do
          # search=2024-01 → range Jan 1 – Jan 31; period Jan 10 – Jan 20 is contained
          expect(endpoint.validate_period_search('2024-01', closed_period)).to be true
        end

        it 'does not match a month that only partially contains the period' do
          # search=2024-01 but period is Jan 1 – Feb 5 → period extends past January
          partial_period = FHIR::Period.new(start: '2024-01-01', end: '2024-02-05')
          expect(endpoint.validate_period_search('2024-01', partial_period)).to be false
        end

        it 'does not match an open-start period (eq requires non-nil boundaries)' do
          expect(endpoint.validate_period_search('2024-01-15', open_start_period)).to be false
        end

        it 'does not match an open-end period (eq requires non-nil boundaries)' do
          expect(endpoint.validate_period_search('2024-01-15', open_end_period)).to be false
        end
      end

      context 'with gt (range above search overlaps target)' do
        it 'matches when the period extends past the search date' do
          expect(endpoint.validate_period_search('gt2024-01-15', closed_period)).to be true
        end

        it 'does not match when the period ends exactly on the search date' do
          # search end = Jan 20 23:59:59; period end = Jan 20 23:59:59 — not strictly less
          expect(endpoint.validate_period_search('gt2024-01-20', closed_period)).to be false
        end

        it 'does not match when the period ends before the search date' do
          expect(endpoint.validate_period_search('gt2024-01-21', closed_period)).to be false
        end

        it 'matches an open-end period (period end is nil ⇒ extends forever)' do
          expect(endpoint.validate_period_search('gt2024-01-15', open_end_period)).to be true
        end

        it 'matches an open-end period even when search date equals period start' do
          # gt: target_end.nil? → true regardless of where the search falls
          expect(endpoint.validate_period_search('gt2024-01-10', open_end_period)).to be true
        end

        it 'does not match an open-start period when it ends before the search date' do
          past_end_open_start = FHIR::Period.new(end: '2024-01-05')
          expect(endpoint.validate_period_search('gt2024-01-10', past_end_open_start)).to be false
        end
      end

      context 'with lt (range below search overlaps target)' do
        it 'matches when the period starts before the search date' do
          expect(endpoint.validate_period_search('lt2024-01-15', closed_period)).to be true
        end

        it 'does not match when the period starts exactly on the search date' do
          # search start = Jan 10 00:00; period start = Jan 10 00:00 — not strictly greater
          expect(endpoint.validate_period_search('lt2024-01-10', closed_period)).to be false
        end

        it 'does not match when the period starts after the search date' do
          expect(endpoint.validate_period_search('lt2024-01-09', closed_period)).to be false
        end

        it 'matches an open-start period (period start is nil ⇒ extends to the past)' do
          expect(endpoint.validate_period_search('lt2024-01-15', open_start_period)).to be true
        end

        it 'does not match an open-end period when search date equals period start' do
          # search_start(Jan 10 00:00) == target_start(Jan 10 00:00) → not strictly greater → false
          expect(endpoint.validate_period_search('lt2024-01-10', open_end_period)).to be false
        end
      end

      context 'with ge (greater than or equal)' do
        it 'matches when the period extends past the search date' do
          expect(endpoint.validate_period_search('ge2024-01-15', closed_period)).to be true
        end

        it 'matches when search date equals the period start (period end >= search start)' do
          expect(endpoint.validate_period_search('ge2024-01-10', closed_period)).to be true
        end

        it 'does not match when period ends before search date' do
          expect(endpoint.validate_period_search('ge2024-01-21', closed_period)).to be false
        end

        it 'matches an open-start period when search date equals period end' do
          # open_start_period ends Jan 20; 'ge2024-01-20' starts Jan 20 00:00
          # Jan 20 23:59:59 >= Jan 20 00:00 → true
          expect(endpoint.validate_period_search('ge2024-01-20', open_start_period)).to be true
        end
      end

      context 'with le (less than or equal)' do
        it 'matches when the period starts before the search date' do
          expect(endpoint.validate_period_search('le2024-01-15', closed_period)).to be true
        end

        it 'matches when search date equals the period end (period start <= search end)' do
          expect(endpoint.validate_period_search('le2024-01-20', closed_period)).to be true
        end

        it 'does not match when period starts after search date' do
          expect(endpoint.validate_period_search('le2024-01-09', closed_period)).to be false
        end

        it 'matches an open-end period when search date equals period start' do
          # open_end_period starts Jan 10; 'le2024-01-10' ends Jan 10 23:59:59
          # Jan 10 00:00 <= Jan 10 23:59:59 → true
          expect(endpoint.validate_period_search('le2024-01-10', open_end_period)).to be true
        end
      end

      context 'with ne (not equal)' do
        it 'matches when the search day is outside the period (not contained)' do
          expect(endpoint.validate_period_search('ne2024-01-25', closed_period)).to be true
        end

        it 'does not match when search month fully contains the period' do
          # 2024-01 (Jan 1 – Jan 31) contains Jan 10 – Jan 20 → eq holds → ne is false
          expect(endpoint.validate_period_search('ne2024-01', closed_period)).to be false
        end

        it 'matches an open-start period (nil start prevents eq)' do
          expect(endpoint.validate_period_search('ne2024-01-15', open_start_period)).to be true
        end

        it 'matches an open-end period (nil end prevents eq)' do
          expect(endpoint.validate_period_search('ne2024-01-15', open_end_period)).to be true
        end
      end

      context 'with sa (target starts after search range)' do
        it 'matches when period starts the day after the search date' do
          # search=2024-01-09 → search end = Jan 9 23:59:59; period starts Jan 10 00:00
          expect(endpoint.validate_period_search('sa2024-01-09', closed_period)).to be true
        end

        it 'does not match when period starts on the same day as the search date' do
          # search=2024-01-10 → search end = Jan 10 23:59:59; period start = Jan 10 00:00 → not after
          expect(endpoint.validate_period_search('sa2024-01-10', closed_period)).to be false
        end

        it 'does not match when period starts before the search date' do
          expect(endpoint.validate_period_search('sa2024-01-15', closed_period)).to be false
        end

        it 'does not match an open-start period (nil start has no defined beginning)' do
          expect(endpoint.validate_period_search('sa2024-01-09', open_start_period)).to be false
        end
      end

      context 'with eb (target ends before search range)' do
        it 'matches when period ends the day before the search date' do
          # search=2024-01-21 → search start = Jan 21 00:00; period ends Jan 20 23:59:59
          expect(endpoint.validate_period_search('eb2024-01-21', closed_period)).to be true
        end

        it 'does not match when period ends on the same day as the search date' do
          # search=2024-01-20 → search start = Jan 20 00:00; period end = Jan 20 23:59:59 → not before
          expect(endpoint.validate_period_search('eb2024-01-20', closed_period)).to be false
        end

        it 'does not match when period ends after the search date' do
          expect(endpoint.validate_period_search('eb2024-01-15', closed_period)).to be false
        end

        it 'does not match an open-end period (nil end has no defined finish)' do
          expect(endpoint.validate_period_search('eb2024-01-21', open_end_period)).to be false
        end
      end

      context 'with ap (approximately — search overlaps period)' do
        it 'matches when search day equals the period start' do
          expect(endpoint.validate_period_search('ap2024-01-10', closed_period)).to be true
        end

        it 'matches when search day equals the period end' do
          expect(endpoint.validate_period_search('ap2024-01-20', closed_period)).to be true
        end

        it 'matches when search day is inside the period' do
          expect(endpoint.validate_period_search('ap2024-01-15', closed_period)).to be true
        end

        it 'does not match when search day is the day after the period ends' do
          expect(endpoint.validate_period_search('ap2024-01-21', closed_period)).to be false
        end

        it 'does not match when search day is the day before the period starts' do
          expect(endpoint.validate_period_search('ap2024-01-09', closed_period)).to be false
        end
      end
    end
  end
end
