# frozen_string_literal: true

module Bonanza
  class Dashboard

    COLUMNS = [
      { title: "Done", field: "done", computed: true, compact: true },
      { title: "Title", field: "title", compact: true },
      { title: "Review", field: "reviewDecision", compact: true },
      { field: "latestReviews", hidden: true },
      { title: "My Review", field: "myReview", computed: true, compact: true },
      { title: "PR #", field: "number", hidden: true },
      { title: "Author", field: "author", compact: true },
      { title: "Assignees", field: "assignees" },
      { title: "Draft", field: "isDraft" },
      { title: "Labels", field: "labels" },
      { title: "Last Updated", field: "updatedAt", compact: true },
      { title: "URL", field: "url", compact: true },
      # { title: "Branch", field: "headRefName" }
    ].freeze

    def self.render
      new.render
    end

    def initialize
      Bonanza.log_verbose("Initializing dashboard")

      @gh_handle     = Bonanza.config.gh_handle
      @searches      = (base_searches + Bonanza.config.searches.to_a).uniq
      @search_limit  = Bonanza.config.search_limit
    end

    def render
      fetch_prs
      print_table
    end

    private

    def display_columns
      @display_columns ||= case Bonanza.config.display_mode
        when "compact"
          COLUMNS.reject { |c| c[:hidden] }.select { |c| c[:compact] }
        else
          COLUMNS.reject { |c| c[:hidden] }
        end
    end

    def search_columns
      @search_columns ||= COLUMNS.reject { |c| c[:computed] }
    end

    def base_searches
      [
        "--author #{@gh_handle}",
        "--search involves:#{@gh_handle}"
      ]
    end

    def fetch_prs
      Bonanza.log_verbose("Fetching pull requests")

      @pr_groups = []
      threads = []

      @searches.each.with_index do |search, index|
        threads << Thread.new do
          Bonanza.log_verbose("Searching: #{search}")
          @pr_groups[index] = find_prs_by(search).map do |pr|
            Bonanza.log_verbose("Formatting: PR #{pr['number']}")
            Bonanza::Formatter.format(pr)
          end.sort_by { |pr| pr["priority"] }
        end
      end
      threads.each(&:join)

      Bonanza.log_verbose("Found #{@pr_groups.sum(&:size)} pull requests across #{@pr_groups.size} searches")
    end

    def find_prs_by(search)
      fields = search_columns.map { |c| c[:field] }.compact.join(",")
      base = "PAGER=cat gh pr list --state open --limit #{@search_limit} --json #{fields}"
      cmd = "#{base} #{search}"
      JSON.parse(run_cmd(cmd))
    end

    def print_table
      Bonanza.log_verbose("Printing table")

      rows = []
      prs_added = Set.new

      @pr_groups.each_with_index do |prs, index|
        rows << :separator unless index.zero?
        rows << Array.new(display_columns.size).tap do |arr|
          arr[1] = Bonanza::Formatter.colorize("=> Search: ", color: :white) + Bonanza::Formatter.colorize(@searches[index], color: :greenish)
        end
        rows << :separator

        if prs.size.zero?
          rows << Array.new(display_columns.size).tap {|arr| arr[1] = "No Results"}
        end

        prs.each do |pr|
          unless prs_added.include?(pr["number"])
            rows << pr.slice(*display_columns.map { |c| c[:field] }).values
            prs_added << pr["number"]
          end
        end
      end

      table_title = Bonanza::Formatter.colorize("Bonanza! --- Pull requests for #{@gh_handle} (#{Bonanza.repo_path})", color: :white)
      table = Terminal::Table.new(title: table_title, rows: rows, headings: display_columns.map { |c| c[:title] })
      puts table
    end

    def run_cmd(cmd)
      Bonanza.log_verbose("Running command: #{cmd}")
      `cd #{Bonanza.repo_path}; #{cmd}`
    end

  end
end
