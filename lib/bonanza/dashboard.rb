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

    def initialize
      validate_config

      @gh_handle     = Bonanza::CONFIG["gh_handle"]
      @searches      = (base_searches + Bonanza::CONFIG["searches"].to_a).uniq
      @search_limit  = Bonanza::CONFIG["limit"] || 20
    end

    def render
      fetch_prs
      print_table
    end

    private

    def validate_config
      raise Error, "Config: Must supply gh_handle" if Bonanza::CONFIG["gh_handle"].empty?
    end

    def base_searches
      [
        "--author #{@gh_handle}",
        "--search involves:#{@gh_handle}"
      ]
    end

    def fetch_prs
      search_groups = []
      @prs = Set.new
      @separators_at = []

      threads = []
      @searches.each.with_index do |search, index|
        threads << Thread.new do
          search_groups[index] = find_prs_by(search).map do |pr|
            Bonanza::Formatter.format(pr)
          end.sort_by { |pr| pr["priority"] }
        end
      end
      threads.each(&:join)

      search_groups.each.with_index do |group, index|
        @prs.merge(group)
        @separators_at << @prs.size - 1 unless (index == search_groups.size - 1)
      end
    end

    def find_prs_by(search)
      fields = COLUMNS.reject { |c| c[:computed] }.map { |c| c[:field] }.compact.join(",")
      base = "PAGER=cat gh pr list --state open --limit #{@search_limit} --json #{fields}"
      cmd = "#{base} #{search}"
      JSON.parse(run_cmd(cmd))
    end

    def print_table
      columns_to_show = COLUMNS.reject { |c| c[:hidden] }

      rows = []
      @prs.each.with_index do |pr, index|
        rows << pr.slice(*columns_to_show.map { |c| c[:field] }).values

        if @separators_at.include?(index)
          rows << :separator
        end
      end

      repo_loc = "~#{Dir.pwd.sub(Dir::home, "")}"
      table_title = "Bonanza! --- Pull requests for #{@gh_handle} (#{repo_loc})"
      table = Terminal::Table.new(title: table_title, rows: rows, headings: columns_to_show.map { |c| c[:title] })
      puts table
    end

    def run_cmd(cmd)
      `#{cmd}`
    end

  end
end
