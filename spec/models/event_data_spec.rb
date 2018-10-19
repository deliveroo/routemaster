require 'spec_helper'
require 'bigdecimal'
require 'routemaster/models/event_data'

describe Routemaster::Models::EventData do
  describe '.build' do
    subject(:build) { described_class.build(data) }

    context 'data size is acceptable' do
      let(:data) {{
        'one' => 1,
        'two' => {
          'a' => 'b',
          'c' => 3.4,
          'd' => {
            'e' => BigDecimal.new(3, 2)
          }
        },
        'three' => BigDecimal.new('1,2345', 2)
      }}

      specify do
        expect(build).to be_a described_class
      end
    end

    context 'data size is very large' do
        let(:data) do
          {}.tap do |hash|
            100.times do |i|
              hash[i] = "some-long-string" * (i + 1)
            end
          end
        end

      specify do
        expect { build }.to raise_error(ArgumentError)
      end
    end
  end
end
