# frozen_string_literal: true

require "bundler/setup"
require "logger"
require "amazing_print"
require "json"
require "paint"
require "terminal-table"
require "time"
require "yaml"

require_relative "bonanza/options"
require_relative "bonanza/config"
require_relative "bonanza/dashboard"
require_relative "bonanza/formatter"
require_relative "bonanza/github"

module Bonanza
  class Error < StandardError; end

  class << self
    attr_accessor :repo_path
    attr_writer :config, :options, :my_teams
  end

  def self.logger
    @logger ||= Logger.new($stdout, progname: "BONANZA")
  end

  def self.log_verbose(message)
    logger.debug(message) if options["verbose"]
  end

  def self.options
    @options ||= Bonanza::Options.parse
  end

  def self.config
    @config ||= Bonanza::Config.new(repo_path, options)
  end

  def self.my_teams
    @my_teams ||= Github.get_my_teams
  end

  def self.boot(repo_path)
    self.repo_path = repo_path
    logger
    config
    my_teams
  end

  def self.run(repo_path)
    boot(repo_path)
    Dashboard.new.render
  end
end
