# Load supporting config & helpers
source('functions.R')
source('/srv/docker-config/github/github.token')
org_repo_cfg <- config::get(file = '/srv/docker-config/github/repos.yml')
board <- pins::board_folder('/srv/docker-pins/github')

org_repos <-
  tibble::enframe(org_repo_cfg$orgs,name=NULL,value='org') |>
  dplyr::mutate(repos = purrr::map(org, get_repo_names) ) |>
  tidyr::unnest(repos)

collections <-
  tibble::enframe(org_repo_cfg$collections,name=NULL,value='collection') |>
  dplyr::mutate(repo = purrr::map_chr(collection, galaxy_github_url))

repos <- tibble::enframe(c(org_repos$url, collections$repo), name=NULL) |>
  dplyr::distinct() |>
  dplyr::mutate(org  = purrr::map(value, stringr::str_split_fixed, "/", 5) |>
                  purrr::map_chr(~{.x[4]}),
                repo = purrr::map(value, stringr::str_split_fixed, "/", 5) |>
                  purrr::map_chr(~{.x[5]})
  ) |>
  dplyr::select(org, repo)

pins::pin_write(board, repos, name = "gh_repos")
