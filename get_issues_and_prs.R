# This script reads the list of repos from the `gh_repos` pin,
# checks to see what repos have been updated recently, and then picks
# the next 100 (by date) to index

library(dplyr)
library(pins)
library(reticulate)
use_virtualenv("./github-py") # local venv or in Container

# Load supporting config & helpers
source('functions.R')
source('/srv/docker-config/github/github.token')
source_python('./crawl_issues_and_prs.py')
org_repo_cfg <- config::get(file = '/srv/docker-config/github/repos.yml')

# Set up pin boards
meta_board <- board_folder('/srv/docker-pins/github/meta')
repo_board <- board_folder('/srv/docker-pins/github/repos')

# Load the full repo list
meta_repos <- pin_read(meta_board, 'repos')

# Check the metadata on each repo pin and remove any repo which
# has been parsed this week

safe_pin_meta <- purrr::possibly(~{pin_meta(.x, .y)$created |> as.character()},
                                 otherwise = NA)
meta_repos |>
  mutate(pin_name = glue::glue("{org}|{repo}")) |>
  mutate(pin_time = purrr::map_chr(pin_name, ~safe_pin_meta(repo_board, .x))) |>
  arrange(pin_time) |>
  filter((pin_time < Sys.time() - 60*60*24*7) | is.na(pin_time)) |>
  head(org_repo_cfg$repos_to_index) -> index_list

# Remove any pins that are no longer on the list
pin_list(repo_board) |>
  tibble::enframe(name = NULL, value = "pin_name") |>
  anti_join( meta_repos |> mutate(pin_name = glue::glue("{org}|{repo}")),
             by = "pin_name") |>
  pull(pin_name) |>
  pin_delete(board = repo_board)

# Function to actually do the work
pin_issues_prs_comments <- function(git_org, git_repo, get_all = TRUE) {
  # Setup temporary work path
  work_dir <- fs::path_temp('gh_indexer', git_org, git_repo)
  fs::dir_create(work_dir)
  setwd(work_dir)

  # Run the python scraper in the work path
  main(git_org,git_repo,get_all)

  # There should be one dir in the work area
  gh_dir <- glue::glue('{git_org}%{git_repo}')
  if (fs::dir_exists(gh_dir)) {
    r <- parse_gh_json(gh_dir)
    if (nrow(r) > 0) {
      pins::pin_write(board = repo_board, x = r,
                      name = glue::glue('{git_org}|{git_repo}'))
    }
  }

  # Delete temp work path
  fs::dir_delete(work_dir)
}

# Run the function over the short-list
purrr::walk2(index_list$org, index_list$repo, pin_issues_prs_comments)
