# frozen_string_literal: true

require_relative "../test_helper"

class GithubTest < Minitest::Test

  # Replaces Bonanza::Github.execute so tests never invoke the real CLI.
  def stub_exec(output)
    captured = []
    Bonanza::Github.define_singleton_method(:execute) do |*args, **kwargs|
      captured << { args: args, kwargs: kwargs }
      output
    end
    yield captured
  ensure
    Bonanza::Github.singleton_class.send(:remove_method, :execute)
  end

  # --- get_my_teams ---------------------------------------------------------

  def test_get_my_teams_invokes_gh_user_teams_with_pagination_and_cache
    stub_exec("[]") do |captured|
      Bonanza::Github.get_my_teams
      assert_equal [{
        args: ["gh", "api", "/user/teams", "--paginate", "--cache", "24h"],
        kwargs: {},
      }], captured
    end
  end

  def test_get_my_teams_returns_a_set
    stub_exec("[]") do
      assert_kind_of Set, Bonanza::Github.get_my_teams
    end
  end

  def test_get_my_teams_maps_each_team_to_org_slash_slug
    stub_exec(load_fixture("teams_list").to_json) do
      teams = Bonanza::Github.get_my_teams

      assert_equal Set.new(%w[
        The-Salon-de-Paris/salon-patrons
        the-met/painters
        the-met/team-monet
      ]), teams
    end
  end

  def test_get_my_teams_returns_empty_set_when_user_has_no_teams
    stub_exec("[]") do
      assert_equal Set.new, Bonanza::Github.get_my_teams
    end
  end

  def test_get_my_teams_returns_empty_set_when_output_is_blank
    stub_exec("") do
      assert_equal Set.new, Bonanza::Github.get_my_teams
    end
  end

  def test_get_my_teams_returns_empty_set_when_output_is_not_json
    stub_exec("gh: command not found") do
      assert_equal Set.new, Bonanza::Github.get_my_teams
    end
  end

  # --- search_prs -----------------------------------------------------------

  def test_search_prs_builds_gh_pr_list_command_in_repo
    Bonanza.repo_path = "/tmp/some-repo"
    stub_exec("[]") do |captured|
      Bonanza::Github.search_prs("--author vangogh", limit: 20, fields: %w[number title])
      assert_equal [{
        args: ["gh", "pr", "list", "--state", "open", "--limit", "20", "--json", "number,title", "--author", "vangogh"],
        kwargs: { env: { "PAGER" => "cat" }, chdir: "/tmp/some-repo" },
      }], captured
    end
  ensure
    Bonanza.repo_path = nil
  end

  def test_search_prs_splits_search_string_into_argv_without_a_shell
    Bonanza.repo_path = "/tmp/some-repo"
    # A malicious search string with shell metacharacters must be passed as
    # literal argv tokens, not interpreted by a shell.
    stub_exec("[]") do |captured|
      Bonanza::Github.search_prs("--author vangogh; rm -rf ~", limit: 5, fields: %w[number])
      assert_equal(
        ["gh", "pr", "list", "--state", "open", "--limit", "5", "--json", "number", "--author", "vangogh;", "rm", "-rf", "~"],
        captured.first[:args],
      )
    end
  ensure
    Bonanza.repo_path = nil
  end

  def test_search_prs_parses_json_output
    stub_exec('[{"number":101},{"number":102}]') do
      result = Bonanza::Github.search_prs("--author vangogh", limit: 20, fields: %w[number])
      assert_equal [{ "number" => 101 }, { "number" => 102 }], result
    end
  end

end
