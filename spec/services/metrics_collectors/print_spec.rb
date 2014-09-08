require 'spec_helper'
require 'routemaster/application'
require 'routemaster/mixins/log'
require 'routemaster/services/deliver_metric'
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
      expect{subject.perform(name, value, tags)}.to_not raise_error
    end

  end

end
