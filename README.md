# git-mr

Prepares a merge request description, with link to Jira ticket and current branch commit list.

## Usage

```bash
git mr [issue_code] [base_branch]
```

This will print a merge request description, with a link to Jira ticket and current branch commit list.
* `issue_code` can be guessed from the branch name according to `JIRA_CODE_PATTERN` 
* `base_branch` is determined by going up the commit history and finding the first one attached to a branch 

If a merge request based on the current branch is found on Gitlab, its URL will be provided, along with current votes, open and resolved threads and mergeable status.

Otherwise, a link to create a new merge request will be provided. Default labels and "Delete source branch" status 
can be configured with the `GITLAB_DEFAULT_LABELS` and `GITLAB_DEFAULT_FORCE_REMOVE_SOURCE_BRANCH` environment variables.

----------------------------------------------------------------

```bash
git mr update [base_branch]
```

This will:
* fetch and display the current merge request description from Gitlab.
* compare the commit lists and update the SHA-1 references in the description

If some commits were changed (after a rebase) or added, you will be prompted if you want to post the updated description to Gitlab.

You can also update the source branche if it is different from the current one.  

----------------------------------------------------------------

```bash
git mr unwip
```

This will resolve the _Work in Progress_ status.

----------------------------------------------------------------

```bash
git mr merge
```

This will:
* check merge status
* check open threads
* check WiP status

and if applicable, will prompt you to:
* resolve WIP status
* trigger the merge
* checkout local target branch, update it and delete local merged branch


## Installation

* Add the `git-mr` directory to your `PATH`<br>
  in one of your shell startup scripts:
  ```bash
  PATH="${PATH}:/path/to/git-mr"
  ```

_OR_ 

* Define it as a git alias:<br>
  run:
  ```bash
  git config --global alias.mr '!bash /path/to/git-mr/git-mr'
  ```
  or edit your `~/.gitconfig` directly:
  ```
  [alias]
  	mr = "!bash /path/to/git-mr/git-mr"
  ```

## Configuration

You need to configure the following environment variables:
```bash
export JIRA_USER="user.name@mycompany.com"
export JIRA_INSTANCE="mycompany.atlassian.net"
export JIRA_TOKEN="abcdefghijklmnopqrstuvwx"
export JIRA_CODE_PATTERN="XY-[0-9]+"

export GITLAB_DOMAIN="myapp.gitlab.com"
export GITLAB_TOKEN="Zyxwvutsrqponmlkjihg"

export GITLAB_DEFAULT_LABELS="Review,My Team"      # Default labels for new merge requests
export GITLAB_DEFAULT_FORCE_REMOVE_SOURCE_BRANCH=1 # Check "Delete source branch" by default
```

To create a Jira API Token, go to:
* https://id.atlassian.com/manage-profile/security/api-tokens<br>
  (Account Settings -> Security -> API Token -> Create and manage API tokens)
  
To create a Gitlab API Token, go to:
* https://myapp.gitlab.com/profile/personal_access_tokens<br>
  (Settings -> Access Tokens)

## Sample output

```bash
git mr
```
```
--------------------------------------------------------------------------------

# [XY-1234 Sample git mr output](https://mycompany.atlassian.net/browse/XY-1234)


## Commits

* **f485f6e Init**<br>
* **f09ea0d readme**<br>
* **0545488 Base branch determination improvement**<br>
* **8d39347 Guess issue code from branch**<br>
* **6e381cd Jira error case**<br>

--------------------------------------------------------------------------------

To create a new merge request:

    https://myapp.gitlab.com/my/project/merge_requests/new?merge_request%5Bsource_branch%5D=feature/whatever&merge_request%5Btarget_branch%5D=develop

```
