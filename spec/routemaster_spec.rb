require 'spec_helper'
require 'routemaster'

describe Routemaster do
  describe '.now' do
    it 'is an integer' do
      expect(Routemaster.now).to be_a_kind_of(Fixnum)
    end
  end
end
