library(reticulate)
use_virtualenv("./github-py") # local venv or in Container

# Load supporting config & helpers
source('functions.R')
source('/srv/docker-config/github/github.token')
source_python('./crawl_issues_and_prs.py')
board <- pins::board_folder('/srv/docker-pins/github')

# Use purrr::safely to work around API limits/issues
get_issues_prs <- function(org, repo) {
  git_org = org
  git_repo = repo
  get_all = TRUE

  main(git_org,git_repo,get_all)
  return("done")
}
safe_get <- purrr::possibly(get_issues_prs, otherwise = NA)

results_dir <- tempdir()
setwd(results_dir)
pins::pin_read(board, 'gh_repos') |>
  dplyr::mutate(results = purrr::map2_chr(org, repo, safe_get))

dir_list <- dir(path = '.', pattern='%', full.names = T)
r <- tibble::tibble() ; i = 0
for (dir in dir_list) {
  i = i + 1
  print(paste0(i,"/",length(dir_list),': ',dir))
  r <- dplyr::bind_rows(
    r,
    parse_gh_json(dir)
  )
}

r |>
  dplyr::mutate(org = stringr::str_remove(org,'./')) |>
  pins::pin_write(board = board, "issues_prs_comments")
