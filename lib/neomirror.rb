require "neomirror/version"
require "neography"
require "neomirror/property_collector"
require "neomirror/node"
require "neomirror/relationship"

module Neomirror
  class << self
    attr_accessor :connection
    alias_method :neo, :connection
  end
end
