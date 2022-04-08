# frozen_string_literal: true

module Bonanza
  class Formatter

    PR_REVIEW_PRIORITY = [
      "REQUIRED",
      "REJECTED",
      "APPROVED",
      ""
    ].freeze

    PR_REVIEW_STATUS_MAP = {
      "REVIEW_REQUIRED"   => "REQUIRED",
      "CHANGES_REQUESTED" => "REJECTED",
    }.freeze

    STATUS_COLORS = {
      "APPROVED"  => :green,
      "REQUIRED"  => :yellow,
      "REJECTED"  => :red,
      "COMMENTED" => :orange
    }.freeze

    def self.format(pr)
      # Order matters as some build off each other
      pr["priority"]       = format_priority(pr)
      pr["done"]           = format_done(pr)
      pr["myReview"]       = format_my_review(pr)
      pr["reviewDecision"] = format_review(pr)
      pr["title"]          = format_title(pr)
      pr["author"]         = format_author(pr)
      pr["assignees"]      = format_assignees(pr)
      pr["labels"]         = format_labels(pr)
      pr["isDraft"]        = format_draft(pr)
      pr["updatedAt"]      = format_updated_at(pr)
      pr
    end

    def self.get_review_status(pr)
      if pr["isDraft"]
        ""
      elsif pr["reviewDecision"].nil? || pr["reviewDecision"].empty?
        "REQUIRED" # GH sometimes has empty reviewDecision for PRs that are open and have no reviews yet
      else
        PR_REVIEW_STATUS_MAP[pr["reviewDecision"]] || pr["reviewDecision"]
      end
    end

    def self.get_my_review_status(pr)
      pr["latestReviews"].to_a.find { |r| r["author"]["login"] == Bonanza::CONFIG["gh_handle"] }.to_h["state"]
    end

    def self.format_priority(pr)
      review_status = get_review_status(pr)
      my_review_status = get_my_review_status(pr)

      pr_status = my_review_status == "APPROVED" ? my_review_status : review_status
      PR_REVIEW_PRIORITY.index(pr_status)
    end

    def self.format_my_review(pr)
      status = get_my_review_status(pr)
      status = "REJECTED" if status == "CHANGES_REQUESTED"
      color  = STATUS_COLORS[status]
      colorize(status, color: color)
    end

    def self.format_review(pr)
      status = get_review_status(pr)
      color  = STATUS_COLORS[status]
      colorize(status, color: color)
    end

    def self.format_done(pr)
      review_done    = ["APPROVED", "REJECTED"].include?(get_review_status(pr))
      my_review_done = get_my_review_status(pr) == "APPROVED"
      draft_pr       = pr["isDraft"]

      done = review_done || my_review_done || draft_pr
      pr["done"] = done ? " 🟢" : " ⭕️"
    end

    def self.format_title(pr)
      "PR #{pr['number']}: ".blue + truncate(pr["title"], 55)
    end

    def self.format_author(pr)
      author = pr["author"]["login"]
      color  = Bonanza::CONFIG["author_colors"].to_h[author]
      color ? colorize(author, color: color) : author
    end

    def self.format_assignees(pr)
      pr["assignees"].map do |assignee|
        if (name = assignee["login"]) == Bonanza::CONFIG["gh_handle"]
          colorize(name, color: :blue)
        else
          name
        end
      end.first(2).join(", ")
    end

    def self.format_labels(pr)
      label_colors = Bonanza::CONFIG["label_colors"].to_h

      pr["labels"].sort_by do |label|
        label["name"]
      end.map do |label|
        colorize(label["name"], color: label_colors[label["name"]] || label["color"])
      end.first(3).join(", ")
    end

    def self.format_draft(pr)
      pr["isDraft"] ? colorize("Draft", color: :red) : colorize("Open", color: :green)
    end

    def self.format_updated_at(pr)
      updated_at = Time.parse(pr["updatedAt"]).localtime

      within_hour   = updated_at >= (Time.now - 3600)
      within_day    = updated_at >= (Time.now - 86_400)
      within_3_days = updated_at >= (Time.now - 259_200)

      color = if within_hour
                :green
              elsif within_day
                :yellow
              elsif within_3_days
                :orange
              else
                :red
              end

      colorize(updated_at.strftime("%a %b %d @ %k:%M"), color: color)
    end

    def self.colorize(value, color: nil)
      return value unless color

      # Default to amazing_print colors, otherwise use Paint
      # https://en.wikipedia.org/wiki/X11_color_names#Color_name_chart
      value.respond_to?(color) ? value.public_send(color) : Paint[value, color.to_s, :bright]
    end

    def self.truncate(value, length)
      if value.length > length
        "#{value.slice(0, length - 3)}..."
      else
        value
      end
    end

  end
end
