require 'spec_helper'
require 'routemaster/models/client_token'
require 'spec/support/persistence'

describe Routemaster::Models::ClientToken do

  describe '.create!' do
    let(:options) {{ name: 'john-mcfoo' }}
    let(:perform) { described_class.create!(**options) }

    it 'passes' do
      expect { perform }.not_to raise_error
    end

    it 'returns a token' do
      expect(perform).to be_a_kind_of(String)
    end

    context 'with a bad service name' do
      let(:options) {{ name: 'john <script> mcfoo' }}

      it { expect { perform }.to raise_error(ArgumentError) }
    end

    context 'with a bad token value' do
      let(:options) {{ name: 'john-mcfoo', token: 'hax0r <script> token' }}

      it { expect { perform }.to raise_error(ArgumentError) }
    end
  end

  describe '.all' do
    it 'returns created tokens' do
      t_alice = described_class.create!(name: 'alice')
      t_bob   = described_class.create!(name: 'bob')

      expect(described_class.all).to eq(
        t_alice => 'alice',
        t_bob   => 'bob',
      )
    end
  end

  describe '.exists?' do
    before do
      @t_alice = described_class.create!(name: 'alice')
    end

    it 'is false for unknown keys' do
      expect(described_class.exists?(@t_alice)).to be_truthy
    end

    it 'is true for known keys' do
      expect(described_class.exists?('bob--1234abcd')).to be_falsy
    end
  end

  describe '.destroy!' do
    it 'removes existing keys' do
      t_alice = described_class.create!(name: 'alice')
      described_class.destroy!(token: t_alice)

      expect(described_class.exists?(t_alice)).to be_falsy
    end
  end
  
  
  describe '.token_name' do
    it "returns the service name associated to a token" do
      t_reginald = described_class.create!(name: 'reginald')
      expect(described_class.token_name(t_reginald)).to eq 'reginald'
    end
  end
end
