# frozen_string_literal: true

require "bundler/setup"
require "minitest/autorun"
require "tmpdir"

require_relative "../lib/bonanza"

module FixtureHelpers
  FIXTURE_DIR      = File.expand_path("fixtures", __dir__)
  FIXTURE_REPO_DIR = File.join(FIXTURE_DIR, "repo")

  def load_fixture(name)
    JSON.parse(File.read(File.join(FIXTURE_DIR, "#{name}.json")))
  end

  def pr_fixture(number)
    load_fixture("pr_list").find { |pr| pr["number"] == number } ||
      raise("No PR ##{number} in pr_list fixture")
  end
end

module ConfigHelpers
  # Build a real Bonanza::Config from the fixture .bonanza.yml. When overrides
  # are passed, the fixture is merged with them in a tempdir so individual
  # tests can customize values without mutating the shared fixture on disk.
  def build_fixture_config(overrides = {})
    if overrides.empty?
      Bonanza::Config.new(FixtureHelpers::FIXTURE_REPO_DIR)
    else
      base = YAML.load_file(File.join(FixtureHelpers::FIXTURE_REPO_DIR, ".bonanza.yml"))
      merged = base.merge(overrides.transform_keys(&:to_s))
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, ".bonanza.yml"), YAML.dump(merged))
        return Bonanza::Config.new(dir)
      end
    end
  end

  def with_config(overrides = {})
    previous = Bonanza.config
    Bonanza.config = build_fixture_config(overrides)
    yield
  ensure
    Bonanza.config = previous
  end
end

class Minitest::Test
  include FixtureHelpers
  include ConfigHelpers

  def setup
    Bonanza.options = {}
    Bonanza.config  = build_fixture_config
  end
end
