require 'spec_helper'
require 'routemaster/application'
require 'routemaster/mixins/log'
require 'routemaster/services/metrics/emit'
require 'routemaster/services/metrics/print_adapter'

describe Routemaster::Services::Metrics::PrintAdapter do

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
      expect(subject.gauge(name, value, tags)).to be_truthy
    end

  end

end
