# git-mr

[![Tests](https://github.com/Djuuu/git-mr/actions/workflows/tests.yml/badge.svg)](https://github.com/Djuuu/git-mr/actions/workflows/tests.yml)
[![License](https://img.shields.io/badge/license-Beerware%20%F0%9F%8D%BA-yellow)](https://web.archive.org/web/20160322002352/http://www.cs.trincoll.edu/hfoss/wiki/Chris_Fei:_Beerware_License)

Prepares a merge request description, with link to Jira ticket and current branch commit list.

----------------------------------------------------------------

* [Synopsis](#synopsis)
* [Installation](#installation)
    + [Command installation](#command-installation)
    + [Configuration](#configuration)
* [Commands](#commands)
    + [`git mr`](#git-mr-2)
    + [`git mr open`](#git-mr-open)
    + [`git mr status`](#git-mr-status)
    + [`git mr update`](#git-mr-update)
    + [`git mr menu`](#git-mr-menu)
    + [`git mr ip|cr|qa|accept`](#git-mr-ipcrqaaccept)
    + [`git mr undraft`](#git-mr-undraft)
    + [`git mr merge`](#git-mr-merge)
    + [`git mr hook`](#git-mr-hook)
* [Plumbing commands](#plumbing-commands)
  + [`git mr base`](#git-mr-base)
  + [`git mr code`](#git-mr-code)
* [Hooks](#hooks)
  + [`prepare-commit-msg`](#prepare-commit-msg)

----------------------------------------------------------------

## Synopsis

<pre>
<b>git mr</b>  <i>[OPTIONS]</i>          <i>[BRANCH]</i>
<b>git mr</b>  <i>[OPTIONS]</i>  <b>open</b>    <i>[BRANCH]</i>
<b>git mr</b>  <i>[OPTIONS]</i>  <b>status</b>  <i>[BRANCH]</i>
<b>git mr</b>  <i>[OPTIONS]</i>  <b>update</b>  <i>[BRANCH]</i>
<b>git mr</b>  <i>[OPTIONS]</i>  <b>merge</b>   <i>[BRANCH]</i>

<b>git mr</b>  <i>[OPTIONS]</i>  <b>menu</b>                 <i>[SEARCH_TERM]</i>
<b>git mr</b>  <i>[OPTIONS]</i>  <b>menu</b> <i>update [--all]</i>  <i>[SEARCH_TERM]</i>
<b>git mr</b>  <i>[OPTIONS]</i>  <b>menu</b> <i>status</i>          <i>[SEARCH_TERM]</i>

<b>git mr</b>  <i>[OPTIONS]</i>  <b>(ip|cr|qa|accept)</b>  <i>[BRANCH]</i>
<b>git mr</b>  <i>[OPTIONS]</i>  <b>undraft</b>     <i>[BRANCH]</i>

<b>git mr</b> <b>hook</b>

<b>git mr</b> <b>base</b>
<b>git mr</b> <b>code</b>
</pre>

### Arguments

* `BRANCH`  
  Force merge request source branch.  
  Defaults to current branch.
* `SEARCH_TERM`  
  Term searched in merge requests titles to build menu.  
  Defaults to Jira issue code guessed from branch name.

### Options

* `-c`, `--code` `ISSUE_CODE`  
  Force issue code.
* `-t`, `--target` `TARGET_BRANCH`  
  Force target branch.
* `-e`, `--extended`  
  Use full commit messages in description ("extended", for `git mr [open|update]`).  
  You can also set `GIT_MR_EXTENDED=1` in your environment variables to always use extended commit descriptions.
* `-y`, `--yes`  
  Bypass confirmation prompts (always answer "yes").
* `-n`, `--new-section`  
  Add new section in description for new commits (for `git mr update`)
* `-f`, `--force`  
  Force merge even if there are unresolved threads (for `git mr merge`)
* `-a`, `--all`  
  Update all merge requests (for `git mr menu update`).
* `-v`, `--verbose`  
  Verbose output (displays called API URLs).
* `-h`  
  Show help page.


## Installation

### Command installation

#### Dependencies

* `bash`, `git` and usual command-line utilities: `grep`, `sed`, `curl`, `head`, `tail`, `tr`.
* [**`jq`**](https://stedolan.github.io/jq/) is required and needs to be in PATH.

**Note for macOS users:**  
> macOS usually comes with a pretty outdated version of Bash (3.x) and the BSD versions of `grep` and `sed`.  
> You will need to install a more recent versions of bash (>=4.x) and the GNU versions of `sed` and `grep`.  
> These are available on Homebrew:
> ```shell
> brew install bash gnu-sed grep
> ```
> git-mr detects these versions, so no additional path adjustments should be necessary.

#### git-mr

* Add the `git-mr` directory to your `PATH`<br>
  in one of your shell startup scripts:
  ```bash
  PATH="${PATH}:/path/to/git-mr"
  ```

_OR_ 

* Define it as a Git alias:<br>
  run:
  ```bash
  git config --global alias.mr '!bash /path/to/git-mr/git-mr'
  ```
  or edit your `~/.gitconfig` directly:
  ```
  [alias]
  	mr = "!bash /path/to/git-mr/git-mr"
  ```

#### Completion

Completion is available in `git-mr-completion.bash`. Source it in one of your shell startup scripts:
```bash
. "/path/to/git-mr/git-mr-completion.bash"
```


### Configuration

You need to configure the following environment variables:
```bash
export JIRA_USER="user.name@mycompany.com"
export JIRA_INSTANCE="mycompany.atlassian.net"
export JIRA_TOKEN="abcdefghijklmnopqrstuvwx"
export JIRA_CODE_PATTERN="[A-Z]{2,3}-[0-9]+"

export GITLAB_DOMAIN="myapp.gitlab.com"
export GITLAB_TOKEN="Zyxwvutsrqponmlkjihg"
```

To create a Jira API Token, go to:
* https://id.atlassian.com/manage-profile/security/api-tokens  
  (Account Settings -> Security -> API Token -> Create and manage API tokens)

To create a Gitlab API Token, go to:
* https://myapp.gitlab.com/-/profile/personal_access_tokens?name=Git-MR+Access+token&scopes=api  
  (Settings -> Access Tokens)

Other optional configuration variables:
```bash
# Default labels for new merge requests
export GITLAB_DEFAULT_LABELS="Review,My Team"

# Gitlab status labels (comma-separated, without spaces in between)
export GITLAB_IP_LABELS="WIP"      # Label(s) set on IP step
export GITLAB_CR_LABELS="Review"   # Label(s) set on CR step
export GITLAB_QA_LABELS="Testing"  # Label(s) set on QA step
export GITLAB_OK_LABELS="Accepted" # Label(s) set on Accepted step

# Jira status - transition IDs
export JIRA_IP_ID="xx" # "In progress" transition ID
export JIRA_CR_ID="xx" # "Code review" transition ID
export JIRA_QA_ID="xx" # "Quality Assurance" transition ID
export JIRA_OK_ID="xx" # "Accepted" transition ID

# Check "Delete source branch" by default (defaults to 1)
export GITLAB_DEFAULT_FORCE_REMOVE_SOURCE_BRANCH=1

# Network timeout (in seconds, defaults to 5)
export GIT_MR_TIMEOUT=5
```


## Commands

### `git mr`

<pre>
<b>git mr</b> <i>[OPTION...]</i> <i>[BRANCH]</i>
</pre>

This will print a merge request description, with a link to Jira ticket and current branch commit list.

* Issue code can be guessed from the branch name according to `JIRA_CODE_PATTERN`.  
  It can also be forced with the `-c|--code` option.
* Target branch is determined by going up the commit history and finding the first one attached to another local branch.  
  It can also be forced with the `-t|--target` option.

If a merge request based on the current branch is found on Gitlab, its URL will be provided, along with current votes, open and resolved threads and mergeable status.

Otherwise, a link to create a new merge request will be provided. Default labels and "Delete source branch" status 
can be configured with the `GITLAB_DEFAULT_LABELS` and `GITLAB_DEFAULT_FORCE_REMOVE_SOURCE_BRANCH` environment variables.

![git mr](doc/git-mr.png)

![git mr -e](doc/git-mr-e.png)

----------------------------------------------------------------

### `git mr open`

<pre>
<b>git mr</b> <i>[OPTION...]</i> <b>o|op|open</b> <i>[BRANCH]</i>
</pre>

Similar to `git mr`, but will open browser directly.

----------------------------------------------------------------

### `git mr status`

<pre>
<b>git mr</b> <i>[OPTION...]</i> <b>s|st|status</b> <i>[BRANCH]</i>
</pre>

Displays a quick summary of the merge request, with useful indicators (tags, target branch, votes, open threads, draft status, ...)

![git mr status](doc/git-mr-status.png)

----------------------------------------------------------------

### `git mr update`

<pre>
<b>git mr</b> <i>[OPTION...]</i> <b>u|up|update</b> <i>[BRANCH]</i>
</pre>

This will:
* fetch and display the current merge request description from Gitlab.
* compare the commit lists and update the SHA-1 references in the description

If some commits were changed (after a rebase) or added, you will be prompted if you want to post the updated description to Gitlab.

You can also update the source branch if it is different from the current one.

![git mr update](doc/git-mr-update.png)

----------------------------------------------------------------

### `git mr menu`

<pre>
<b>git mr</b> <i>[OPTION...]</i> <b>menu</b>                   <i>[SEARCH_TERM]</i> 
<b>git mr</b> <i>[OPTION...]</i> <b>menu</b> <i>up|update [--all]</i> <i>[SEARCH_TERM]</i> 
<b>git mr</b> <i>[OPTION...]</i> <b>menu</b> <i>st|status</i>         <i>[SEARCH_TERM]</i> 
</pre>

Searches for all (non-closed) merge requests with the current issue code in the title, and generates a menu.

* `git mr menu`<br>
  Prints the markdown menu

* `git mr menu up|update`<br>
  Updates the menu in the current merge request description (prompts for confirmation)
* `git mr menu up|update -a|--all`<br>
  Updates the menu in all related merge requests (prompts for confirmation)

* `git mr menu st|status`<br>
  Prints the menu and status indicators for every related merge request

![git mr menu](doc/git-mr-menu.png)

![git mr menu-status](doc/git-mr-menu-status.png)

----------------------------------------------------------------

### `git mr ip|cr|qa|accept`

<pre>
<b>git mr</b> <i>[OPTION...]</i> <b>ip|cr|qa|accept</b> <i>[BRANCH]</i>
</pre>

This will:
* Set Gitlab labels according to:
  - `GITLAB_IP_LABELS`
  - `GITLAB_CR_LABELS`
  - `GITLAB_QA_LABELS`
  - `GITLAB_OK_LABELS`
* transition Jira ticket using ID defined in:
  - `JIRA_IP_ID`
  - `JIRA_CR_ID`
  - `JIRA_QA_ID`
  - `JIRA_OK_ID`

#### `git mr ip` _("in progress")_
* removes Gitlab labels defined in `GITLAB_CR_LABELS`, `GITLAB_QA_LABELS` and `GITLAB_OK_LABELS`
* adds Gitlab labels defined in `GITLAB_IP_LABELS`
* transitions Jira ticket using `JIRA_IP_ID`

#### `git mr cr` _("code review")_
* removes Gitlab labels defined in `GITLAB_IP_LABELS`, `GITLAB_QA_LABELS`, and `GITLAB_OK_LABELS`
* adds Gitlab labels defined in `GITLAB_CR_LABELS`
* transitions Jira ticket using `JIRA_CR_ID`

#### `git mr qa` _("quality assurance")_
* removes Gitlab labels defined in `GITLAB_IP_LABELS`, `GITLAB_CR_LABELS`, and `GITLAB_OK_LABELS`
* adds Gitlab labels defined in `GITLAB_QA_LABELS`
* transitions Jira ticket using `JIRA_QA_ID`

#### `git mr accept` _("accepted")_
* removes Gitlab labels defined in `GITLAB_IP_LABELS`, `GITLAB_CR_LABELS`, and `GITLAB_QA_LABELS`
* adds Gitlab labels defined in `GITLAB_OK_LABELS`
* removes Gitlab draft status
* transitions Jira ticket using `JIRA_OK_ID`

----------------------------------------------------------------

### `git mr undraft`

<pre>
<b>git mr</b> <i>[OPTION...]</i> <b>undraft</b> <i>[BRANCH]</i>
</pre>

This will resolve the Gitlab _Draft_ (_Work in Progress_) status.

----------------------------------------------------------------

### `git mr merge`

<pre>
<b>git mr</b> <i>[OPTION...]</i> <b>m|mg|merge</b> <i>[BRANCH]</i>
</pre>

This will:
* check merge status
* check open threads
* check draft status

and if applicable, will prompt you to:
* resolve draft status
* trigger the merge
* checkout local target branch, update it and delete local merged branch

![git mr merge](doc/git-mr-merge.png)

----------------------------------------------------------------

### `git mr hook`

<pre>
<b>git mr</b> <b>hook</b>
</pre>

Adds the `prepare-commit-msg` Git hook to your current repository.

----------------------------------------------------------------

## Plumbing commands

These "plumbing" commands can be useful in other scripts or git aliases.

### `git mr base`

Outputs guessed base branch.

----------------------------------------------------------------

### `git mr code`

Outputs guessed issue code.

----------------------------------------------------------------

## Hooks

The following hooks are provided for convenience:

### `prepare-commit-msg`

Ensures your commit messages are prefixed with the code of related issue.
