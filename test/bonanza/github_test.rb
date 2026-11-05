# frozen_string_literal: true

require_relative "../test_helper"

class GithubTest < Minitest::Test

  # Replaces Bonanza::Github.execute so tests never invoke the real CLI.
  # Pass a responder lambda instead of output to answer per command.
  def stub_exec(output = nil, responder: nil)
    captured = []
    Bonanza::Github.define_singleton_method(:execute) do |*args, **kwargs|
      captured << { args: args, kwargs: kwargs }
      responder ? responder.call(args) : output
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

  # --- get_repo_name --------------------------------------------------------

  # Answers `git remote get-url <remote>` from a hash; missing remotes fail
  # the way git does.
  def remotes_responder(remotes)
    ->(args) { remotes.fetch(args.last) { raise Bonanza::Error, "error: No such remote" } }
  end

  def test_get_repo_name_reads_git_remote_in_repo
    Bonanza.repo_path = "/tmp/some-repo"
    stub_exec("git@github.com:example/repo.git\n") do |captured|
      assert_equal "example/repo", Bonanza::Github.get_repo_name
      assert_equal [{
        args: ["git", "remote", "get-url", "upstream"],
        kwargs: { chdir: "/tmp/some-repo" },
      }], captured
    end
  ensure
    Bonanza.repo_path = nil
  end

  def test_get_repo_name_parses_github_remote_formats
    %w[
      git@github.com:example/repo.git
      git@github.com:example/repo
      https://github.com/example/repo.git
      https://github.com/example/repo
      https://github.com/example/repo/
      ssh://git@github.com/example/repo.git
    ].each do |url|
      stub_exec(url) do
        assert_equal "example/repo", Bonanza::Github.get_repo_name, "failed to parse #{url}"
      end
    end
  end

  def test_get_repo_name_keeps_dots_in_repo_name
    stub_exec("git@github.com:example/repo.github.io.git") do
      assert_equal "example/repo.github.io", Bonanza::Github.get_repo_name
    end
  end

  def test_get_repo_name_prefers_upstream_over_origin
    remotes = { "upstream" => "git@github.com:example/repo.git", "origin" => "git@github.com:me/repo.git" }
    stub_exec(responder: remotes_responder(remotes)) do
      assert_equal "example/repo", Bonanza::Github.get_repo_name
    end
  end

  def test_get_repo_name_falls_back_to_origin_when_upstream_is_missing
    stub_exec(responder: remotes_responder("origin" => "git@github.com:me/repo.git")) do
      assert_equal "me/repo", Bonanza::Github.get_repo_name
    end
  end

  def test_get_repo_name_skips_non_github_remotes
    remotes = { "upstream" => "git@gitlab.com:example/repo.git", "origin" => "git@github.com:me/repo.git" }
    stub_exec(responder: remotes_responder(remotes)) do
      assert_equal "me/repo", Bonanza::Github.get_repo_name
    end
  end

  def test_get_repo_name_raises_when_no_github_remote
    stub_exec(responder: remotes_responder({})) do
      error = assert_raises(Bonanza::Error) { Bonanza::Github.get_repo_name }
      assert_match(/No GitHub remote found/, error.message)
    end
  end

  # --- build_search ---------------------------------------------------------

  def test_build_search_scopes_to_open_prs_in_repo_sorted_by_update
    assert_equal "repo:example/repo is:pr is:open label:critical sort:updated-desc",
                 Bonanza::Github.build_search("label:critical")
  end

  def test_build_search_keeps_a_user_supplied_sort
    assert_equal "repo:example/repo is:pr is:open label:critical sort:created-asc",
                 Bonanza::Github.build_search("label:critical sort:created-asc")
  end

  def test_build_search_handles_blank_search
    assert_equal "repo:example/repo is:pr is:open sort:updated-desc", Bonanza::Github.build_search(nil)
  end

  # --- search_prs -----------------------------------------------------------

  def test_search_prs_invokes_gh_api_graphql_with_variables
    stub_exec("{}") do |captured|
      Bonanza::Github.search_prs("author:vangogh", limit: 20)
      assert_equal [{
        args: [
          "gh", "api", "graphql",
          "-f", "query=#{Bonanza::Github::SEARCH_QUERY}",
          "-f", "search=repo:example/repo is:pr is:open author:vangogh sort:updated-desc",
          "-F", "limit=20",
        ],
        kwargs: {},
      }], captured
    end
  end

  def test_search_prs_passes_search_as_a_single_argument_without_a_shell
    # Shell metacharacters must stay inside the search variable, not be interpreted.
    stub_exec("{}") do |captured|
      Bonanza::Github.search_prs("author:vangogh; rm -rf ~", limit: 5)
      assert_includes captured.first[:args],
                      "search=repo:example/repo is:pr is:open author:vangogh; rm -rf ~ sort:updated-desc"
    end
  end

  def test_search_prs_flattens_connections
    stub_exec(load_fixture("search_prs").to_json) do
      pr = Bonanza::Github.search_prs("author:monet", limit: 20).first

      assert_equal [{ "login" => "current_user" }], pr["assignees"]
      assert_equal [{ "name" => "frontend", "color" => "0052cc" }], pr["labels"]
      assert_equal ["COMMENTED"], pr["latestReviews"].map { |r| r["state"] }
      assert_equal ["APPROVED"], pr["latestOpinionatedReviews"].map { |r| r["state"] }
      assert_equal({ "login" => "monet" }, pr["author"])
    end
  end

  def test_search_prs_unwraps_review_requests_and_drops_unknown_reviewers
    stub_exec(load_fixture("search_prs").to_json) do
      pr = Bonanza::Github.search_prs("author:monet", limit: 20).first
      assert_equal [{ "slug" => "the-met/team-monet" }, { "login" => "rodin" }], pr["reviewRequests"]
    end
  end

  def test_search_prs_drops_non_pull_request_results
    stub_exec(load_fixture("search_prs").to_json) do
      assert_equal [107], Bonanza::Github.search_prs("author:monet", limit: 20).map { |pr| pr["number"] }
    end
  end

  def test_search_prs_returns_empty_array_when_no_results
    stub_exec({ "data" => { "search" => { "nodes" => [] } } }.to_json) do
      assert_equal [], Bonanza::Github.search_prs("author:nobody", limit: 20)
    end
  end

end
