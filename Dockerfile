FROM rocker/tidyverse:latest

# Python backend to call from R
RUN install2.r reticulate && rm -rf /tmp/downloaded_packages
RUN R -e "reticulate::install_python()"
RUN R -e "reticulate::virtualenv_create('/opt/github/github-py')"
RUN R -e "reticulate::use_virtualenv('/opt/github/github-py') ; reticulate::py_install('requests')"

RUN install2.r config emayili pins remotes gh rlist xml2 \
    && rm -rf /tmp/downloaded_packages

RUN mkdir -p /opt/github
WORKDIR /opt/github
COPY ./functions.R .
COPY ./crawl_issues_and_prs.py .
COPY ./get_repos.R .
COPY ./get_issues_and_prs.R .

CMD ["R"]
