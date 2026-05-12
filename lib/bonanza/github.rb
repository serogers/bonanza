# frozen_string_literal: true

module Bonanza
  module Github

    def self.get_my_teams
      Bonanza.log_verbose("Fetching user teams")
      teams = JSON.parse(execute("gh api /user/teams --paginate"))
      Set.new(teams.map { |t| "#{t['organization']['login']}/#{t['slug']}" })
    rescue StandardError => e
      Bonanza.log_verbose("Failed to fetch user teams: #{e.message}")
      Set.new
    end

    def self.search_prs(search, limit:, fields:)
      fields_arg = Array(fields).join(",")
      cmd = "PAGER=cat gh pr list --state open --limit #{limit} --json #{fields_arg} #{search}"
      JSON.parse(execute("cd #{Bonanza.repo_path}; #{cmd}"))
    end

    def self.execute(cmd)
      Bonanza.log_verbose("Running command: #{cmd}")
      `#{cmd}`
    end

  end
end
