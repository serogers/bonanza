# frozen_string_literal: true

require_relative "../test_helper"

class FormatterTest < Minitest::Test

  # --- get_review_status ----------------------------------------------------

  def test_get_review_status_returns_empty_for_drafts
    pr = { "isDraft" => true, "reviewDecision" => "REVIEW_REQUIRED" }
    assert_equal "", Bonanza::Formatter.get_review_status(pr)
  end

  def test_get_review_status_treats_empty_review_decision_as_required
    pr = { "isDraft" => false, "reviewDecision" => "" }
    assert_equal "REQUIRED", Bonanza::Formatter.get_review_status(pr)
  end

  def test_get_review_status_treats_nil_review_decision_as_required
    pr = { "isDraft" => false, "reviewDecision" => nil }
    assert_equal "REQUIRED", Bonanza::Formatter.get_review_status(pr)
  end

  def test_get_review_status_maps_review_required_to_required
    pr = { "isDraft" => false, "reviewDecision" => "REVIEW_REQUIRED" }
    assert_equal "REQUIRED", Bonanza::Formatter.get_review_status(pr)
  end

  def test_get_review_status_maps_changes_requested_to_rejected
    pr = { "isDraft" => false, "reviewDecision" => "CHANGES_REQUESTED" }
    assert_equal "REJECTED", Bonanza::Formatter.get_review_status(pr)
  end

  def test_get_review_status_passes_through_approved
    pr = { "isDraft" => false, "reviewDecision" => "APPROVED" }
    assert_equal "APPROVED", Bonanza::Formatter.get_review_status(pr)
  end

  # --- get_my_review_status -------------------------------------------------

  def test_get_my_review_status_returns_empty_with_no_reviews
    assert_equal "", Bonanza::Formatter.get_my_review_status(pr_fixture(101))
  end

  def test_get_my_review_status_returns_state_when_user_has_reviewed
    assert_equal "COMMENTED", Bonanza::Formatter.get_my_review_status(pr_fixture(102))
    assert_equal "APPROVED",  Bonanza::Formatter.get_my_review_status(pr_fixture(106))
  end

  def test_get_my_review_status_ignores_reviews_from_other_users
    assert_equal "", Bonanza::Formatter.get_my_review_status(pr_fixture(103))
  end

  def test_get_my_review_status_is_required_when_my_team_is_a_pending_reviewer
    Bonanza.my_teams = Set.new(["the-met/team-monet"])
    assert_equal "REQUIRED", Bonanza::Formatter.get_my_review_status(pr_fixture(107))
  end

  def test_get_my_review_status_is_empty_when_i_am_the_author_even_if_my_team_is_pending
    Bonanza.my_teams = Set.new(["the-met/team-monet"])
    pr = pr_fixture(107).merge("author" => { "login" => "current_user" })
    assert_equal "", Bonanza::Formatter.get_my_review_status(pr)
  end

  def test_get_my_review_status_is_empty_when_only_other_teams_are_pending_reviewers
    Bonanza.my_teams = Set.new(["the-met/team-monet"])
    assert_equal "", Bonanza::Formatter.get_my_review_status(pr_fixture(108))
  end

  def test_get_my_review_status_scopes_team_match_to_pr_org
    # team slug matches but org does not — should not count as my team blocking
    Bonanza.my_teams = Set.new(["other-org/team-monet"])
    assert_equal "", Bonanza::Formatter.get_my_review_status(pr_fixture(107))
  end

  def test_get_my_review_status_personal_review_takes_precedence_over_team_request
    Bonanza.my_teams = Set.new(["the-met/team-monet"])
    # PR 106: I've already approved personally; team logic shouldn't override that.
    assert_equal "APPROVED", Bonanza::Formatter.get_my_review_status(pr_fixture(106))
  end

  # --- format_review --------------------------------------------------------

  def test_format_review_omits_counts_when_no_completed_or_pending_reviews
    # PR 105 has empty latestReviews and no reviewRequests.
    assert_equal "REQUIRED", Bonanza::Formatter.format_review(pr_fixture(105))
  end

  def test_format_review_omits_counts_on_drafts
    # Status is "" for drafts; we don't decorate with counts.
    assert_equal "", Bonanza::Formatter.format_review(pr_fixture(101))
  end

  def test_format_review_appends_counts_for_pending_team_review
    # PR 107: 0 completed, 1 pending (team).
    assert_equal "REQUIRED (0/1)", Bonanza::Formatter.format_review(pr_fixture(107))
  end

  def test_format_review_appends_counts_for_pending_user_and_team_review
    # PR 108: 0 completed, 2 pending (team + user).
    assert_equal "REQUIRED (0/2)", Bonanza::Formatter.format_review(pr_fixture(108))
  end

  def test_format_review_counts_approved_reviews_as_completed
    # PR 103: 2 APPROVED reviews, no pending requests.
    assert_equal "APPROVED (2/2)", Bonanza::Formatter.format_review(pr_fixture(103))
  end

  def test_format_review_counts_changes_requested_as_completed
    # PR 104: 1 CHANGES_REQUESTED review, no pending requests.
    assert_equal "REJECTED (1/1)", Bonanza::Formatter.format_review(pr_fixture(104))
  end

  def test_format_review_does_not_count_commented_reviews_as_completed
    # PR 102: 1 COMMENTED review, no pending requests — nothing to display.
    assert_equal "REQUIRED", Bonanza::Formatter.format_review(pr_fixture(102))
  end

  # --- format_priority ------------------------------------------------------

  def test_format_priority_uses_review_required_when_not_yet_approved
    assert_equal 0, Bonanza::Formatter.format_priority(pr_fixture(102))
    assert_equal 0, Bonanza::Formatter.format_priority(pr_fixture(105))
  end

  def test_format_priority_uses_rejected_for_changes_requested
    assert_equal 1, Bonanza::Formatter.format_priority(pr_fixture(104))
  end

  def test_format_priority_uses_approved_when_pr_is_approved
    assert_equal 2, Bonanza::Formatter.format_priority(pr_fixture(103))
  end

  def test_format_priority_prefers_my_approval_over_required
    # PR 106: overall REVIEW_REQUIRED, but current_user has approved.
    assert_equal 2, Bonanza::Formatter.format_priority(pr_fixture(106))
  end

  def test_format_priority_places_drafts_last
    assert_equal 3, Bonanza::Formatter.format_priority(pr_fixture(101))
  end

  # --- format_done ----------------------------------------------------------

  def test_format_done_marks_drafts_as_done
    assert_equal " 🟢", Bonanza::Formatter.format_done(pr_fixture(101))
  end

  def test_format_done_marks_approved_prs_as_done
    assert_equal " 🟢", Bonanza::Formatter.format_done(pr_fixture(103))
  end

  def test_format_done_marks_rejected_prs_as_done
    assert_equal " 🟢", Bonanza::Formatter.format_done(pr_fixture(104))
  end

  def test_format_done_marks_pr_as_done_when_i_have_approved
    assert_equal " 🟢", Bonanza::Formatter.format_done(pr_fixture(106))
  end

  def test_format_done_marks_required_review_as_not_done
    assert_equal " ⭕️", Bonanza::Formatter.format_done(pr_fixture(102))
    assert_equal " ⭕️", Bonanza::Formatter.format_done(pr_fixture(105))
  end

  # --- format_title ---------------------------------------------------------

  def test_format_title_prefixes_pr_number
    formatted = Bonanza::Formatter.format_title(pr_fixture(101))
    assert_includes formatted, "PR 101: Add Starry Night background to login flow"
  end

  def test_format_title_truncates_long_titles
    formatted = Bonanza::Formatter.format_title(pr_fixture(103))
    title_part = formatted.sub(/^PR 103: /, "")
    assert_equal 55, title_part.length
    assert title_part.end_with?("..."), "expected truncated title to end with '...' (got #{title_part.inspect})"
  end

  # --- format_author --------------------------------------------------------

  def test_format_author_returns_author_login
    assert_equal "munch", Bonanza::Formatter.format_author(pr_fixture(102))
  end

  # --- format_assignees -----------------------------------------------------

  def test_format_assignees_returns_empty_string_when_none
    assert_equal "", Bonanza::Formatter.format_assignees(pr_fixture(101))
  end

  def test_format_assignees_limits_to_two
    assert_equal "current_user, davinci", Bonanza::Formatter.format_assignees(pr_fixture(102))
  end

  # --- format_labels --------------------------------------------------------

  def test_format_labels_returns_empty_string_when_none
    assert_equal "", Bonanza::Formatter.format_labels(pr_fixture(104))
  end

  def test_format_labels_sorts_and_limits_to_three
    # Labels are sorted alphabetically and capped at 3 (tech-debt drops off).
    assert_equal "backend, critical, should-be-truncated",
                 Bonanza::Formatter.format_labels(pr_fixture(103))
  end

  # --- format_draft ---------------------------------------------------------

  def test_format_draft_distinguishes_draft_from_open
    assert_equal "Draft", Bonanza::Formatter.format_draft(pr_fixture(101))
    assert_equal "Open",  Bonanza::Formatter.format_draft(pr_fixture(102))
  end

  # --- format_updated_at ----------------------------------------------------

  def test_format_updated_at_renders_localized_time_string
    pr = { "updatedAt" => "2026-05-11T22:00:00Z" }
    expected = Time.parse(pr["updatedAt"]).localtime.strftime("%a %b %d @ %k:%M")
    assert_equal expected, Bonanza::Formatter.format_updated_at(pr)
  end

  # --- format (integration-style) -------------------------------------------

  def test_format_assigns_all_expected_keys_and_preserves_others
    pr = pr_fixture(102)
    formatted = Bonanza::Formatter.format(pr)

    # Adds computed columns
    assert_equal 0, formatted["priority"]
    %w[done myReview reviewDecision title author assignees labels isDraft updatedAt].each do |key|
      assert formatted.key?(key), "expected formatted PR to have #{key}"
    end

    # Original keys still present
    assert_equal 102, formatted["number"]
    assert_equal "https://github.com/example/repo/pull/102", formatted["url"]
  end

end
