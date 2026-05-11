# frozen_string_literal: true

require_relative "../test_helper"
require "tmpdir"

class ConfigTest < Minitest::Test

  def with_repo(user_config)
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, ".bonanza.yml"), YAML.dump(user_config))
      yield dir
    end
  end

  def test_loads_default_values_and_merges_user_config
    with_repo("gh_handle" => "vangogh") do |dir|
      config = Bonanza::Config.new(dir)

      assert_equal "vangogh", config.gh_handle
      assert_equal 20,        config.search_limit  # from defaults
      assert_equal "full",    config.display_mode  # from defaults
    end
  end

  def test_user_config_overrides_defaults
    with_repo("gh_handle" => "vangogh", "search_limit" => 5) do |dir|
      config = Bonanza::Config.new(dir)
      assert_equal 5, config.search_limit
    end
  end

  def test_options_override_user_config
    with_repo("gh_handle" => "vangogh", "display_mode" => "full") do |dir|
      config = Bonanza::Config.new(dir, "display_mode" => "compact")
      assert_equal "compact", config.display_mode
    end
  end

  def test_method_missing_returns_values_for_known_keys
    with_repo("gh_handle" => "vangogh", "author_colors" => { "vangogh" => "blue" }) do |dir|
      config = Bonanza::Config.new(dir)
      assert_equal({ "vangogh" => "blue" }, config.author_colors)
    end
  end

  def test_method_missing_falls_through_for_unknown_keys
    with_repo("gh_handle" => "vangogh") do |dir|
      config = Bonanza::Config.new(dir)
      assert_raises(NoMethodError) { config.nonexistent_key }
    end
  end

  def test_respond_to_reports_true_for_known_keys
    with_repo("gh_handle" => "vangogh") do |dir|
      config = Bonanza::Config.new(dir)
      assert config.respond_to?(:gh_handle)
      refute config.respond_to?(:totally_made_up_key)
    end
  end

  def test_raises_when_no_user_config_present
    Dir.mktmpdir do |dir|
      error = assert_raises(Bonanza::Error) { Bonanza::Config.new(dir) }
      assert_match(/Must specify a valid path/, error.message)
    end
  end

  def test_raises_when_gh_handle_is_blank
    with_repo("gh_handle" => "") do |dir|
      error = assert_raises(Bonanza::Error) { Bonanza::Config.new(dir) }
      assert_match(/gh_handle/, error.message)
    end
  end

end
