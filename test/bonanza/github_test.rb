# frozen_string_literal: true

require_relative "../test_helper"

class GithubTest < Minitest::Test

  # Replaces Bonanza::Github.execute so tests never invoke the real CLI.
  def stub_exec(output)
    captured = []
    Bonanza::Github.define_singleton_method(:execute) do |cmd|
      captured << cmd
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
      assert_equal ["gh api /user/teams --paginate --cache 24h"], captured
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
      assert_equal [
        "cd /tmp/some-repo; PAGER=cat gh pr list --state open --limit 20 --json number,title --author vangogh",
      ], captured
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
