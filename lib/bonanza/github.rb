# frozen_string_literal: true

require "open3"

module Bonanza
  module Github

    # Only the fields the dashboard uses. Connections are kept small since each
    # nested lookup adds server-side time (see `reviews` vs `latestReviews`).
    SEARCH_QUERY = <<~GRAPHQL
      query($search: String!, $limit: Int!) {
        search(query: $search, type: ISSUE, first: $limit) {
          nodes {
            ... on PullRequest {
              number
              title
              url
              isDraft
              reviewDecision
              updatedAt
              baseRefName
              additions
              deletions
              author { login }
              assignees(first: 10) { nodes { login } }
              labels(first: 20) { nodes { name color } }
              reviewRequests(first: 20) {
                nodes {
                  requestedReviewer {
                    ... on User { login }
                    ... on Team { slug: combinedSlug }
                  }
                }
              }
              latestReviews(first: 20) { nodes { author { login } state submittedAt } }
              latestOpinionatedReviews(first: 20) { nodes { author { login } state submittedAt } }
            }
          }
        }
      }
    GRAPHQL

    def self.get_my_teams
      Bonanza.log_verbose("Fetching user teams")
      teams = JSON.parse(execute("gh", "api", "/user/teams", "--paginate", "--cache", "24h"))
      teams.to_set { |t| "#{t['organization']['login']}/#{t['slug']}" }
    rescue StandardError => e
      Bonanza.log_verbose("Failed to fetch user teams: #{e.message}")
      Set.new
    end

    def self.get_repo_name
      Bonanza.log_verbose("Fetching repo name")
      execute("gh", "repo", "view", "--json", "nameWithOwner", "--jq", ".nameWithOwner", chdir: Bonanza.repo_path.to_s).strip
    end

    def self.search_prs(search, limit:)
      response = JSON.parse(execute(
        "gh", "api", "graphql",
        "-f", "query=#{SEARCH_QUERY}",
        "-f", "search=#{build_search(search)}",
        "-F", "limit=#{limit}"
      ))
      response.dig("data", "search", "nodes").to_a.reject(&:empty?).map { |pr| normalize_pr(pr) }
    end

    # Scopes a user search to open PRs in the current repo, most recently updated first.
    def self.build_search(search)
      parts = ["repo:#{Bonanza.repo_name}", "is:pr", "is:open", search.to_s.strip]
      parts << "sort:updated-desc" unless search.to_s.include?("sort:")
      parts.reject(&:empty?).join(" ")
    end

    # Flattens GraphQL connections ({ "nodes" => [...] }) into plain arrays.
    def self.normalize_pr(pr)
      pr = pr.transform_values { |value| value.is_a?(Hash) && value.key?("nodes") ? value["nodes"] : value }
      pr["reviewRequests"] = pr["reviewRequests"].to_a.filter_map { |req| req["requestedReviewer"] }
      pr
    end

    def self.execute(*args, chdir: nil)
      Bonanza.log_verbose("Running: #{args.inspect}#{chdir ? " (chdir: #{chdir})" : ""}")
      opts = chdir ? { chdir: chdir } : {}
      stdout, stderr, status = Open3.capture3(*args, **opts)
      unless status.success?
        raise Bonanza::Error, "Command failed (#{args.first}): #{stderr.strip}"
      end
      stdout
    end

  end
end
