# git-mr

Prepares a merge request description, with link to Jira ticket and current branch commit list.

----------------------------------------------------------------

* [Synopsis](#synopsis)
* [Installation](#installation)
* [Configuration](#configuration)
* [Usage](#usage)
    + [`git mr`](#git-mr-1)
    + [`git mr open`](#git-mr-open)
    + [`git mr status`](#git-mr-status)
    + [`git mr update`](#git-mr-update)
    + [`git mr menu`](#git-mr-menu)
    + [`git mr ip|cr|qa`](#git-mr-ipcrqa)
    + [`git mr undraft`](#git-mr-undraft)
    + [`git mr merge`](#git-mr-merge)
    + [`git mr hook`](#git-mr-hook)
* [Hooks](#hooks)
  + [prepare-commit-msg](#prepare-commit-msg)
* [Sample output](#sample-output)

----------------------------------------------------------------

## Synopsis

<pre>
<b>git mr</b>  <i>[OPTIONS]</i>          <i>[ISSUE_CODE]</i> <i>[BASE_BRANCH]</i>
<b>git mr</b>  <i>[OPTIONS]</i>  <b>open</b>    <i>[ISSUE_CODE]</i> <i>[BASE_BRANCH]</i>
<b>git mr</b>  <i>[OPTIONS]</i>  <b>status</b>
<b>git mr</b>  <i>[OPTIONS]</i>  <b>update</b>  <i>[BASE_BRANCH]</i>

<b>git mr</b>  <i>[OPTIONS]</i>  <b>menu</b>    <i>[update [--all] | status]</i> <i>[ISSUE_CODE]</i>

<b>git mr</b>  <i>[OPTIONS]</i>  <b>ip</b>
<b>git mr</b>  <i>[OPTIONS]</i>  <b>cr</b>
<b>git mr</b>  <i>[OPTIONS]</i>  <b>qa</b>
<b>git mr</b>  <i>[OPTIONS]</i>  <b>undraft</b>

<b>git mr</b>  <i>[OPTIONS]</i>  <b>merge</b>   <i>[BASE_BRANCH]</i>

<b>git mr</b>  <i>[OPTIONS]</i>  <b>hook</b>
</pre>

### Arguments

* `ISSUE_CODE` Force Jira issue code, if not detected properly
* `BASE_BRANCH` Force base branch, if not detected properly

### Options

* `-v` Verbose output (displays called API URLs)
* `-y` Bypass confirmation prompts (always answer "yes")
* `-e` Use full commit messages in description ("extended", for `git mr update`)
* `-a`|`--all` Update all merge requests (`git mr menu update`)

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

### Dependencies

* [**`jq`**](https://stedolan.github.io/jq/) is required and needs to be in PATH.


## Configuration

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
* https://id.atlassian.com/manage-profile/security/api-tokens<br>
  (Account Settings -> Security -> API Token -> Create and manage API tokens)

To create a Gitlab API Token, go to:
* https://myapp.gitlab.com/profile/personal_access_tokens<br>
  (Settings -> Access Tokens)

Other optional configuration variables:
```bash
# Default labels for new merge requests
export GITLAB_DEFAULT_LABELS="Review,My Team"

# Check "Delete source branch" by default (defaults to 1)
export GITLAB_DEFAULT_FORCE_REMOVE_SOURCE_BRANCH=1

# Network timeout (in seconds, defaults to 5)
export GIT_MR_TIMEOUT=5

# Gitlab status labels (comma-separated, without spaces in between)
export GITLAB_OK_LABELS="Validated,Accepted" # Labels removed on IP, CR or QA steps
export GITLAB_CR_LABELS="Review"             # Labels set on CR step
export GITLAB_QA_LABELS="Testing"            # Labels set on QA step

# Jira status IDs
export JIRA_IP_ID="xx" # "In progress" status ID
export JIRA_CR_ID="xx" # "Code review" status ID
export JIRA_QA_ID="xx" # "Quality Assurance" status ID
```


## Usage

### `git mr`

<pre>
<b>git mr</b> <i>[OPTIONS]</i> <i>[ISSUE_CODE]</i> <i>[BASE_BRANCH]</i>
</pre>

This will print a merge request description, with a link to Jira ticket and current branch commit list.
* `ISSUE_CODE` can be guessed from the branch name according to `JIRA_CODE_PATTERN` 
* `BASE_BRANCH` is determined by going up the commit history and finding the first one attached to a branch 

If a merge request based on the current branch is found on Gitlab, its URL will be provided, along with current votes, open and resolved threads and mergeable status.

Otherwise, a link to create a new merge request will be provided. Default labels and "Delete source branch" status 
can be configured with the `GITLAB_DEFAULT_LABELS` and `GITLAB_DEFAULT_FORCE_REMOVE_SOURCE_BRANCH` environment variables.

----------------------------------------------------------------

### `git mr open`

<pre>
<b>git mr</b> <i>[OPTIONS]</i> <b>o|op|open</b> <i>[ISSUE_CODE]</i> <i>[BASE_BRANCH]</i>
</pre>

Similar to `git mr`, but will open browser directly.

----------------------------------------------------------------

### `git mr status`

<pre>
<b>git mr</b> <i>[OPTIONS]</i> <b>s|st|status</b> <i>[BASE_BRANCH]</i>
</pre>

Displays a quick summary of the merge request, with useful indicators (tags, target branch, votes, open threads, draft status, ...)

----------------------------------------------------------------

### `git mr update`

<pre>
<b>git mr</b> <i>[OPTIONS]</i> <b>u|up|update</b> <i>[BASE_BRANCH]</i>
</pre>

This will:
* fetch and display the current merge request description from Gitlab.
* compare the commit lists and update the SHA-1 references in the description

If some commits were changed (after a rebase) or added, you will be prompted if you want to post the updated description to Gitlab.

You can also update the source branche if it is different from the current one.

----------------------------------------------------------------

### `git mr menu`

<pre>
<b>git mr</b> <i>[OPTIONS]</i> <b>menu</b> <i>[st|status]</i> <i>[up|update [--all]]</i> <i>[ISSUE_CODE]</i> 
</pre>

Searches for all (non-closed) merge requests with the current issue code in the title, and generates a menu.

Sample:
```markdown
## Menu

* My Project: [feature/XY-1234 My feature main stuff](https://myapp.gitlab.com/my/project/merge_requests/5)
* My Other Project: [feature/XY-1234 My feature related stuff](https://myapp.gitlab.com/my/other-project/merge_requests/6)
* My Other Project: [feature/XY-1234 My feature other stuff](https://myapp.gitlab.com/my/other-project/merge_requests/7)

--------------------------------------------------------------------------------

```

* `git mr menu`<br>
  Prints the markdown menu

* `git mr menu up|update`<br>
  Updates the menu in the current merge request description (prompts for confirmation)
* `git mr menu up|update -a|--all`<br>
  Updates the menu in all related merge requests (prompts for confirmation)

* `git mr menu st|status`<br>
  Prints the menu and status indicators for every related merge request

----------------------------------------------------------------

### `git mr ip|cr|qa`

<pre>
<b>git mr</b> <i>[OPTIONS]</i> <b>ip|cr|qa</b> <i>[ISSUE_CODE]</i>
</pre>

This will:
* Set Gitlab labels according to:
  - `GITLAB_CR_LABELS`
  - `GITLAB_QA_LABELS`
  - `GITLAB_OK_LABELS`
* set Jira ticket to status ID defined in:
  - `JIRA_IP_ID`
  - `JIRA_CR_ID`
  - `JIRA_QA_ID`

#### `git mr ip`
* removes Gitlab labels defined in `GITLAB_CR_LABELS`, `GITLAB_QA_LABELS` and `GITLAB_OK_LABELS`
* sets Jira ticket to status ID defined in `JIRA_IP_ID`

#### `git mr cr`
* removes Gitlab labels defined in `GITLAB_QA_LABELS`, and `GITLAB_OK_LABELS`
* adds Gitlab labels defined in `GITLAB_CR_LABELS`
* sets Jira ticket to status ID defined in `JIRA_CR_ID`

#### `git mr qa`
* removes Gitlab labels defined in `GITLAB_CR_LABELS`, and `GITLAB_OK_LABELS`
* adds Gitlab labels defined in `GITLAB_QA_LABELS`
* sets Jira ticket to status ID defined in `JIRA_QA_ID`

----------------------------------------------------------------

### `git mr undraft`

<pre>
<b>git mr</b> <i>[OPTIONS]</i> <b>undraft</b>
</pre>

This will resolve the Gitlab _Work in Progress_ status.

----------------------------------------------------------------

### `git mr merge`

<pre>
<b>git mr</b> <i>[OPTIONS]</i> <b>m|mg|merge</b> <i>[BASE_BRANCH]</i>
</pre>

This will:
* check merge status
* check open threads
* check draft status

and if applicable, will prompt you to:
* resolve draft status
* trigger the merge
* checkout local target branch, update it and delete local merged branch

----------------------------------------------------------------

### `git mr hook`

<pre>
<b>git mr</b> <i>[OPTIONS]</i> <b>hook</b>
</pre>

This will symlink hooks of your repository to the ones provided by git-mr:
* `prepare-commit-msg`

----------------------------------------------------------------

## Hooks

The following hooks are provided for convenience:

### `prepare-commit-msg`

Ensures your commit messages are prefixed with the code of related issue.

----------------------------------------------------------------

## Sample output

<pre>
<font color="#4E9A06">me@mystation</font><font color="#D3D7CF">:</font><font color="#729FCF"><b>~/projects/my-project</b></font><font color="#905C99"> (feature/xy-1234-ipsum)</font><font color="#4E9A06"> ↔ ✔ </font>$ git mr
</pre>
<pre>
<details>
<summary>Output</summary>
--------------------------------------------------------------------------------
# [XY-1234 Ipsum consectetur adipiscing](https://mycompany.atlassian.net/browse/XY-1234)

## Commits

* **78330c9 In vulputate quam ac ultrices volutpat**&lt;br&gt;
* **0010a6a Curabitur vel purus sed tortor finibus posuere**&lt;br&gt;
* **3621817 Aenean sed sem hendrerit ex egestas**&lt;br&gt;

--------------------------------------------------------------------------------

To create a new merge request:

  https://myapp.gitlab.com/my/project/merge_requests/new?merge_request%5Bsource_branch%5D=feature/xy-1234-ipsum&amp;merge_request%5Btarget_branch%5D=develop
</details></pre>

------------------------------------------------------------------------------------------------------------------------

<pre>
<font color="#4E9A06">me@mystation</font><font color="#D3D7CF">:</font><font color="#729FCF"><b>~/projects/my-project</b></font><font color="#905C99"> (feature/xy-1234-ipsum)</font><font color="#4E9A06"> ↔ ✔ </font>$ git mr -e
</pre>
<pre>
<details>
<summary>Output</summary>
--------------------------------------------------------------------------------
# [XY-1234 Ipsum consectetur adipiscing](https://mycompany.atlassian.net/browse/XY-1234)

## Commits

* **78330c9 In vulputate quam ac ultrices volutpat**

  Some commit description

* **0010a6a Curabitur vel purus sed tortor finibus posuere**

  Extended description
  - stuff
  - other stuff

* **3621817 Aenean sed sem hendrerit ex egestas**

--------------------------------------------------------------------------------

To create a new merge request:

  https://myapp.gitlab.com/my/project/merge_requests/new?merge_request%5Bsource_branch%5D=feature/xy-1234-ipsum&amp;merge_request%5Btarget_branch%5D=develop
</details></pre>

------------------------------------------------------------------------------------------------------------------------

<pre>
<font color="#4E9A06">me@mystation</font><font color="#D3D7CF">:</font><font color="#729FCF"><b>~/projects/my-project</b></font><font color="#905C99"> (feature/xy-1234-ipsum)</font><font color="#4E9A06"> ↔ ✔ </font>$ git mr update
</pre>
<pre>
<details>
<summary>Output</summary>
-------------------------------------------------------------------
Draft: Feature/XY-1234 Ipsum
-------------------------------------------------------------------
# [XY-1234 Ipsum consectetur adipiscing](https://mycompany.atlassian.net/browse/XY-1234)

Vivamus venenatis tortor et neque sollicitudin, eget suscipit est malesuada

## Commits

* **<font color="#729FCF">78330c9</font> In vulputate quam ac ultrices volutpat**&lt;br&gt;
  In vulputate quam&lt;br&gt;
  ac ultrices volutpat

* **<font color="#729FCF">0010a6a</font> Curabitur vel purus sed tortor finibus posuere**&lt;br&gt;
  Curabitur vel

* **<font color="#C4A000">aac348f</font> Aenean sed sem hendrerit ex egestas tincidunt**&lt;br&gt;
  Hendrerit ex egestas&lt;br&gt;
  egestas sed

## Update

* **<font color="#4E9A06">e9642b7</font> Ut consectetur leo ut leo commodo porttitor**&lt;br&gt;

--------------------------------------------------------------------------------

  updated commits: <font color="#C4A000">1</font>
      new commits: <font color="#4E9A06">1</font>

Do you want to update the merge request description? [y/N] y
OK
--------------------------------------------------------------------------------

Merge request:

  https://myapp.gitlab.com/my/project/merge_requests/6

    👍  1    👎  0        Resolved threads: 1/2        Draft: yes        Can be merged: ✅
</details></pre>

------------------------------------------------------------------------------------------------------------------------

<pre>
<font color="#4E9A06">me@mystation</font><font color="#D3D7CF">:</font><font color="#729FCF"><b>~/projects/my-project</b></font><font color="#905C99"> (feature/xy-1234-ipsum)</font><font color="#4E9A06"> ↔ ✔ </font>$ git mr merge
</pre>
<pre>
<details>
<summary>Output</summary>
-------------------------------------------------------------------
Draft: Feature/XY-1234 Ipsum
-------------------------------------------------------------------

Merge request:

  https://myapp.gitlab.com/my/project/merge_requests/6

    👍  2    👎  0        Resolved threads: 2/2        Draft: yes        Can be merged: ✅

<font color="#C4A000">Merge request is a Work in Progress</font>
Do you want to resolve draft status? [y/N] y
OK
Do you want to merge &apos;feature/xy-1234-ipsum&apos;? [y/N] y
OK
Do you want to checkout &apos;develop&apos; and pull changes? [y/N] y
Switched to branch &apos;develop&apos;
Your branch is up to date with &apos;origin/develop&apos;.
From myapp.gitlab.com:me/my/project
 - [deleted]         (none)     -&gt; origin/feature/xy-1234-ipsum
remote: Enumerating objects: 1, done.
remote: Counting objects: 100% (1/1), done.
remote: Total 1 (delta 0), reused 0 (delta 0), pack-reused 0
remote: 
Unpacking objects: 100% (1/1), 263 bytes | 263.00 KiB/s, done.
   c17b3a1..9545ecd  develop    -&gt; origin/develop
Updating c17b3a1..9545ecd
Fast-forward

Do you want to delete local branch &apos;feature/xy-1234-ipsum&apos; [y/N] y
Deleted branch feature/xy-1234-ipsum (was e9642b7).
</details></pre>
