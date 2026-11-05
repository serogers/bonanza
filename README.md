# Bonanza - A Fancy Pull Request Dashboard 🎊

Get productive with Github's pull request list! Github has [some handy search filters](https://docs.github.com/en/issues/tracking-your-work-with-issues/filtering-and-searching-issues-and-pull-requests) for their Pull Request list, but sometimes you need more flexibility. For example, Github's search does not allow for `OR` operations, only `AND`. If you want to see several searches in one dashboard, you've come to the right place!

![Bonanza Example](example.jpg)

## Installation

1. Install the [Github CLI](https://cli.github.com) and login to your account
2. Clone this prepository to somwhere comfy
3. Install script dependencies: `bundle install`
4. Create a `.bonanza.yml` file in each repo you want to render a dashboard (see format below)
5. Add `.bonanza.yml` to your `gitignore_global` file, or to each repo
6. Add the bonanza executable to your shell path: `PATH=$PATH:PATH_TO_REPO/bonanza/bin/bonanza`

## Configuration

```yml
# Place in project directory: .bonanza.yml

gh_handle: [Your GH Handle]

# GitHub search syntax, scoped to open PRs in this repo (two included by default, see FAQ)
searches:
  - label:critical
  - label:general
  - review:required

search_limit: 20 # default

# Optionally colorize authors
author_colors:
  [GH Handle]: green
  [GH Handle]: blue
  [GH Handle]: "#e6e1dc"

# Optionally override label colors
label_colors:
  critical: red
  stale: gray
```

### Search syntax

Each entry in `searches` uses [GitHub search syntax](https://docs.github.com/en/search-github/searching-on-github/searching-issues-and-pull-requests), the same as the search bar on a repo's pull request list. Bonanza adds `repo:<owner/name> is:pr is:open` to each one, plus `sort:updated-desc` unless the search includes its own `sort:`.

Older versions of Bonanza used `gh pr list` flags. Bonanza will stop with an error if a search starts with `--`. To convert:

| `gh pr list` flag | Search syntax |
|---|---|
| `--label team-claw` | `label:team-claw` |
| `--label "needs review"` | `label:"needs review"` |
| `--label critical --label general` | `label:critical label:general` |
| `--author octocat` | `author:octocat` |
| `--assignee octocat` | `assignee:octocat` |
| `--base main` | `base:main` |
| `--draft` | `draft:true` |
| `--search review:required` | `review:required` |

Search syntax also supports filters the flags don't, such as `-label:wip`, `review-requested:@me`, `team-review-requested:org/team` and `updated:>2026-10-01`.

## Running Bonanza

Change to your project's directory, and run `bonanza` (or the alias you chose) to see the dashboard.

## Testing

The test suite uses [minitest](https://github.com/minitest/minitest) and lives in `test/`.

```sh
bundle install
bundle exec rake test
```

Layout:
- `test/test_helper.rb` — boots a minimal `Bonanza` module
- `test/fixtures/` — fixtures used by tests
- `test/bonanza/` — mirrors `lib/bonanza/`, one `*_test.rb` per class

By default each test boots `Bonanza.config` from the fixture `.bonanza.yml`. To override values for a single test, wrap the assertion in `with_config`:

```ruby
with_config("author_colors" => { "monalisa" => :red }) do
  # Bonanza.config.author_colors is { "monalisa" => :red } in here
end
```

`test/fixtures/pr_list.json` holds PRs as returned by `Bonanza::Github.search_prs` (connections flattened). `test/fixtures/search_prs.json` holds a raw GraphQL response. To capture a fresh raw response from a real repo:

```sh
cd /path/to/repo
gh api graphql \
  -f query="$(cd /path/to/bonanza && ruby -r ./lib/bonanza -e "print Bonanza::Github::SEARCH_QUERY")" \
  -f search="repo:$(gh repo view --json nameWithOwner --jq .nameWithOwner) is:pr is:open" \
  -F limit=5 \
  > /path/to/bonanza/test/fixtures/<name>.json
```

## FAQ

**What are the different dashboard sections?**

Each "search" generates a new section. Currently there are two default searches that show first:
- Pull requests authored by you
- Pull involving you (as defined by Github - assigned, commented, etc.)

**What is the "Done" column?**

This is used to signify whether a pull request needs your attention. For example, once you've reviewed a pull request, it's "Done".

**What do the colors in "Last Updated" mean?**

- Within the hour: Green
- Within a day:    Yellow
- Within 3 days:   Orange
- Anything older:  Red

**Is this production ready?**

This utility was created to fulfill a personal need. As such, the implementation and tests cover my use cases. However it should be safe to use (though at your own risk).

**I've got an idea, how to contribute?**

Open a pull request or issue! Or fork and go crazy.
