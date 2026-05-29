# frozen_string_literal: true

require "open3"
require "shellwords"

module Bonanza
  module Github

    def self.get_my_teams
      Bonanza.log_verbose("Fetching user teams")
      teams = JSON.parse(execute("gh", "api", "/user/teams", "--paginate", "--cache", "24h"))
      teams.to_set { |t| "#{t['organization']['login']}/#{t['slug']}" }
    rescue StandardError => e
      Bonanza.log_verbose("Failed to fetch user teams: #{e.message}")
      Set.new
    end

    def self.search_prs(search, limit:, fields:)
      fields_arg = Array(fields).join(",")
      args = ["gh", "pr", "list", "--state", "open", "--limit", limit.to_s, "--json", fields_arg]
      args.concat(Shellwords.split(search.to_s))
      JSON.parse(execute(*args, env: { "PAGER" => "cat" }, chdir: Bonanza.repo_path.to_s))
    end

    def self.execute(*args, env: nil, chdir: nil)
      Bonanza.log_verbose("Running: #{args.inspect}#{chdir ? " (chdir: #{chdir})" : ""}")
      opts = chdir ? { chdir: chdir } : {}
      cmd = env ? [env, *args] : args
      stdout, stderr, status = Open3.capture3(*cmd, **opts)
      unless status.success?
        raise Bonanza::Error, "Command failed (#{args.first}): #{stderr.strip}"
      end
      stdout
    end

  end
end
