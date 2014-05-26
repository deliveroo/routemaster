require 'spec_helper'

describe String do
	
  describe '#camelize' do

    context 'when given a String' do

      it 'should return a capitalized version' do
        expect('string'.camelize).to eq('String')
      end

    end

    context 'when given a String with underscores' do

      it 'should return a camelized version' do
        expect('this_string'.camelize).to eq('ThisString')
      end

      it 'should return a camelized version' do
        expect('this_other_string'.camelize).to eq('ThisOtherString')
      end

    end

    context 'when given a path' do

      it 'should return a constant' do
        expect('this/string'.camelize).to eq('This::String')
      end

      it 'should return a constant' do
        expect('this/other/string'.camelize).to eq('This::Other::String')
      end

    end

  end

end