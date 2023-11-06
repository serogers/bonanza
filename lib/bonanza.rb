# frozen_string_literal: true

require "bundler/setup"
require "logger"
require "amazing_print"
require "json"
require "paint"
require "set"
require "terminal-table"
require "time"
require "yaml"

require_relative "bonanza/options"
require_relative "bonanza/config"
require_relative "bonanza/dashboard"
require_relative "bonanza/formatter"

module Bonanza
  class Error < StandardError; end

  def self.logger
    @@logger ||= Logger.new($stdout, progname: "BONANZA")
  end

  def self.log_verbose(message)
    logger.debug(message) if options["verbose"]
  end

  def self.repo_path
    @@repo_path
  end

  def self.repo_path=(path)
    @@repo_path = path
  end

  def self.options
    @@options ||= Bonanza::Options.parse
  end

  def self.config
    @@config ||= Bonanza::Config.new(repo_path, options)
  end
end

# Initialize the config
Bonanza.repo_path = ARGV[0]
Bonanza.config

Bonanza::Dashboard.new.render
