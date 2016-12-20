require 'spec_helper'
require 'core_ext/hash'

describe Hash do
  describe '#symbolize_keys' do
    it 'leaves {} as is' do
      expect({}.symbolize_keys).to eq({})
    end

    it 'returns a copy' do
      h1 = {'a' => 1}
      h2 = h1.symbolize_keys
      h1['a'] = 2
      expect(h2).to eq(a: 1)
    end

    it 'transforms keys' do
      expect({:a => 1, 'b' => 2, 'c' => 3}.symbolize_keys).
        to eq(a:1, b:2, c:3)
    end
  end

  describe '#map_values' do
    xit
  end
end
