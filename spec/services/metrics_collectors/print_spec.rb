require 'spec_helper'
require 'routemaster/application'
require 'routemaster/mixins/log'
require 'routemaster/mixins/deliver_metric'
require 'routemaster/services/metrics_collectors/print'

describe Routemaster::Services::MetricsCollectors::Print do

  describe '#process' do

    let(:subject) { described_class.instance }

    it 'should work' do
      name = "test.collection"
      value = 10.5
      tags = [
        'host:routemaster.test.app',
        'env:test',
        'app:routemaster-test'
      ]
      expect_any_instance_of(described_class).to receive(:_log_message)
        .with("#{name}:#{value} (#{tags.join(',')})")
      subject.perform(name, value, tags)
    end

  end

end
