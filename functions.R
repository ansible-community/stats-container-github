# Function to get a list of repos from a GH org
get_repo_gql <- function(org, cursor = '') {
  if (cursor != '') { cursor = sprintf('after: "%s",',cursor) }

  gh::gh_gql(
    sprintf('
query {
  repositoryOwner(login: "%s") {
    repositories(%s isFork: false, first: 100, orderBy: {field: UPDATED_AT, direction: DESC}) {
      totalCount
      pageInfo {
        hasNextPage
        endCursor
      }
      nodes {
        nameWithOwner,
        url,
        issues(first: 1, orderBy:{field:UPDATED_AT, direction: DESC}) {
          nodes{
            number
            title
            updatedAt
          }
        }
        pullRequests(first: 1, orderBy:{field:UPDATED_AT, direction: DESC}) {
          nodes{
            number
            title
            updatedAt
          }
        }
      }
    }
  }
}', org, cursor))
}

# Function to call the GGQL function, paginate, and clean the response
get_repo_names <- function(org) {
  nextPage = TRUE
  repos    = tibble::tibble()
  cursor   = ''
  while (nextPage) {
    r <- get_repo_gql(org, cursor)

    nextPage <- r$data$repositoryOwner$repositories$pageInfo$hasNextPage
    cursor   <- r$data$repositoryOwner$repositories$pageInfo$endCursor

    data <- r$data$repositoryOwner$repositories$nodes
    new <- tibble::tibble(url = rlist::list.mapv(data,url),
                  issues_updated = rlist::list.map(data, dplyr::first(issues$nodes)$updatedAt),
                  prs_updated = rlist::list.map(data, dplyr::first(pullRequests$nodes)$updatedAt)
    ) |> tidyr::unnest(c(issues_updated, prs_updated), keep_empty = TRUE)

    repos <- rbind(repos, new)
  }
  return(repos)
}

# Function to parse a collection name and get the URL from Galaxy
galaxy_github_url <- function(col) {
  namespace <- stringr::str_split(col, '\\.')[[1]][1]
  name      <- stringr::str_split(col, '\\.')[[1]][2]

  req <- httr::GET(
    glue::glue('https://galaxy.ansible.com/api/pulp/api/v3/content/ansible/collection_versions/?namespace={namespace}&name={name}&limit=1')
  )

  return(httr::content(req)$results[[1]]$origin_repository)
}

# Function to parse the output of the python GH crawler
parse_gh_json <- function(dir) {
  issues <- jsonlite::read_json(stringr::str_c(dir,'/issues.json'))
  prs    <- jsonlite::read_json(stringr::str_c(dir,'/pull_requests.json'))

  org_repo = stringr::str_split_fixed(dir,'%',2)

  #browser()
  # Adjust for fields as needed
  i <- tibble::tibble(
    org  = org_repo[1],
    repo = org_repo[2],
    type = 'issue',
    number = purrr::map_int(issues, 'number'),
    author = purrr::map(issues, 'author') |> purrr::map_chr('login', .default = NA),
    authorAssociation = purrr::map_chr(issues, 'authorAssociation'),
    createdAt = purrr::map_chr(issues, 'createdAt'),
    closedAt  = purrr::map_chr(issues, 'closedAt', .default = NA),
    labels = purrr::map(issues, 'labels', .default = NA),
    commenters = purrr::map(issues, 'commenters'),
    comments = purrr::map(issues, 'comments')
  )
  p <- tibble::tibble(
    org  = org_repo[1],
    repo = org_repo[2],
    type = 'pull_request',
    number = purrr::map_int(prs, 'number'),
    author = purrr::map(prs, 'author') |> purrr::map_chr('login', .default = NA),
    authorAssociation = purrr::map_chr(prs, 'authorAssociation'),
    createdAt = purrr::map_chr(prs, 'createdAt'),
    closedAt  = purrr::map_chr(prs, 'closedAt', .default = NA),
    mergedAt = purrr::map_chr(prs, 'mergedAt', .default = NA),
    additions = purrr::map_int(prs, 'additions'),
    deletions = purrr::map_int(prs, 'deletions'),
    changedFiles = purrr::map_int(prs, 'changedFiles'),
    labels = purrr::map(prs, 'labels', .default = NA),
    #labels = purrr::map(prs, ~possibly('labels', otherwise = NA)),
    #files  = purrr::map(r, 'files', .default = NA),
    mergedBy = purrr::map(prs, 'mergedBy') |> purrr::map_chr('login', .default = NA),
    commenters = purrr::map(prs, 'commenters'),
    comments   = purrr::map(prs, 'comments')
  )
  dplyr::bind_rows(i,p) |> dplyr::arrange(number)
}
