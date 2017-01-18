require 'routemaster/controllers'
require 'routemaster/mixins/log'
require 'sinatra/base'
require 'oj'

module Routemaster
  module Controllers
    module Parser
      module Helpers
        include Mixins::Log

        def data
          @parsed_data
        end
      end

      def self.registered(app)
        app.helpers Helpers

        app.set :parse do |format|
          condition do
            case format
            when :json
              begin
                @parsed_data = Oj.load(request.body.read, mode: :compat)
              rescue Oj::ParseError => e
                _log.warn("JSON parse error: '#{e.message}'")
                halt 400
              end
            else
              raise "unknown format '#{format}'"
            end
          end
        end
      end
    end
  end
end

