# git-mr

Prepares a merge request description, with link to Jira ticket and current branch commit list.

## Usage

```bash
mr.sh issue_code [base_branch]
```

or

```bash
git mr issue_code [base_branch]
```

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
```

To create a Jira API Token, go to:
* https://id.atlassian.com/manage-profile/security/api-tokens<br>
  (Account Settings -> Security -> API Token -> Create and manage API tokens)
