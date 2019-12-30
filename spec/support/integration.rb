require 'spec_helper'
require 'spec/support/persistence'
require 'spec/support/webmock'
require 'core_ext/math'

# turn this on to get verbose tests
VERBOSE = ENV.fetch('VERBOSE_ACCEPTANCE_TESTS', 'NO') == 'YES'

module Acceptance
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
      _logline 'starting'
      @loglines = []
      rd, wr = IO.pipe
      if @pid = fork
        # parent
        wr.close
        @reader = Thread.new { _read_log(rd) }
      else
        _logline "forked (##{$$})"
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

    # politely ask the process to stop
    def stop
      return if @pid.nil?
      _logline "stopping (##{@pid})"
      Process.kill('INT', @pid)
      self
    end

    # after calling `start`, wait until the process has logged a line indicating
    # it is ready for use
    def wait_start
      return unless @start_regexp && @pid
      _logline 'waiting to start'
      wait_log @start_regexp
      _logline "started (##{@pid})"
      self
    end

    # after calling `stop`, wait until the log exhibits an entry indicating
    # the process has stoped cleanly
    def wait_stop
      return unless @stop_regexp && @pid
      _logline "waiting to stop (##{@pid})"
      wait_log @stop_regexp
      _logline 'stopped'
    ensure
      terminate
    end

    # terminate the process without waiting
    def terminate
      if @pid
        Process.kill('KILL', @pid)
        Process.wait(@pid)
      end
      @reader.join if @reader
      @pid = @reader = nil
      self
    end

    # wait until a log line is seen that matches `regexp`, up to a timeout
    def wait_log(regexp)
      begin
        _logline "wait_log - '#{regexp}' - starting"
        Timeout::timeout(10) do
          loop do
            line = @loglines.shift
            if line.nil?
              sleep(1.ms) 
            elsif line =~ regexp
              _logline "match - '#{regexp}'"
              break
            else
              _logline "no match - #{line}"
            end
          end
        end
      rescue Timeout::Error
        _logline "timed out - '#{regexp}'"
      ensure
        
      end
      _logline "wait_log - '#{regexp}' - finished"
      self
    end

    private
 
    def _read_log(io)
      while line = io.gets
        if VERBOSE
          _log line
        end
        @loglines.push line
      end
    end

    def _log(message)
      return unless VERBOSE
      $stderr.write("[#{@pid}] [#{Time.now.to_s}] \t-> #{@name}: #{message}")
    end
    def _logline(message)
      _log "#{message}\n"
    end
  end

  class ProcessLibrary
    def watch
      @watch ||= SubProcess.new(
        name:    'worker',
        command: './bin/worker',
        start:   /job worker: started/,
        stop:    /job worker: completed/
      )
    end

    def web
      @web ||= SubProcess.new(
        name:    'web',
        command: 'puma -I. -C config/puma.rb',
        start:   /Worker 1.*booted/,
        stop:    /Goodbye!/
      )
    end

    def client
      @client ||= SubProcess.new(
        name:    'client',
        command: 'puma -I. -w 2 -p 17892 -C /dev/null spec/support/client.ru',
        start:   /Worker 1.*booted/,
        stop:    /Goodbye!/
      )
    end

    def server_tunnel
      @server_tunnel ||= SubProcess.new(
        name:    'server-tunnel',
        command: 'ruby spec/support/tunnel 127.0.0.1:17893 127.0.0.1:17891',
        start:   /Ready/,
        stop:    /tunnel terminated/,
      )
    end

    def client_tunnel 
      @client_tunnel ||= SubProcess.new(
        name:    'client-tunnel',
        command: 'ruby spec/support/tunnel 127.0.0.1:17894 127.0.0.1:17892',
        start:   /Ready/,
        stop:    /tunnel terminated/,
      )
    end

    def all
      [server_tunnel, client_tunnel, watch, web, client]
    end
  end
end

