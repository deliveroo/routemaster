require 'routemaster/models/bunny_channel'

describe Routemaster::Models::BunnyChannel do
  subject { Routemaster::Models::BunnyChannel.instance }

  let(:channel) { double('Channel', mocked_method: true, closed?: false) }
  let(:session) do
    double(
      'Session',
      create_channel: channel,
      closed?: false,
      closing?: false,
      close: true
    )
  end

  before do
    allow(subject).to receive(:disconnect)
    allow(session).to receive(:start).and_return(session)
    allow(Bunny).to receive(:new).and_return(session)

    # Reset the singleton
    Singleton.__init__(described_class)
  end

  after(:all) { Singleton.__init__(described_class) }

  context 'when connection is not establised' do
    context 'when bunny continuation timeout is not set' do
      it 'creates a new Bunny session' do
        expect(Bunny).to receive(:new).with(
          ENV['ROUTEMASTER_AMQP_URL'],
          continuation_timeout: Bunny::Session::DEFAULT_CONTINUATION_TIMEOUT
        ).and_return(session)

        subject.mocked_method
      end
    end

    context 'when bunny continuation timeout is set' do
      it 'creates a new Bunny session' do
        ENV['BUNNY_CONTINUATION_TIMEOUT'] = '1000'

        expect(Bunny).to receive(:new).with(
          ENV['ROUTEMASTER_AMQP_URL'],
          continuation_timeout: 1000
        ).and_return(session)

        subject.mocked_method

        ENV['BUNNY_CONTINUATION_TIMEOUT'] = nil
      end
    end
  end

  context 'when connection is already established' do
    before { subject.mocked_method }

    it 'creates a new Bunny session' do
      expect(Bunny).to_not receive(:new)

      subject.mocked_method
    end
  end

  context 'on timeout' do
    context 'raises error only once' do
      before do
        @times_called = 0

        allow(Bunny).to receive(:new) do
          @times_called += 1

          if @times_called == 1
            raise Timeout::Error
          else
            session
          end
        end
      end

      it 'should disconnect before reconnecting' do
        expect(subject).to receive(:disconnect).once
        subject.mocked_method
      end

      it { expect { subject.mocked_method }.to_not raise_error }
    end

    context 'after three timeouts' do
      before do
        allow(Bunny).to receive(:new).exactly(3).times.and_raise(Timeout::Error)
      end

      it { expect { subject.mocked_method }.to raise_error(Timeout::Error) }
    end
  end
end
