require 'spec_helper'
require 'timeout'
require 'routemaster/services/thread'

describe Routemaster::Services::Thread do
  let(:callback) { -> {
    q.push :hello
  }}

  let(:q) { Queue.new }
  let(:errq) { Queue.new }

  subject { described_class.new(callback, name: 'test', errq: errq) }

  after { subject.stop.wait }

  around { |ex| Timeout.timeout(5) { ex.run } }

  it 'runs the callback' do
    subject
    expect(q.pop).to eq(:hello)
  end

  xit 'cleanup'

  context 'when the callback fails' do
    let(:callback) { -> {
      raise ArgumentError, "you don't even"
    }}

    it 'reports the failure' do
      subject
      expect(errq.pop).to eq(subject)
    end
  end
end
