require 'spec_helper'
require 'core_ext/env'
require 'spec/support/env'

describe ENV do
  describe '#ifetch' do
    it 'allows indirection' do
      ENV['FOO_BAR'] = 'foobar'
      ENV['QUX'] = 'FOO_BAR'

      expect(ENV.ifetch('QUX')).to eq('foobar')
    end

    it 'fetchs without indirection' do
      ENV['QUX'] = 'foobar'
      expect(ENV.ifetch('QUX')).to eq('foobar')
    end
  end
end
