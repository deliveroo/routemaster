require 'spec_helper'
require 'routemaster/mixins/log'

describe Routemaster::Mixins::Log do
  include described_class

  describe '#_log_level_invalid?' do
    context 'when valid log level provided' do
      it 'return false' do
        ENV['ROUTEMASTER_LOG_LEVEL'] = 'INFO'
        expect(_log_level_invalid?).to eq(false)
      end
    end

    context 'when invalid log level provided' do
      it 'return false' do
        ENV['ROUTEMASTER_LOG_LEVEL'] = 'FOO'
        expect(_log_level_invalid?).to eq(true)
      end
    end
  end
end
