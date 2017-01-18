require 'spec_helper'
require 'spec/support/persistence'
require 'routemaster/mixins/redis'

describe Routemaster::Mixins::Redis do
  include described_class

  describe '#_redis_lua_run' do
    def perform
      _redis_lua_run('sum', argv:[2,3,4])
    end

    it 'runs named scripts' do
      expect(perform).to eq(9)
    end

    context 'when scripts gets flushed' do
      before do
        perform
        _redis.script('flush')
      end

      it { expect { perform }.not_to raise_error }
    end
  end
end
