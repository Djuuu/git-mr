# git-mr

Prepares a merge request description, with link to Jira ticket and current branch commit list.

## Usage

```bash
mr.sh [issue_code] [base_branch]
```

or

```bash
git mr [issue_code] [base_branch]
```


When `JIRA_CODE_PATTERN` is set in the environment, Jira issue code can be guessed from the git branch name:
```bash
JIRA_CODE_PATTERN="XY-[0-9]+"
```
`feature/xy-1234-my-feature-branch` -> `XY-1234`

When not provided, base branch is guessed from commit history (first commit in current branch history also having a branch).

## Installation

### As a standalone script:

```bash
alias mr=/path/to/mr.sh
```

### As a git alias:

Define this alias in your .gitconfig:
```
[alias]
	mr = "!bash /path/to/mr.sh"
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
