require 'spec_helper'
require 'spec/support/persistence'
require 'routemaster/models/subscribers'
require 'routemaster/models/user'

describe Routemaster::Models::Subscribers do
  User = Routemaster::Models::User

  let(:topic) { stub 'Topic', name: 'widgets' }
  subject { described_class.new(topic) }

  describe '#initialize' do
    it 'passes' do
      expect { subject }.not_to raise_error
    end
  end

  describe '#to_a' do
    it 'returns an array' do
      expect(subject.to_a).to be_a_kind_of(Array)
    end
  end

  describe '#add' do
    it 'adds the subscriber' do
      subject.add User.new('bob')
      expect(subject.to_a).to eq(%w(bob))
    end

    it 'behaves like a set' do
      subject.add User.new('alice')
      subject.add User.new('bob')
      subject.add User.new('alice')
      expect(subject.to_a.sort).to eq(%w(alice bob))
    end
  end
end

