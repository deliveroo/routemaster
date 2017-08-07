require 'routemaster/controllers'
require 'routemaster/controllers/auth'
require 'routemaster/controllers/parser'
require 'sinatra/base'

module Routemaster
  module Controllers
    class Base < Sinatra::Base
      register Auth
      register Parser
    end
  end
end
