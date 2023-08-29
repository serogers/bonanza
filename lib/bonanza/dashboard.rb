# frozen_string_literal: true

module Bonanza
  class Dashboard

    COLUMNS = [
      { title: "Done", field: "done", computed: true },
      { title: "Title", field: "title" },
      { title: "Review", field: "reviewDecision" },
      { field: "latestReviews", hidden: true },
      { title: "My Review", field: "myReview", computed: true },
      { title: "PR #", field: "number", hidden: true },
      { title: "Author", field: "author" },
      { title: "Assignees", field: "assignees" },
      { title: "Draft", field: "isDraft" },
      { title: "Labels", field: "labels" },
      { title: "Last Updated", field: "updatedAt" },
      { title: "URL", field: "url" },
      # { title: "Branch", field: "headRefName" }
    ].freeze

    def self.render
      new.render
    end

    def initialize
      @gh_handle     = Bonanza.config["gh_handle"]
      @searches      = (base_searches + Bonanza.config["searches"].to_a).uniq
      @search_limit  = Bonanza.config["limit"] || 20
    end

    def render
      fetch_prs
      print_table
    end

    private

    def base_searches
      [
        "--author #{@gh_handle}",
        "--search involves:#{@gh_handle}"
      ]
    end

    def fetch_prs
      @pr_groups = []
      threads = []

      @searches.each.with_index do |search, index|
        threads << Thread.new do
          @pr_groups[index] = find_prs_by(search).map do |pr|
            Bonanza::Formatter.format(pr)
          end.sort_by { |pr| pr["priority"] }
        end
      end
      threads.each(&:join)
    end

    def find_prs_by(search)
      fields = COLUMNS.reject { |c| c[:computed] }.map { |c| c[:field] }.compact.join(",")
      base = "PAGER=cat gh pr list --state open --limit #{@search_limit} --json #{fields}"
      cmd = "#{base} #{search}"
      JSON.parse(run_cmd(cmd))
    end

    def print_table
      columns = COLUMNS.reject { |c| c[:hidden] }
      rows = []
      prs_added = Set.new

      @pr_groups.each_with_index do |prs, index|
        rows << :separator unless index.zero?
        rows << Array.new(columns.size).tap {|arr| arr[1] = "=> Search: ".white + @searches[index].greenish}
        rows << :separator

        if prs.size.zero?
          rows << Array.new(columns.size).tap {|arr| arr[1] = "No Results"}
        end

        prs.each do |pr|
          unless prs_added.include?(pr["number"])
            rows << pr.slice(*columns.map { |c| c[:field] }).values
            prs_added << pr["number"]
          end
        end
      end

      table_title = "Bonanza! --- Pull requests for #{@gh_handle} (#{Bonanza.repo_path})".white
      table = Terminal::Table.new(title: table_title, rows: rows, headings: columns.map { |c| c[:title] })
      puts table
    end

    def run_cmd(cmd)
      `cd #{Bonanza.repo_path}; #{cmd}`
    end

  end
end
