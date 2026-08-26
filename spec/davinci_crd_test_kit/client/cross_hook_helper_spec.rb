require_relative '../../../lib/davinci_crd_test_kit/client/cross_hook_helper'

# Minimal stand-in for the parts of Inferno::TestGroup/Test that
# `find_completeness_tests` walks: `parent`, `groups`, `tests`, and `id`.
FakeRunnable = Struct.new(:id, :parent, :groups, :tests) do
  def initialize(id:, parent: nil, groups: [], tests: [])
    super(id, parent, groups, tests)
  end
end

RSpec.describe DaVinciCRDTestKit::CrossHookHelper do
  let(:test_class) do
    Class.new do
      include DaVinciCRDTestKit::CrossHookHelper

      class << self
        attr_accessor :parent
      end
    end
  end

  let(:instance) { test_class.new }

  let(:appointment_book_prefetch_complete_test) do
    FakeRunnable.new(id: 'crd_client_v221-crd_v221_client_hooks-crd_v221_client_appointment_book-Group03-' \
                         'crd_v221_hook_request_prefetch_complete')
  end
  let(:appointment_book_other_test) do
    FakeRunnable.new(id: 'crd_client_v221-crd_v221_client_hooks-crd_v221_client_appointment_book-Group03-' \
                         'crd_v221_hook_request_conformance')
  end
  let(:appointment_book_requests_subgroup) do
    FakeRunnable.new(id: 'Group03', tests: [appointment_book_other_test, appointment_book_prefetch_complete_test])
  end
  let(:appointment_book_group) do
    FakeRunnable.new(id: 'crd_v221_client_appointment_book', groups: [appointment_book_requests_subgroup])
  end

  let(:order_sign_prefetch_complete_test) do
    FakeRunnable.new(id: 'crd_client_v221-crd_v221_client_hooks-crd_v221_client_order_sign-Group03-' \
                         'crd_v221_hook_request_prefetch_complete')
  end
  let(:order_sign_requests_subgroup) do
    FakeRunnable.new(id: 'Group03', tests: [order_sign_prefetch_complete_test])
  end
  let(:order_sign_group) do
    FakeRunnable.new(id: 'crd_v221_client_order_sign', groups: [order_sign_requests_subgroup])
  end

  let(:hooks_group) do
    FakeRunnable.new(id: 'crd_v221_client_hooks', groups: [appointment_book_group, order_sign_group])
  end
  let(:registration_group) { FakeRunnable.new(id: 'crd_v221_client_registration') }
  let(:hook_invocation_group) do
    FakeRunnable.new(id: 'crd_v221_client_hook_invocation', groups: [registration_group, hooks_group])
  end

  let(:cross_hooks_prefetch_complete_test) do
    FakeRunnable.new(id: 'crd_client_v221-crd_v221_client_cross_hook-crd_v221_client_cross_hook_interaction-' \
                         'Requests-crd_v221_hook_request_prefetch_complete')
  end
  let(:cross_hooks_requests_subgroup) do
    FakeRunnable.new(id: 'Requests', tests: [cross_hooks_prefetch_complete_test])
  end
  let(:cross_hooks_interaction_group) do
    FakeRunnable.new(id: 'crd_v221_client_cross_hook_interaction', groups: [cross_hooks_requests_subgroup])
  end
  let(:cross_hook_group) do
    FakeRunnable.new(id: 'crd_v221_client_cross_hook', parent: hook_invocation_group,
                     groups: [cross_hooks_interaction_group])
  end

  # The including test's own group: `self.class.parent` from `find_completeness_tests`' point of view.
  let(:additional_capabilities_group) do
    FakeRunnable.new(id: 'crd_v221_client_cross_hook_additional_capabilities', parent: cross_hook_group)
  end

  before { test_class.parent = additional_capabilities_group }

  describe '#find_completeness_tests' do
    it 'finds the prefetch-complete test for every hook group and for the cross-hooks interaction group' do
      result = instance.find_completeness_tests

      expect(result).to contain_exactly(
        appointment_book_prefetch_complete_test,
        order_sign_prefetch_complete_test,
        cross_hooks_prefetch_complete_test
      )
    end

    it 'identifies tests by id substring rather than exact match' do
      result = instance.find_completeness_tests

      expect(result).to include(appointment_book_prefetch_complete_test)
      expect(appointment_book_prefetch_complete_test.id).to_not eq('crd_v221_hook_request_prefetch_complete')
    end

    it 'compacts out hooks whose subgroup has no matching completeness test' do
      appointment_book_requests_subgroup.tests = [appointment_book_other_test]

      result = instance.find_completeness_tests

      expect(result).to_not include(nil)
      expect(result).to contain_exactly(order_sign_prefetch_complete_test, cross_hooks_prefetch_complete_test)
    end

    it 'compacts out the cross-hooks completeness test when none is found' do
      cross_hooks_requests_subgroup.tests = []

      result = instance.find_completeness_tests

      expect(result).to_not include(nil)
      expect(result).to contain_exactly(appointment_book_prefetch_complete_test, order_sign_prefetch_complete_test)
    end

    it 'raises if the hooks group cannot be found under the great-grandparent group' do
      hook_invocation_group.groups = [registration_group]

      expect { instance.find_completeness_tests }.to raise_error(NoMethodError)
    end

    it 'raises if the cross-hooks interaction group cannot be found under the grandparent group' do
      cross_hook_group.groups = []

      expect { instance.find_completeness_tests }.to raise_error(NoMethodError)
    end
  end
end
