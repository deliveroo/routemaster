require 'spec_helper'
require 'spec/support/persistence'
require 'routemaster/client'
require 'pathname'
require 'routemaster/models/subscription'
require 'core_ext/math'

# turn this on to get verbose tests
VERBOSE = false

describe 'integration' do

  class SubProcess
    def initialize(name:, command:, start: nil, stop: nil)
      @name    = name
      @command = command
      @pid     = nil
      @reader  = nil
      @loglines = []
      @start_regexp = start
      @stop_regexp  = stop
    end

    def start
      raise 'already started' if @pid
      _log 'starting'
      @loglines = []
      rd, wr = IO.pipe
      if @pid = fork
        # parent
        wr.close
        @reader = Thread.new { _read_log(rd) }
      else
        _log 'forked'
        # child
        rd.close
        ENV['ROUTEMASTER_LOG_FILE'] = nil
        $stdin.reopen('/dev/null')
        $stdout.reopen(wr)
        $stderr.reopen(wr)
        $stdout.sync = true
        $stderr.sync = true
        exec @command
      end
      self
    end

    def stop
      return if @pid.nil?
      _log 'stopping'
      Process.kill('TERM', @pid)
      Process.wait(@pid)
      @reader.join
      @pid = nil
      self
    end

    def wait_start
      return unless @start_regexp
      _log 'waiting to start'
      wait_log @start_regexp
      _log 'started'
    end

    def wait_stop
      return unless @stop_regexp
      wait_log @stop_regexp
    end

    def wait_log(regexp)
      Timeout::timeout(25) do
        until @loglines.shift =~ regexp
          sleep(10.ms)
        end
      end
    end

    private

    def _read_log(io)
      while line = io.gets
        if VERBOSE
          $stderr.write line
          $stderr.flush
        end
        @loglines.push line
      end
    end

    def _log(message)
      return unless VERBOSE
      $stderr.write("\t-> #{@name}: #{message}\n")
    end
  end

  WatchProcess = SubProcess.new(
    name:    'watch',
    command: 'ruby -I. watch.rb',
    start:   /INFO: starting watch service/,
    stop:    /INFO: watch completed/
  )

  WebProcess = SubProcess.new(
    name:    'web',
    command: 'unicorn -I. -c config/unicorn.rb',
    start:   /worker=1 ready/,
    stop:    /master complete/
  )

  ClientProcess = SubProcess.new(
    name:    'client',
    command: 'unicorn -I. -c spec/support/client.rb -p 17892 spec/support/client.ru',
    start:   /worker=1 ready/,
    stop:    /master complete/
  )

  ServerTunnelProcess = SubProcess.new(
    name:    'server-tunnel',
    command: 'ruby spec/support/tunnel 127.0.0.1:17893 127.0.0.1:17891',
    start:   /Ready/
  )

  ClientTunnelProcess = SubProcess.new(
    name:    'client-tunnel',
    command: 'ruby spec/support/tunnel 127.0.0.1:17894 127.0.0.1:17892',
    start:   /Ready/
  )

  Processes = [ServerTunnelProcess, ClientTunnelProcess, WatchProcess, WebProcess, ClientProcess]

  before do
    if defined?(WebMock)
      WebMock.disable!
    end
  end

  shared_examples 'start and stop' do
    before { subject.start }
    after  { subject.stop }

    it 'starts cleanly' do
      subject.wait_start
    end

    it 'stops cleanly' do
      subject.wait_start
      subject.stop
      subject.wait_stop
    end
  end

  context 'watch worker' do
    subject { WatchProcess }
    include_examples 'start and stop'
  end

  context 'web worker' do
    subject { WebProcess }
    include_examples 'start and stop'
  end

  context 'client worker' do
    subject { ClientProcess }
    include_examples 'start and stop'
  end

  context 'server tunnel' do
    subject { ServerTunnelProcess }
    include_examples 'start and stop'
  end

  context 'client tunnel' do
    subject { ClientTunnelProcess }
    include_examples 'start and stop'
  end

  context 'server, watch, and receiver running' do
    before { Processes.each(&:start) }
    before { Processes.each(&:wait_start) }
    after  { Processes.each(&:stop) }

    describe 'ruby client' do
      let(:client) {
        Routemaster::Client.new(url: 'https://127.0.0.1:17893', uuid: 'demo')
      }

      it 'connects' do
        expect { client }.not_to raise_error
      end

      it 'subscribes' do
        client.subscribe(
          topics: %w(widgets),
          callback: 'https://127.0.0.1:17894/events'
        )

        sub = Routemaster::Models::Subscription.new(subscriber: 'demo')
        expect(sub.callback).to eq('https://127.0.0.1:17894/events')
      end
      
      it 'publishes' do
        client.created('widgets', 'https://example.com/widgets/1')
      end
    end

    describe 'event reception' do
      let(:client) {
        Routemaster::Client.new(url: 'https://127.0.0.1:17893', uuid: 'demo')
      }

      before do
        # FIXME: this has to be here because subscribing doesnt implicitely
        # create the topics (it should)
        client.created('cats', 'https://example.com/cats/1')
        client.created('dogs', 'https://example.com/dogs/1')

        client.subscribe(
          topics:   %w(cats dogs),
          callback: 'https://127.0.0.1:17894/events',
          uuid:     'demo-client',
          max:      1)
      end

      it 'routes a single event' do
        client.created('cats', 'https://example.com/cats/1')
        ClientProcess.wait_log %r(received https://example.com/cats/1, create, cats)
      end

      it 'routes events from multiple topics' do
        client.created('cats', 'https://example.com/cats/1')
        client.created('dogs', 'https://example.com/dogs/1')
        ClientProcess.wait_log %r{create, cats}
        ClientProcess.wait_log %r{create, dogs}
      end

      it 'sends batches of events'
      it 'sends partial batches after a timeout'
      it 'sends events to multiple clients'
    end
  end
end
