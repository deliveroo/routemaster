require 'spec_helper'
require 'spec/support/counters'
require 'routemaster'

describe Routemaster do
  before do
    # because Routemaster is a module, we need to dip into internals to reset
    Routemaster.instance_variables.each do |ivar|
      Routemaster.instance_variable_set(ivar, nil)
    end
  end

  describe '.now' do
    it 'is an integer' do
      expect(Routemaster.now).to be_a_kind_of(Integer)
    end
  end

  describe '.configure' do
    let(:perform) { Routemaster.configure(redis_pool_size: 42) }

    it 'sets the configuration' do
      expect { perform }.to change { Routemaster.config[:redis_pool_size] }.to(42)
    end

    it 'increments the process start counter' do
      expect { perform }.to change { get_counter('process', type: 'unknown', status: 'start') }.by(1)
    end
  end

  describe '.teardown' do
    let(:perform) { Routemaster.teardown }

    it 'increments the process stop counter' do
      expect { perform }.to change { get_counter('process', type: 'unknown', status: 'stop') }.by(1)
    end
  end
end
