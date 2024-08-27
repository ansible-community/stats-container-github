## Docker Container for GitHub Reports

This container handles the gathering of Ansible GitHub data, and saves it to a pin in the mounted pins folder

## Setup

This container requires two mount points:
- a config dir mounted to `/srv/docker-config/github` for the tokens, lists, and email config
- a `pins` dir mounted to `/srv/docker-pins/github` for storing/reading data

### Example dir layout

Inside the container it should look like this:
```
/srv/docker-config
└── github
    ├── email.yml
    ├── github.token
    └── repos.yml
/srv/docker-pins
└── github
```

### GitHub token file

This file will be sourced as a Sys.env file and should be in the format as seen in the example file - just replace the placeholder with your token. It needs `public_repo, read:org` as a scope.

### Repo config file

See the example - it's a list of orgs, repos, and collections (dereferenced through Galaxy) of interest.

### Email config file (not used yet)

I'm assuming a Gmail account in the code, just provide a file that looks like the example in this repo.

## Build the container

```
podman build --tag github-pins .
```

## Run the container

All the tasks are designed for a single execution

### Example single run of get_github_repos.R

This builds a `pin` of the repos of interest *only* - as such it runs quite quickly.

```
podman run --rm -ti \
  -v /srv/docker-config/github/:/srv/docker-config/github \
  -v /srv/docker-pins/github:/srv/docker-pins/github \
  github:latest Rscript get_repos.R
```

### Example single run of get_github_data.R

This builds a `pin` of the issues, PRs, and associated comments in the repo list. With a single GH token it can take over 17 hours, so for testing use a smaller repos `pin`.

```
podman run --rm -ti \
  -v /srv/docker-config/github/:/srv/docker-config/github \
  -v /srv/docker-pins/github:/srv/docker-pins/github \
  github:latest Rscript get_issues_and_prs.R
```

### Interactive testing

You can run an R shell in the container - this is the container default:

```
podman run --rm -ti \
  -v /srv/docker-config/github/:/srv/docker-config/github \
  -v /srv/docker-pins/github:/srv/docker-pins/github \
  github:latest 
```
