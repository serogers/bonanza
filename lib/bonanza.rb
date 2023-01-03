# frozen_string_literal: true

require "amazing_print"
require "json"
require "paint"
require "set"
require "terminal-table"
require "time"
require "yaml"

require_relative "bonanza/dashboard"
require_relative "bonanza/formatter"

module Bonanza
  class Error < StandardError; end

  CONFIG_PATH = File.join(Dir.pwd, ".bonanza.yml")
  CONFIG      = YAML.load_file(CONFIG_PATH)
end


Bonanza::Dashboard.new.render
