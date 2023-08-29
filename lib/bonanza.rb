# frozen_string_literal: true

require "bundler/setup"
require "amazing_print"
require "json"
require "paint"
require "set"
require "terminal-table"
require "time"
require "yaml"

require_relative "bonanza/config"
require_relative "bonanza/dashboard"
require_relative "bonanza/formatter"

module Bonanza
  class Error < StandardError; end

  def self.repo_path
    @@repo_path
  end

  def self.repo_path=(path)
    @@repo_path = path
  end

  def self.config
    @@config ||= Bonanza::Config.new(@@repo_path).config
  end
end

Bonanza.repo_path = ARGV[0]
Bonanza::Dashboard.new.render
