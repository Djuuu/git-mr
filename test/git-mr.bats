#!/usr/bin/env bats

load "test_helper/bats-support/load"
load "test_helper/bats-assert/load"

################################################################################
# Setup

setup_file() {
    export LANG=C.UTF-8 # ensure tests handle UTF-8 properly

    # Unset all git-mr environment variables (would take precedence over local configuration)
    unset JIRA_INSTANCE JIRA_USER JIRA_TOKEN JIRA_CODE_PATTERN \
          GITLAB_DOMAIN GITLAB_TOKEN GITLAB_MR_LIMIT_GROUP GITLAB_DEFAULT_LABELS \
          GITLAB_IP_LABELS GITLAB_CR_LABELS GITLAB_QA_LABELS GITLAB_OK_LABELS \
            JIRA_IP_ID       JIRA_CR_ID       JIRA_QA_ID       JIRA_OK_ID \
          GITLAB_PROJECTS_LIMIT_MEMBER \
          GIT_MR_EXTENDED GIT_MR_REQUIRED_UPVOTES GIT_MR_TIMEOUT

    export GIT_MR_NO_COLORS=1
    export GIT_MR_NO_TERMINAL_LINK=1
    export GIT_MR_NO_COMMITS=
    export GIT_MR_EXTENDED=

    export GITLAB_DOMAIN="gitlab.example.net"

    export MD_BR='..' # for easier visualization

    # Custom file descriptors
    # {var}-style redirects automatically allocating free file descriptors don't seem to work well in bats context
    export GIT_MR_FD_MR=21
    export GIT_MR_FD_AP=22
    export GIT_MR_FD_TH=23

    cd "${BATS_TEST_DIRNAME}" || exit

    [[ -d data ]] && rm -rf data
    mkdir data && cd data || exit

    git init --bare remote
    git init --bare gitlab
    git init repo && cd repo || exit
    configure-git-repo

    git remote add fs-local ../remote
    git remote add gitlab ../gitlab -m real-main

    git switch -c main
    git commit --allow-empty -m "Main 1"
    git commit --allow-empty -m "Main 2"
        git switch -c feature/old
        git commit --allow-empty -m "Old 1"
        git commit --allow-empty -m "Old 2"
        git switch main

    git commit --allow-empty -m "Main 3"
    git commit --allow-empty -m "Main 4"
        git branch feature/local
    git commit --allow-empty -m "Main 5"

    git push fs-local main
    git push -u gitlab main:real-main
    echo "ref: refs/remotes/gitlab/real-main" > .git/refs/remotes/gitlab/HEAD

    git switch -c epic/big-feature main
    git commit --allow-empty -m "Epic 1"
    git commit --allow-empty -m "Epic 2"
    git commit --allow-empty -m "Epic 3"

    git switch -c feature/base
    git commit --allow-empty -m "Feature base - 1"
    git push -u fs-local feature/base # remote branch should not be considered as base
    git commit --allow-empty -m "Feature base - 2" -m "This is my second commit"
    git tag base-tag # tag should not be considered as base
    git commit --allow-empty -m "Feature base - 3" -m "This is my third commit" -m "With an extended description"

    git switch -c feature/AB-123-test-feature
    git commit --allow-empty -m "Feature test - 1"
    git push fs-local feature/AB-123-test-feature # remote branch should not be considered as base
    git push -u gitlab feature/AB-123-test-feature # remote branch should not be considered as base
    git commit --allow-empty -m "Feature test - 2" -m "This is my second commit"
    git tag feature-tag # tag should not be considered as base
    git commit --allow-empty -m "Feature test - 3" -m "This is my third commit" -m "With an extended description"

    git remote set-url --push gitlab "git@${GITLAB_DOMAIN}:my/project.git"

    cd ..
}

teardown_file() {
    cd "${BATS_TEST_DIRNAME}" || exit
    rm -rf data
}

setup() {
    # cd to repo first to take local git-mr configuration into account
    cd "${BATS_TEST_DIRNAME}/data" || exit
    cd repo

    # Source git-mr to load functions
    . "${BATS_TEST_DIRNAME}"/../git-mr >&3

    git switch feature/AB-123-test-feature
}

################################################################################
# Wrappers & utilities

# Use test config (useful when git is run by Bats)
git() {
    command git \
        -c include.path="${BATS_TEST_DIRNAME}/.gitconfig" \
        "$@"
}

# Set test config in repo (useful when git is run by git-mr)
configure-git-repo() {
    command git config --local include.path "${BATS_TEST_DIRNAME}/.gitconfig"
}

git-push() {
    [[ $1 == "gitlab" ]] && git remote set-url --push gitlab "../gitlab"
    git push "$@"
    [[ $1 == "gitlab" ]] && git remote set-url --push gitlab "git@${GITLAB_DOMAIN}:my/project.git"
}

git-mr() {
    "${BATS_TEST_DIRNAME}"/../git-mr "$@"
}

short_sha() {
    git log --all --oneline | grep "$1" | cut -d ' ' -f 1
}

full_sha() {
    git rev-parse "$(short_sha "$1")"
}

sha_link() {
    local mr_url="some/project/-/merge_requests/1"
    echo "[${1}](https://${GITLAB_DOMAIN}/${mr_url}/diffs?commit_id=$(git rev-parse "${1}"))"
}

################################################################################
# Git functions

@test "Fails outside a Git repository" {
    cd /tmp
    run git-mr
    assert_failure "$ERR_GIT_REPO"
}

@test "Determines current branch" {
    git switch main
    run git_current_branch
    assert_output "main"

    git switch epic/big-feature
    run git_current_branch
    assert_output "epic/big-feature"

    git switch feature/base
    run git_current_branch
    assert_output "feature/base"

    git switch feature/AB-123-test-feature
    run git_current_branch
    assert_output "feature/AB-123-test-feature"

    git checkout -f "$(git rev-parse HEAD)"
    run git_current_branch
    assert_output ""
}

@test "Determines base branch" {
    git switch epic/big-feature
    run git-mr base
    assert_output "main"

    git switch feature/base
    run git-mr base
    assert_output "epic/big-feature"

    git switch feature/AB-123-test-feature
    run git-mr base
    assert_output "feature/base"

    git switch feature/old
    run git-mr base
    assert_output "$(full_sha "Main 2")"

    git checkout -f "$(git rev-parse HEAD)"
    run git-mr base
    assert_failure "$ERR_GIT"

    git switch main
    run git-mr base
    assert_failure "$ERR_GIT"

    # with argument
    run git-mr base feature/AB-123-test-feature
    assert_output "feature/base"
}

@test "Determines remote name" {
    run git_remote
    assert_output fs-local
}

@test "Checks branch existence" {
    run git_branch_exists feature/base
    assert_success

    run git_branch_exists whatever
    assert_failure
}

@test "Determines default branch" {
    # Consider local branch tracking gitlab remote default
    run git_default_branch
    assert_output "main"

    # fallback
    export GITLAB_DOMAIN="test.example.net"
    run git_default_branch
    assert_output "main"
}

@test "Checks remote branch existence" {
    # Local-only branch
    run git_remote_branch_exists feature/local
    assert_failure
    run git_remote_branch_exists feature/local fs-local
    assert_failure

    # Only on fs-local remote (gitlab remote considered by default)
    run git_remote_branch_exists feature/base
    assert_failure
    run git_remote_branch_exists feature/base fs-local
    assert_success

    # On both remotes
    run git_remote_branch_exists feature/AB-123-test-feature
    assert_success
    run git_remote_branch_exists feature/AB-123-test-feature fs-local
    assert_success

    # Non-existent branch
    run git_remote_branch_exists feature/whatever
    assert_failure
    run git_remote_branch_exists feature/whatever fs-local
    assert_failure
}

@test "Checks branch coherence" {
    run git_check_branches feature/base main
    assert_success
    assert_output ""

    run git_check_branches "" main
    assert_failure "$ERR_GIT"
    assert_output "Not on any branch"

    run git_check_branches test main
    assert_failure "$ERR_GIT"
    assert_output "Branch 'test' does not exist"

    run git_check_branches main epic/big-feature
    assert_failure "$ERR_GIT"
    assert_output "On default branch"

    run git_check_branches feature/base ""
    assert_failure "$ERR_GIT"
    assert_output "Unable to determine target branch"

    # Workaround when we don't care about checking target (mr status)
    run git_check_branches feature/base "-"
    assert_success

    GIT_MR_TARGET="wrong"
    run git_check_branches feature/base "wrong"
    assert_failure "$ERR_GIT"
    assert_output "Branch 'wrong' does not exist"
}

@test "Lists current branch commits" {
    testSha1=$(short_sha "Feature test - 1")
    testSha2=$(short_sha "Feature test - 2")
    testSha3=$(short_sha "Feature test - 3")
    baseSha1=$(short_sha "Feature base - 1")
    baseSha2=$(short_sha "Feature base - 2")
    baseSha3=$(short_sha "Feature base - 3")

    # Commits of current branch
    run git_commits
    assert_output "$(cat <<- EOF
		${testSha1} Feature test - 1
		${testSha2} Feature test - 2
		${testSha3} Feature test - 3
		EOF
    )"

    git switch main

    # Commits of specified branch
    run git_commits "feature/base"
    assert_output "$(cat <<- EOF
		${baseSha1} Feature base - 1
		${baseSha2} Feature base - 2
		${baseSha3} Feature base - 3
		EOF
    )"

    run git_commits "feature/AB-123-test-feature" "epic/big-feature"
    assert_output "$(cat <<- EOF
		${baseSha1} Feature base - 1
		${baseSha2} Feature base - 2
		${baseSha3} Feature base - 3
		${testSha1} Feature test - 1
		${testSha2} Feature test - 2
		${testSha3} Feature test - 3
		EOF
    )"

    run git_commits "feature/AB-123-test-feature" "${testSha1}"
    assert_output "$(cat <<- EOF
		${testSha2} Feature test - 2
		${testSha3} Feature test - 3
		EOF
    )"
}

@test "Lists current branch commits with commit body" {
    sha1=$(short_sha "Feature test - 1")
    sha2=$(short_sha "Feature test - 2")
    sha3=$(short_sha "Feature test - 3")

    run git_commits_extended

    assert_output "$(cat <<- EOF
		* **${sha1} Feature test - 1**..
		* **${sha2} Feature test - 2**..
		This is my second commit
		* **${sha3} Feature test - 3**..
		This is my third commit

		With an extended description
		EOF
    )"
}

@test "Shows commit with commit body" {
    sha2=$(short_sha "Feature test - 2")

    run git_commit_extended_console_display "$sha2"

    assert_output "$(cat <<- EOF
		* **${sha2} Feature test - 2**..
		This is my second commit
		EOF
    )"
}

@test "Makes title from branch" {
    run git_titlize_branch feature/AB-123-some-branch_title
    assert_output "Feature/AB-123 Some branch title"

    run git_titlize_branch AB-123-some-branch_title
    assert_output "AB-123 Some branch title"

    run git_titlize_branch task/other_branch-title
    assert_output "Task/Other branch title"
}

################################################################################
# Misc. utilities

@test "Uses GNU commands" {
    run sed --version
    assert_success
    assert_output --partial "GNU sed"

    run grep --version
    assert_success
    assert_output --partial "GNU grep"
}

@test "Exits with error" {
    run exit_error 99 "Nope!"
    assert_failure 99
    assert_output "Nope!"
}

@test "Encodes URL arguments" {
    run urlencode "Some 'string'&\"stuff\" (that needs [to] be) encoded!"
    assert_output "Some%20%27string%27%26%22stuff%22%20%28that%20needs%20%5Bto%5D%20be%29%20encoded%21"
}

@test "Checks terminal color support" {
    TERM=xterm-256color
    GIT_MR_NO_COLORS=
    run has_colors; assert_success

    GIT_MR_NO_COLORS=1
    run has_colors; assert_failure

    GIT_MR_NO_COLORS=
    TERM=ansi-mono # disable colors
    run has_colors; assert_failure
}

@test "Checks terminal link support (sort of)" {
    TERM=xterm-256color
    GIT_MR_NO_TERMINAL_LINK=
    run has_links; assert_success

    GIT_MR_NO_TERMINAL_LINK=1
    run has_links; assert_failure

    GIT_MR_NO_TERMINAL_LINK=
    TERM=ansi-mono # disable colors
    run has_links; assert_failure
}

@test "Outputs conditionally depending on verbosity" {
    GIT_MR_VERBOSE=1
    run echo_debug "Some debug output"
    assert_success
    assert_output "Some debug output"

    GIT_MR_VERBOSE=0
    run echo_debug "Some debug output"
    assert_success
    assert_output ""

    GIT_MR_VERBOSE=
    run echo_debug "Some debug output"
    assert_success
    assert_output ""
}

@test "Outputs spacers" {
    run echo_spacer 3
    assert_output "   "

    run echo_spacer 5 '-'
    assert_output "-----"

    run echo_spacer 0 'x'
    assert_output ""

    run echo_spacer -1 'x'
    assert_output ""
}

@test "Trims strings" {
    run trim "  some string  " " "
    assert_output "some string"

    run trim ",,some,list,," ","
    assert_output "some,list"
}

@test "Asks for confirmation" {
    run confirm "Are you sure?" <<< "yes"
    assert_success
    run confirm "Are you sure?" <<< "y"
    assert_success

    run confirm "Are you sure?" <<< "no"
    assert_failure
    run confirm "Are you sure?" <<< "n"
    assert_failure
    run confirm "Are you sure?" <<< "whatever"
    assert_failure

    GIT_MR_YES=1
    run confirm "Are you sure?" <<< "whatever"
    assert_success
    run confirm "Are you sure?"
    assert_success
}

@test "Builds json" {
    data=$(jq_build "title" "Some Title")
    data=$(jq_build "description" "Some Description" "$data")
    data=$(jq_build "value" 3 "$data")

    assert_equal "$data" '{"title":"Some Title","description":"Some Description","value":3}'
}

@test "Escapes regex literals" {
    run regex_escape '[] \/ $ * . ^ ? []'
    assert_output '\[\] \\\/ \$ \* \. \^ \? \[\]'
}

@test "Has read-only mode" {
    GIT_MR_READONLY=1
    run git_mr_readonly
    assert_success
    run git_mr_readonly show
    assert_success
    assert_output "🚫 Read-only 🚫"

    GIT_MR_READONLY=0
    run git_mr_readonly
    assert_failure
    run git_mr_readonly show
    assert_failure
    assert_output ""

    GIT_MR_READONLY=
    run git_mr_readonly
    assert_failure
    run git_mr_readonly show
    assert_failure
    assert_output ""

    export GIT_MR_READONLY=1
    JIRA_USER="whatever"
    JIRA_TOKEN="whatever"
    JIRA_INSTANCE="whatever"
    run jira_request "whatever" "POST" "{}"
    assert_success

    run gitlab_request "whatever" "POST" "{}"
    assert_success
}

@test "Determines default text editor from env" {
    VISUAL=fake_visual_test
    EDITOR=fake_editor_test
    run git_mr_editor
    assert_failure
    assert_output "Invalid editor: fake_visual_test"

    VISUAL=
    EDITOR=fake_editor_test
    run git_mr_editor
    assert_failure
    assert_output "Invalid editor: fake_editor_test"
}

################################################################################
# Markdown formatting

@test "Formats markdown titles" {
    run markdown_title "This is a title"
    assert_output "# This is a title"

    run markdown_title "This is a level 2 title" 2
    assert_output "## This is a level 2 title"
}

@test "Formats markdown links" {
    run markdown_link "Link" "https://example.net/"
    assert_output "[Link](https://example.net/)"
}

@test "Formats markdown lists" {
    run markdown_list "$(cat <<- EOF
		one
		two two
		three three three
		EOF
    )"
    assert_output "$(cat <<- EOF
		* **one**..
		* **two two**..
		* **three three three**..
		EOF
    )"
}

@test "Formats markdown list descriptions" {
    run markdown_indent_list_items "$(cat <<- EOF
		* **one**..
		blah
		* **two**..
		blah
		blah
		EOF
    )"
    assert_output "$(cat <<- EOF
		* **one**..
		  blah..
		* **two**..
		  blah..
		  blah..
		EOF
    )"
}

################################################################################
# Gitlab functions

@test "Determines Gitlab remote" {
    # Default tests setup
    run gitlab_remote
    assert_success
    assert_output "gitlab"

    GITLAB_DOMAIN="test.example.net"

    git remote add other1 "git@other-domain.net:other1.git"
    git remote add other2 "https://other-domain.net/other2.git"
    run gitlab_remote
    assert_failure "$ERR_GIT_REPO"

    # SSH URL
    git remote add gitlab1 "git@${GITLAB_DOMAIN}:my/project.git"
    run gitlab_remote
    assert_success
    assert_output "gitlab1"
    git remote remove gitlab1

    # HTTPS URL
    git remote add gitlab2 "https://${GITLAB_DOMAIN}/my/project.git"
    run gitlab_remote
    assert_success
    assert_output "gitlab2"
    git remote remove gitlab2

    git remote remove other1
    git remote remove other2
}

@test "Determines Gitlab project URL" {
    GITLAB_DOMAIN="test.example.net"

    run gitlab_project_url
    assert_failure "$ERR_GIT_REPO"
    assert_output "$(cat <<- EOF
		Unable to determine Gitlab project URL, check GITLAB_DOMAIN configuration
		  fs-local:     ../remote
		  current:    GITLAB_DOMAIN="test.example.net"
		  Suggestion: GITLAB_DOMAIN="../remote"
		EOF
    )"

    # SSH URL
    git remote add remote1 "git@${GITLAB_DOMAIN}:my/project.git"
    run gitlab_project_url
    assert_success
    assert_output "my/project"
    git remote remove remote1

    # HTTPS URL
    git remote add gitlab1 "https://${GITLAB_DOMAIN}/my/project.git"
    run gitlab_project_url
    assert_success
    assert_output "my/project"
    git remote remove gitlab1
}

@test "Sends Gitlab project API requests" {
    gitlab_request() {
        echo "gitlab_request('$1' '${2:-"GET"}' '$3')"
    }

    run gitlab_current_project_request 'test' 'POST' '{"test":1}'
    assert_success
    assert_output "gitlab_request('projects/my%2Fproject/test' 'POST' '{\"test\":1}')"
}

@test "Warns for Gitlab API request errors" {
    run gitlab_check_error '{"error":"failed"}'
    assert_failure
    assert_output "$(cat <<- EOF

		Gitlab error:
		  {"error":"failed"}
		EOF
    )"

    run gitlab_check_error '{"message":"failed"}'
    assert_failure
    assert_output "$(cat <<- EOF

		Gitlab error:
		  {"message":"failed"}
		EOF
    )"

    run gitlab_check_error '{"ok":"ok"}'
    assert_success
    assert_output ""
}

@test "Determines new merge request URL" {
    GITLAB_DEFAULT_LABELS="Label A,Label C"
    gitlab_current_project_request() {
        [[ $1 == "labels" ]] &&
            echo '[{"id":1,"name":"Label A"},{"id":2,"name":"Label B"},{"id":3,"name":"Label C"}]'
    }

    run gitlab_new_merge_request_url
    assert_output "Target branch 'feature/base' does not exist on remote"

    # bypass remote branch existence check
    git_remote_branch_exists() { return 0; }

    run gitlab_new_merge_request_url
    expected="https://${GITLAB_DOMAIN}/my/project/-/merge_requests/new"
    expected="${expected}?merge_request%5Bsource_branch%5D=feature/AB-123-test-feature"
    expected="${expected}&merge_request%5Btarget_branch%5D=feature/base"
    expected="${expected}&merge_request%5Blabel_ids%5D%5B%5D=1&merge_request%5Blabel_ids%5D%5B%5D=3"
    expected="${expected}&merge_request%5Bforce_remove_source_branch%5D=1"
    expected="${expected}&merge_request%5Btitle%5D=Draft%3A%20Feature%2FAB-123%20Test%20feature"
    assert_output "$expected"
}

@test "Extracts MR info from merge request summary" {
    gitlab_current_project_request() {
        case "$1" in
            "merge_requests?state=opened&view=simple&source_branch=feature/xy-1234-lorem-ipsum")
                echo '[{
                    "id": 1234, "iid": 123, "project_id": 12,
                    "title": "Draft: Feature/XY-1234 Lorem Ipsum",
                    "web_url": "https://gitlab.example.net/mr/123"
                },{}]'
                ;;
            "merge_requests?state=opened&view=simple&source_branch=feature/nope")
                echo '[]'
                ;;
            *) return $ERR_GITLAB;;
        esac
    }

    mr_summary=$(gitlab_merge_request_summary "feature/xy-1234-lorem-ipsum")

    run gitlab_extract_iid   "$mr_summary"; assert_output 123
    run gitlab_extract_url   "$mr_summary"; assert_output "https://gitlab.example.net/mr/123"
    run gitlab_extract_title "$mr_summary"; assert_output "Draft: Feature/XY-1234 Lorem Ipsum"

    run gitlab_merge_request_summary "feature/nope"
    assert_success
    assert_output ""

    run gitlab_merge_request_summary "nope"
    assert_failure "$ERR_GITLAB"
    assert_output ""

    run gitlab_extract_iid   ""; assert_output ''
    run gitlab_extract_url   ""; assert_output ''
    run gitlab_extract_title ""; assert_output ''
}

@test "Extracts MR info from merge request detail" {
    mr_detail='{
        "title":"MR title",
        "description":"MR description",
        "merge_status":"can_be_merged",
        "target_branch":"main",
        "labels":["aaa","b b","c-c"],
        "head_pipeline": {"status":"success", "web_url":"https://example.net/ci"}
    }'
    assert_equal "$(gitlab_extract_title "$mr_detail")" "MR title"
    assert_equal "$(gitlab_extract_description "$mr_detail")" "MR description"
    assert_equal "$(gitlab_extract_merge_status "$mr_detail")" 'can_be_merged'
    assert_equal "$(gitlab_extract_pipeline_status "$mr_detail")" 'success'
    assert_equal "$(gitlab_extract_pipeline_url "$mr_detail")" 'https://example.net/ci'
    assert_equal "$(gitlab_extract_target_branch "$mr_detail")" 'main'
    assert_equal "$(gitlab_extract_labels "$mr_detail")" 'aaa,b b,c-c'

    mr_detail='{"title":"MR title","state":"merged"}'
    assert_equal "$(gitlab_extract_merge_status "$mr_detail")" 'merged'
}

@test "Extracts Gitlab project part from MR URL" {
    mr_url="https://gitlab.example.net/some/project/-/merge_requests/123"

    run gitlab_extract_project_url_part "$mr_url"
    assert_output "some/project"
}

@test "Extracts Gitlab merge request approvals" {
    gitlab_request() {
        [[ $1 == "projects/some%2Fproject/merge_requests/1/approval_state" ]] &&
            echo '{"rules": '"$approval_rules"'}'
    }

    approval_rules='[
      {
        "id": 1, "name": "Example",
        "approvals_required": 2,
        "approved_by": [
          {"id": 1, "name": "John Doe"}
        ],
        "approved": false
      }, {
        "id": 2, "name": "Example",
        "approvals_required": 1,
        "approved_by": [
          {"id": 3, "name": "Jane Doe"}
        ],
        "approved": true
      }
    ]'
    run gitlab_merge_request_approvals "https://gitlab.example.net/some/project/-/merge_requests/1"
    assert_output "false 2/3"

    approval_rules='[
      {
        "id": 1, "name": "Example",
        "approvals_required": 2,
        "approved_by": [
          {"id": 1, "name": "John Doe"},
          {"id": 2, "name": "John Dough"}
        ],
        "approved": true
      }, {
        "id": 2, "name": "Example",
        "approvals_required": 1,
        "approved_by": [
          {"id": 3, "name": "Jane Doe"}
        ],
        "approved": true
      }
    ]'
    run gitlab_merge_request_approvals "https://gitlab.example.net/some/project/-/merge_requests/1"
    assert_output "true 3/3"

    approval_rules='[
      {
        "id": 1, "name": "Example",
        "approvals_required": 2,
        "approved_by": [
          {"id": 1, "name": "John Doe"}
        ],
        "approved": false
      }, {
        "id": 2, "name": "Example",
        "approvals_required": 1,
        "approved_by": [
          {"id": 3, "name": "Jane Doe"},
          {"id": 4, "name": "Jenn Doh"}
        ],
        "approved": true
      }
    ]'
    run gitlab_merge_request_approvals "https://gitlab.example.net/some/project/-/merge_requests/1"
    assert_output "false 3/3"

    approval_rules='[
      {
        "id": 1, "name": "Example",
        "approvals_required": 0,
        "approved_by": [
          {"id": 1, "name": "John Doe"}
        ],
        "approved": true
      }
    ]'
    run gitlab_merge_request_approvals "https://gitlab.example.net/some/project/-/merge_requests/1"
    assert_output "true 1/0"

    approval_rules='[]'
    run gitlab_merge_request_approvals "https://gitlab.example.net/some/project/-/merge_requests/1"
    assert_output "true 0/0"
}

@test "Extracts Gitlab merge request threads" {
    gitlab_request() {
        [[ $1 == "projects/some%2Fproject/merge_requests/123/discussions?per_page=100&page=1" ]] &&
            echo '[
                {"id": "n1","notes": [{"id": 11},{"id": 12,"resolvable": false}]},
                {"id": "n2","notes": [{"id": 21},{"id": 22,"resolvable": true, "resolved": false},{"id": 23,"resolvable": true, "resolved": false}]},
                {"id": "n3","notes": [{"id": 31},{"id": 32,"resolvable": true, "resolved": true}]}
            ]'
    }

    run gitlab_merge_request_threads "https://gitlab.example.net/some/project/-/merge_requests/123"
    assert_output "$(cat <<- EOF
		n2	unresolved:true	note_id:22
		n3	unresolved:false	note_id:null
		EOF
    )"
}

@test "Fetches default Gitlab label ids" {
    GITLAB_DEFAULT_LABELS="Label A,Label C"
    gitlab_current_project_request() {
        [[ $1 == "labels" ]] &&
            echo '[{"id":1,"name":"Label A"},{"id":2,"name":"Label B"},{"id":3,"name":"Label C"}, {"id":4,"name":"Label C"}]'
    }

    run gitlab_default_label_ids
    assert_output "$(cat <<- EOF
		1
		3
		4
		EOF
    )"
}

@test "Handles draft MR titles" {
    run gitlab_title_is_draft "WIP: My MR"
    assert_success

    run gitlab_title_is_draft "Draft: My MR"
    assert_success

    run gitlab_title_is_draft "My MR"
    assert_failure

    run gitlab_title_is_draft "My Draft: MR"
    assert_failure

    run gitlab_title_to_draft "My MR"
    assert_output "Draft: My MR"

    run gitlab_title_undraft  "Draft: My MR"
    assert_output "My MR"

    run gitlab_title_undraft  "WIP: My MR"
    assert_output "My MR"
}

################################################################################
# Merge request utility functions

@test "Determines issue code" {
    git switch feature/AB-123-test-feature
    run git-mr code
    assert_output "AB-123"

    git switch feature/base
    run git-mr code
    assert_output "Unable to guess issue code"

    run git-mr code feature/AB-123-CD-456-test-feature
    assert_output "CD-456" # debatable
}

@test "Generates MR title from Jira issue title" {
    load "test_helper/jira-mock.bash"

    run mr_title
    assert_output "[AB-123 This is an issue](https://mycompany.example.net/browse/AB-123)"

    run mr_title feature/without-code
    assert_output "$(cat <<- EOF
		Unable to guess issue code
		Feature/Without code
		EOF
    )" # includes stderr

    run mr_title feature/CD-456-unknown-code 2>/dev/null
    assert_output "$(cat <<- EOF
		Unable to get issue title from Jira
		  issue_code: CD-456
		CD-456
		EOF
    )" # includes stderr

    run mr_title feature/EF-789-no-summary 2>/dev/null
    assert_output "$(cat <<- EOF
		Unable to get issue title from Jira
		  issue_code: EF-789
		  {"key":"EF-789", "fields":{}}
		EF-789
		EOF
    )" # includes stderr
}

@test "Generates MR description from commits" {
    load "test_helper/jira-mock.bash"

    local c1sha=$(short_sha "Feature test - 1")
    local c2sha=$(short_sha "Feature test - 2")
    local c3sha=$(short_sha "Feature test - 3")

    GIT_MR_NO_COMMITS=1
    GIT_MR_EXTENDED=
    run mr_description

    assert_output "$(cat <<- EOF
		# [AB-123 This is an issue](https://mycompany.example.net/browse/AB-123)

		EOF
    )"

    GIT_MR_NO_COMMITS=
    GIT_MR_EXTENDED=
    run mr_description

    assert_output "$(cat <<- EOF
		# [AB-123 This is an issue](https://mycompany.example.net/browse/AB-123)


		## Commits

		* **${c1sha} Feature test - 1**..
		* **${c2sha} Feature test - 2**..
		* **${c3sha} Feature test - 3**..
		EOF
    )"

    GIT_MR_EXTENDED=1
    run mr_description

    local empty=""
    assert_output "$(cat <<- EOF
		# [AB-123 This is an issue](https://mycompany.example.net/browse/AB-123)


		## Commits

		* **${c1sha} Feature test - 1**..
		* **${c2sha} Feature test - 2**..
		  This is my second commit..
		* **${c3sha} Feature test - 3**..
		  This is my third commit..
		  ${empty}
		  With an extended description..
		EOF
    )"
}

@test "Prints MR status indicators" {
    mr='{
        "title": "Draft: Feature/XY-1234 Lorem Ipsum", "web_url":"https://gitlab.example.net/my/project/merge_requests/6",
        "labels":["Review","My Team"], "target_branch": "main", "upvotes": 1, "downvotes": 1, "merge_status": "cannot_be_merged",
        "head_pipeline": {"status":"failed", "web_url":"https://example.net/ci/1"}
    }'
    approvals='true 0/0'
    threads='1	unresolved:false	note_id:1
2	unresolved:true	note_id:2'

    run mr_status_block "$mr" "$mr" "$approvals" "$threads"
    assert_output "$(cat <<- EOF
		--------------------------------------------------------------------------------
		 Feature/XY-1234 Lorem Ipsum
		 ⇒ https://gitlab.example.net/my/project/merge_requests/6
		--------------------------------------------------------------------------------

		   🏷  [Review] [My Team]                       🚧 Draft               (↣ main)

		   👍 1  👎 1                Threads: 1/2       CI: ❌       Can be merged: ❌
		EOF
    )"

    # ------------------------------------------------------------------------------------------------------------------

    approvals='true 1/0'

    run mr_status_block "$mr" "$mr" "$approvals" "$threads"
    assert_output "$(cat <<- EOF
		--------------------------------------------------------------------------------
		 Feature/XY-1234 Lorem Ipsum
		 ⇒ https://gitlab.example.net/my/project/merge_requests/6
		--------------------------------------------------------------------------------

		   🏷  [Review] [My Team]                       🚧 Draft               (↣ main)

		   ✅ 1   👍 1  👎 1         Threads: 1/2       CI: ❌       Can be merged: ❌
		EOF
    )"

    approvals='false 1/2'

    run mr_status_block "$mr" "$mr" "$approvals" "$threads"
    assert_output "$(cat <<- EOF
		--------------------------------------------------------------------------------
		 Feature/XY-1234 Lorem Ipsum
		 ⇒ https://gitlab.example.net/my/project/merge_requests/6
		--------------------------------------------------------------------------------

		   🏷  [Review] [My Team]                       🚧 Draft               (↣ main)

		   ☑️ 1/2   👍 1  👎 1       Threads: 1/2       CI: ❌       Can be merged: ❌
		EOF
    )"

    approvals='false 2/2'

    run mr_status_block "$mr" "$mr" "$approvals" "$threads"
    assert_output "$(cat <<- EOF
		--------------------------------------------------------------------------------
		 Feature/XY-1234 Lorem Ipsum
		 ⇒ https://gitlab.example.net/my/project/merge_requests/6
		--------------------------------------------------------------------------------

		   🏷  [Review] [My Team]                       🚧 Draft               (↣ main)

		   ☑️ 2/2   👍 1  👎 1       Threads: 1/2       CI: ❌       Can be merged: ❌
		EOF
    )"

    approvals='true 2/2'

    run mr_status_block "$mr" "$mr" "$approvals" "$threads"
    assert_output "$(cat <<- EOF
		--------------------------------------------------------------------------------
		 Feature/XY-1234 Lorem Ipsum
		 ⇒ https://gitlab.example.net/my/project/merge_requests/6
		--------------------------------------------------------------------------------

		   🏷  [Review] [My Team]                       🚧 Draft               (↣ main)

		   ✅ 2/2   👍 1  👎 1       Threads: 1/2       CI: ❌       Can be merged: ❌
		EOF
    )"

    # ------------------------------------------------------------------------------------------------------------------

    mr='{
        "title": "Feature/XY-1234 Lorem Ipsum", "web_url":"https://gitlab.example.net/my/project/merge_requests/6",
        "labels":["Testing","My Team"], "target_branch": "main", "upvotes": 2, "downvotes": 0, "merge_status": "can_be_merged",
        "head_pipeline": {"status":"success", "web_url":"https://example.net/ci/1"}
    }'
    approvals='true 0/0'
    threads='1	unresolved:false	note_id:1
2	unresolved:false	note_id:2'

    run mr_status_block "$mr" "$mr" "$approvals" "$threads"
    assert_output "$(cat <<- EOF
		--------------------------------------------------------------------------------
		 Feature/XY-1234 Lorem Ipsum
		 ⇒ https://gitlab.example.net/my/project/merge_requests/6
		--------------------------------------------------------------------------------

		   🏷  [Testing] [My Team]                                             (↣ main)

		   👍 2  👎 0                Threads: 2/2       CI: ✔       Can be merged: ✔
		EOF
    )"

    # ------------------------------------------------------------------------------------------------------------------

    mr='{
        "title": "Feature/XY-1234 Lorem Ipsum", "web_url":"https://gitlab.example.net/my/project/merge_requests/6",
        "labels":["Accepted","My Team"], "target_branch": "main", "upvotes": 2, "downvotes": 0, "state":"merged"
    }'
    approvals='true 0/0'
    threads="\n"

    run mr_status_block "$mr" "$mr" "$approvals" "$threads"
    assert_output "$(cat <<- EOF
		--------------------------------------------------------------------------------
		 Feature/XY-1234 Lorem Ipsum
		 ⇒ https://gitlab.example.net/my/project/merge_requests/6
		--------------------------------------------------------------------------------

		   🏷  [Accepted] [My Team]                                            (↣ main)

		   👍 2  👎 0                                                      Merged
		EOF
    )"
}

@test "Identifies first commit line in description" {

    # Initial format
    mr_description="XY-1234 Some Feature {1}
## Commits {2}
* **431561fff0 XY-1234 Donec id justo ut nisi** {3}
* **472c4a8cb9 XY-1234 Pellentesque** {4}"
    run mr_description_first_commit_line "$mr_description"
    assert_output "3"

    # Proper merge request commit links format
    mr_description="XY-1234 Some Feature {1}
## Commits {2}
* **[a2678c36f3](https://${GITLAB_DOMAIN}/my/project/-/merge_requests/22/diffs?commit_id=a2678c36f307caedd20a11ecc6b3dc615b2bf7ed) XY-1234 Donec id justo ut nisi** {3}
* **[97278d35aa](https://${GITLAB_DOMAIN}/my/project/-/merge_requests/22/diffs?commit_id=97278d35aa2e62677bff1adf0a1824f0a0357ee3) XY-1234 Pellentesque** {4}"
    run mr_description_first_commit_line "$mr_description"
    assert_output "3"
}

@test "Identifies last commit line in description" {
    indent="  "

    # Standard commit list - Last description line is commit
    # Initial format
    mr_description="XY-1234 Some Feature {1}
## Commits {2}
* **431561fff0 XY-1234 Donec id justo ut nisi** {3}
* **472c4a8cb9 XY-1234 Pellentesque** {4}"
    run mr_description_last_commit_line "$mr_description"
    assert_output "4"

    # Proper merge request commit links format
    mr_description="XY-1234 Some Feature {1}
## Commits {2}
* **[a2678c36f3](https://${GITLAB_DOMAIN}/my/project/-/merge_requests/22/diffs?commit_id=a2678c36f307caedd20a11ecc6b3dc615b2bf7ed) XY-1234 Donec id justo ut nisi** {3}
* **[97278d35aa](https://${GITLAB_DOMAIN}/my/project/-/merge_requests/22/diffs?commit_id=97278d35aa2e62677bff1adf0a1824f0a0357ee3) XY-1234 Pellentesque** {4}"
    run mr_description_last_commit_line "$mr_description"
    assert_output "4"


    # Standard commit list - Last non-empty description line is commit
    # Initial format
    mr_description="XY-1234 Some Feature {1}
## Commits {2}
* **431561fff0 XY-1234 Donec id justo ut nisi** {3}
* **472c4a8cb9 XY-1234 Pellentesque** {4}

"
    run mr_description_last_commit_line "$mr_description"
    assert_output "4"
    # Proper merge request commit links format
    mr_description="XY-1234 Some Feature {1}
## Commits {2}
* **[a2678c36f3](https://${GITLAB_DOMAIN}/my/project/-/merge_requests/22/diffs?commit_id=a2678c36f307caedd20a11ecc6b3dc615b2bf7ed) XY-1234 Donec id justo ut nisi** {3}
* **[97278d35aa](https://${GITLAB_DOMAIN}/my/project/-/merge_requests/22/diffs?commit_id=97278d35aa2e62677bff1adf0a1824f0a0357ee3) XY-1234 Pellentesque** {4}

"
    run mr_description_last_commit_line "$mr_description"
    assert_output "4"


    # Standard commit list - With additional global description
    # Initial format
    mr_description="XY-1234 Some Feature {1}
## Commits {2}
* **431561fff0 XY-1234 Donec id justo ut nisi** {3}
* **472c4a8cb9 XY-1234 Pellentesque** {4}


Some Description {7}"
    run mr_description_last_commit_line "$mr_description"
    assert_output "4"
    # Proper merge request commit links format
    mr_description="XY-1234 Some Feature {1}
## Commits {2}
* **[a2678c36f3](https://${GITLAB_DOMAIN}/my/project/-/merge_requests/22/diffs?commit_id=a2678c36f307caedd20a11ecc6b3dc615b2bf7ed) XY-1234 Donec id justo ut nisi** {3}
* **[97278d35aa](https://${GITLAB_DOMAIN}/my/project/-/merge_requests/22/diffs?commit_id=97278d35aa2e62677bff1adf0a1824f0a0357ee3) XY-1234 Pellentesque** {4}


Some Description {7}"
    run mr_description_last_commit_line "$mr_description"
    assert_output "4"


    # Commits with extended description - Last description line is commit extended description
    # Initial format
    mr_description="XY-1234 Some Feature {1}
## Commits {2}
* **431561fff0 XY-1234 Donec id justo ut nisi** {3}
${indent}Curabitur eleifend elit in pellentesque dapibus. {4}
* **472c4a8cb9 XY-1234 Pellentesque** {5}
${indent}Duis bibendum lacus id lacus bibendum gravida. {6}
${indent}
${indent}Pellentesque vulputate risus id posuere malesuada. {8}"
    run mr_description_last_commit_line "$mr_description"
    assert_output "8"
    # Proper merge request commit links format
    mr_description="XY-1234 Some Feature {1}
## Commits {2}
* **431561fff0 XY-1234 Donec id justo ut nisi** {3}
${indent}Curabitur eleifend elit in pellentesque dapibus. {4}
* **472c4a8cb9 XY-1234 Pellentesque** {5}
${indent}Duis bibendum lacus id lacus bibendum gravida. {6}
${indent}
${indent}Pellentesque vulputate risus id posuere malesuada. {8}"
    run mr_description_last_commit_line "$mr_description"
    assert_output "8"

    # (same with non-indented empty lines in extended description: {7})
    # Initial format
    mr_description="XY-1234 Some Feature {1}
## Commits {2}
* **431561fff0 XY-1234 Donec id justo ut nisi** {3}
${indent}Curabitur eleifend elit in pellentesque dapibus. {4}
* **472c4a8cb9 XY-1234 Pellentesque** {5}
${indent}Duis bibendum lacus id lacus bibendum gravida. {6}

${indent}Pellentesque vulputate risus id posuere malesuada. {8}"
    run mr_description_last_commit_line "$mr_description"
    assert_output "8"
    # Proper merge request commit links format
    mr_description="XY-1234 Some Feature {1}
## Commits {2}
* **[a2678c36f3](https://${GITLAB_DOMAIN}/my/project/-/merge_requests/22/diffs?commit_id=a2678c36f307caedd20a11ecc6b3dc615b2bf7ed) XY-1234 Donec id justo ut nisi** {3}
${indent}Curabitur eleifend elit in pellentesque dapibus. {4}
* **[97278d35aa](https://${GITLAB_DOMAIN}/my/project/-/merge_requests/22/diffs?commit_id=97278d35aa2e62677bff1adf0a1824f0a0357ee3) XY-1234 Pellentesque** {4}
${indent}Duis bibendum lacus id lacus bibendum gravida. {6}

${indent}Pellentesque vulputate risus id posuere malesuada. {8}"
    run mr_description_last_commit_line "$mr_description"
    assert_output "8"


    # Commits with extended description - Last non-empty description line is commit extended description
    # Initial format
    mr_description="XY-1234 Some Feature {1}
## Commits {2}
* **431561fff0 XY-1234 Donec id justo ut nisi** {3}
${indent}Curabitur eleifend elit in pellentesque dapibus. {4}
* **472c4a8cb9 XY-1234 Pellentesque** {5}
${indent}Duis bibendum lacus id lacus bibendum gravida. {6}
${indent}
${indent}Pellentesque vulputate risus id posuere malesuada. {8}


"
    run mr_description_last_commit_line "$mr_description"
    assert_output "8"
    # Proper merge request commit links format
        mr_description="XY-1234 Some Feature {1}
## Commits {2}
* **[a2678c36f3](https://${GITLAB_DOMAIN}/my/project/-/merge_requests/22/diffs?commit_id=a2678c36f307caedd20a11ecc6b3dc615b2bf7ed) XY-1234 Donec id justo ut nisi** {3}
${indent}Curabitur eleifend elit in pellentesque dapibus. {4}
* **[97278d35aa](https://${GITLAB_DOMAIN}/my/project/-/merge_requests/22/diffs?commit_id=97278d35aa2e62677bff1adf0a1824f0a0357ee3) XY-1234 Pellentesque** {4}
${indent}Duis bibendum lacus id lacus bibendum gravida. {6}
${indent}
${indent}Pellentesque vulputate risus id posuere malesuada. {8}


"
    run mr_description_last_commit_line "$mr_description"
    assert_output "8"

    # (same with trailing indented line in extended description {9})
    # Initial format
    mr_description="XY-1234 Some Feature {1}
## Commits {2}
* **431561fff0 XY-1234 Donec id justo ut nisi** {3}
${indent}Curabitur eleifend elit in pellentesque dapibus. {4}
* **472c4a8cb9 XY-1234 Pellentesque** {5}
${indent}Duis bibendum lacus id lacus bibendum gravida. {6}
${indent}
${indent}Pellentesque vulputate risus id posuere malesuada. {8}
${indent}


"
    run mr_description_last_commit_line "$mr_description"
    assert_output "9"
    # Proper merge request commit links format
    mr_description="XY-1234 Some Feature {1}
## Commits {2}
* **[a2678c36f3](https://${GITLAB_DOMAIN}/my/project/-/merge_requests/22/diffs?commit_id=a2678c36f307caedd20a11ecc6b3dc615b2bf7ed) XY-1234 Donec id justo ut nisi** {3}
${indent}Curabitur eleifend elit in pellentesque dapibus. {4}
* **[97278d35aa](https://${GITLAB_DOMAIN}/my/project/-/merge_requests/22/diffs?commit_id=97278d35aa2e62677bff1adf0a1824f0a0357ee3) XY-1234 Pellentesque** {4}
${indent}Duis bibendum lacus id lacus bibendum gravida. {6}
${indent}
${indent}Pellentesque vulputate risus id posuere malesuada. {8}
${indent}


"
    run mr_description_last_commit_line "$mr_description"
    assert_output "9"

    # (same with non-indented empty lines in extended description {9-10})
    # Initial format
    mr_description="XY-1234 Some Feature {1}
## Commits {2}
* **431561fff0 XY-1234 Donec id justo ut nisi** {3}
${indent}Curabitur eleifend elit in pellentesque dapibus. {4}
* **472c4a8cb9 XY-1234 Pellentesque** {5}
${indent}Duis bibendum lacus id lacus bibendum gravida. {6}

${indent}Pellentesque vulputate risus id posuere malesuada. {8}


"
    run mr_description_last_commit_line "$mr_description"
    assert_output "8"
    # Proper merge request commit links format
    mr_description="XY-1234 Some Feature {1}
## Commits {2}
* **[a2678c36f3](https://${GITLAB_DOMAIN}/my/project/-/merge_requests/22/diffs?commit_id=a2678c36f307caedd20a11ecc6b3dc615b2bf7ed) XY-1234 Donec id justo ut nisi** {3}
${indent}Curabitur eleifend elit in pellentesque dapibus. {4}
* **[97278d35aa](https://${GITLAB_DOMAIN}/my/project/-/merge_requests/22/diffs?commit_id=97278d35aa2e62677bff1adf0a1824f0a0357ee3) XY-1234 Pellentesque** {4}
${indent}Duis bibendum lacus id lacus bibendum gravida. {6}

${indent}Pellentesque vulputate risus id posuere malesuada. {8}


"
    run mr_description_last_commit_line "$mr_description"
    assert_output "8"


    # Commits with extended description - With additional global description
    # Initial format
    mr_description="XY-1234 Some Feature {1}
## Commits {2}
* **431561fff0 XY-1234 Donec id justo ut nisi** {3}
${indent}Curabitur eleifend elit in pellentesque dapibus. {4}
* **472c4a8cb9 XY-1234 Pellentesque** {5}
${indent}Duis bibendum lacus id lacus bibendum gravida. {6}
${indent}
${indent}Pellentesque vulputate risus id posuere malesuada. {8}
Some global description. {9}"
    run mr_description_last_commit_line "$mr_description"
    assert_output "8"
    # Proper merge request commit links format
    mr_description="XY-1234 Some Feature {1}
## Commits {2}
* **[a2678c36f3](https://${GITLAB_DOMAIN}/my/project/-/merge_requests/22/diffs?commit_id=a2678c36f307caedd20a11ecc6b3dc615b2bf7ed) XY-1234 Donec id justo ut nisi** {3}
${indent}Curabitur eleifend elit in pellentesque dapibus. {4}
* **[97278d35aa](https://${GITLAB_DOMAIN}/my/project/-/merge_requests/22/diffs?commit_id=97278d35aa2e62677bff1adf0a1824f0a0357ee3) XY-1234 Pellentesque** {4}
${indent}Duis bibendum lacus id lacus bibendum gravida. {6}
${indent}
${indent}Pellentesque vulputate risus id posuere malesuada. {8}
Some global description. {9}"
    run mr_description_last_commit_line "$mr_description"
    assert_output "8"

    # (same with additional blank lines before global description)
    # Initial format
    mr_description="XY-1234 Some Feature {1}
## Commits {2}
* **431561fff0 XY-1234 Donec id justo ut nisi** {3}
${indent}Curabitur eleifend elit in pellentesque dapibus. {4}
* **472c4a8cb9 XY-1234 Pellentesque** {5}
${indent}Duis bibendum lacus id lacus bibendum gravida. {6}
${indent}
${indent}Pellentesque vulputate risus id posuere malesuada. {8}


Nulla eget sem semper, scelerisque enim nec, pellentesque nisi. {11}
${indent}With unrelated indent {12}"
    run mr_description_last_commit_line "$mr_description"
    assert_output "8"
    # Proper merge request commit links format
        mr_description="XY-1234 Some Feature {1}
## Commits {2}
* **[a2678c36f3](https://${GITLAB_DOMAIN}/my/project/-/merge_requests/22/diffs?commit_id=a2678c36f307caedd20a11ecc6b3dc615b2bf7ed) XY-1234 Donec id justo ut nisi** {3}
${indent}Curabitur eleifend elit in pellentesque dapibus. {4}
* **[97278d35aa](https://${GITLAB_DOMAIN}/my/project/-/merge_requests/22/diffs?commit_id=97278d35aa2e62677bff1adf0a1824f0a0357ee3) XY-1234 Pellentesque** {4}
${indent}Duis bibendum lacus id lacus bibendum gravida. {6}
${indent}
${indent}Pellentesque vulputate risus id posuere malesuada. {8}


Nulla eget sem semper, scelerisque enim nec, pellentesque nisi. {11}
${indent}With unrelated indent {12}"
    run mr_description_last_commit_line "$mr_description"
    assert_output "8"

    # (same with non-indented empty lines in extended description, and indented lines global description)
    # Initial format
    mr_description="XY-1234 Some Feature {1}
## Commits {2}
* **431561fff0 XY-1234 Donec id justo ut nisi** {3}
${indent}Curabitur eleifend elit in pellentesque dapibus. {4}
* **472c4a8cb9 XY-1234 Pellentesque** {5}
${indent}Duis bibendum lacus id lacus bibendum gravida. {6}

${indent}Pellentesque vulputate risus id posuere malesuada. {8}


Nulla eget sem semper, scelerisque enim nec, pellentesque nisi. {11}
* Fusce vitae sem {12}
${indent}non mi egestas dignissim {13}
Nunc vitae {14}"
    run mr_description_last_commit_line "$mr_description"
    assert_output "8"
    # Proper merge request commit links format
    mr_description="XY-1234 Some Feature {1}
## Commits {2}
* **[a2678c36f3](https://${GITLAB_DOMAIN}/my/project/-/merge_requests/22/diffs?commit_id=a2678c36f307caedd20a11ecc6b3dc615b2bf7ed) XY-1234 Donec id justo ut nisi** {3}
${indent}Curabitur eleifend elit in pellentesque dapibus. {4}
* **[97278d35aa](https://${GITLAB_DOMAIN}/my/project/-/merge_requests/22/diffs?commit_id=97278d35aa2e62677bff1adf0a1824f0a0357ee3) XY-1234 Pellentesque** {4}
${indent}Duis bibendum lacus id lacus bibendum gravida. {6}

${indent}Pellentesque vulputate risus id posuere malesuada. {8}


Nulla eget sem semper, scelerisque enim nec, pellentesque nisi. {11}
* Fusce vitae sem {12}
${indent}non mi egestas dignissim {13}
Nunc vitae {14}"
    run mr_description_last_commit_line "$mr_description"
    assert_output "8"
}

@test "Inserts new commits in description" {
    mr_description="# Title
## Commits
* **plop**..
End"
    new_commits="new commit"
    last_commit_line=3

    run mr_description_insert_new_commits "$mr_description" "$new_commits" "$last_commit_line"
    assert_output "$(cat <<-EOF
		# Title
		## Commits
		* **plop**..
		* **new commit**..
		End
		EOF
    )"

    mr_description="# Title
## Commits
* **plop**"
    new_commits="new commit"
    last_commit_line=3

    run mr_description_insert_new_commits "$mr_description" "$new_commits" "$last_commit_line"
    assert_output "$(cat <<-EOF
		# Title
		## Commits
		* **plop**
		* **new commit**..
		EOF
    )"
    # Note: mr_description_insert_new_commits does not handle trailing new line anymore.
    # Commit lines are normalized by substition regexes in mr_update
}

@test "Updates MR description with new commits in new section" {
    load "test_helper/gitlab-mock-mr-description-simple.bash"
    load "test_helper/gitlab-mock-mr-update.bash"

    GIT_MR_UPDATE_NEW_SECTION=1

    local c1sha=$(short_sha "Feature test - 1")
    local c2sha=$(short_sha "Feature test - 2"); local c2href=$(sha_link "$c2sha")
    local c3sha=$(short_sha "Feature test - 3"); local c3href=$(sha_link "$c3sha")

    # Ensure remote branch is up-to-date
    git-push gitlab feature/AB-123-test-feature --force

    run mr_update <<< 'n'
    assert_output "$(cat <<- EOF


		[AB-123 Test issue](https://mycompany.example.net/browse/AB-123)

		## Commits

		* **${c1sha}🔗✔ Feature test - descr 1**..
		* **${c2sha}🔗 Feature test - descr 2**..
		* **${c3sha}🔗 Feature test - descr 3**..

		--------------------------------------------------------------------------------

		   upgraded links: 1 🔗
		EOF
    )"

    # Amend last commit
    git reset --hard HEAD~1
    git commit --allow-empty -m "Feature test - 3" -m "Updated"
    c3shaNew=$(git rev-parse --short HEAD)

    # Add new commits
    git commit --allow-empty -m "Feature test - 4" -m "With extended message too"
    c4shaNew=$(git rev-parse --short HEAD)
    git commit --allow-empty -m "Feature test - 5"
    c5shaNew=$(git rev-parse --short HEAD)

    # Ensure remote branch is up-to-date
    git-push gitlab feature/AB-123-test-feature --force

    run mr_update <<< 'n'
    assert_output "$(cat <<- EOF


		[AB-123 Test issue](https://mycompany.example.net/browse/AB-123)

		## Commits

		* **${c1sha}🔗✔ Feature test - descr 1**..
		* **${c2sha}🔗 Feature test - descr 2**..
		* **${c3shaNew}🔗 Feature test - descr 3**..

		## Update

		* **${c4shaNew}🔗 Feature test - 4**..
		* **${c5shaNew}🔗 Feature test - 5**..

		--------------------------------------------------------------------------------

		   upgraded links: 1 🔗
		  updated commits: 1
		      new commits: 2

		EOF
    )"

    GIT_MR_UPDATE_NEW_SECTION_NAME="Cleanup & refactor"
    run mr_update <<< 'n'
    assert_output "$(cat <<- EOF


		[AB-123 Test issue](https://mycompany.example.net/browse/AB-123)

		## Commits

		* **${c1sha}🔗✔ Feature test - descr 1**..
		* **${c2sha}🔗 Feature test - descr 2**..
		* **${c3shaNew}🔗 Feature test - descr 3**..

		## Cleanup & refactor

		* **${c4shaNew}🔗 Feature test - 4**..
		* **${c5shaNew}🔗 Feature test - 5**..

		--------------------------------------------------------------------------------

		   upgraded links: 1 🔗
		  updated commits: 1
		      new commits: 2

		EOF
    )"

    # Reset repo for next tests
    git reset --hard "$c3sha"
    git-push gitlab feature/AB-123-test-feature --force
}

@test "Updates MR description with new commits with extended description" {
    load "test_helper/gitlab-mock-mr-description-extended.bash"
    load "test_helper/gitlab-mock-mr-update.bash"

    GIT_MR_EXTENDED=1
    GIT_MR_UPDATE_NEW_SECTION=

    local c1sha=$(short_sha "Feature test - 1")
    local c2sha=$(short_sha "Feature test - 2"); local c2href=$(sha_link "$c2sha")
    local c3sha=$(short_sha "Feature test - 3"); local c3href=$(sha_link "$c3sha")

    # Ensure remote branch is up-to-date
    git-push gitlab feature/AB-123-test-feature --force

    run mr_update <<< 'n'
    local empty=""
    assert_output "$(cat <<-EOF


		[AB-123 Test issue](https://mycompany.example.net/browse/AB-123)

		## Commits

		* **${c1sha}🔗✔ Feature test - descr 1**..
		* **${c2sha}🔗 Feature test - descr 2**..
		  This is my second commit..
		* **${c3sha}🔗 Feature test - descr 3**..
		  This is my third commit..
		  ${empty}
		  With an extended description

		--------------------------------------------------------------------------------

		   upgraded links: 1 🔗

		EOF
    )"

    # Amend last commit
    git reset --hard HEAD~1
    git commit --allow-empty -m "Feature test - 3" -m "Updated"
    local c3shaNew=$(git rev-parse --short HEAD)

    # Add new commits
    git commit --allow-empty -m "Feature test - 4" -m "With extended message too"
    local c4shaNew=$(git rev-parse --short HEAD)
    git commit --allow-empty -m "Feature test - 5"
    local c5shaNew=$(git rev-parse --short HEAD)

    # Ensure remote branch is up-to-date
    git-push gitlab feature/AB-123-test-feature --force

    run mr_update <<< 'n'
    local empty=""
    assert_output "$(cat <<-EOF


		[AB-123 Test issue](https://mycompany.example.net/browse/AB-123)

		## Commits

		* **${c1sha}🔗✔ Feature test - descr 1**..
		* **${c2sha}🔗 Feature test - descr 2**..
		  This is my second commit..
		* **${c3shaNew}🔗 Feature test - descr 3**..
		  This is my third commit..
		  ${empty}
		  With an extended description
		* **${c4shaNew}🔗 Feature test - 4**..
		  With extended message too..
		* **${c5shaNew}🔗 Feature test - 5**..

		--------------------------------------------------------------------------------

		   upgraded links: 1 🔗
		  updated commits: 1
		      new commits: 2

		EOF
    )"

    # Reset repo for next tests
    git reset --hard "$c3sha"
    git-push gitlab feature/AB-123-test-feature --force
}

@test "Warns before updating merge request when remote branch is not up-to-date" {
    load "test_helper/gitlab-mock-mr-description-simple.bash"
    load "test_helper/gitlab-mock-mr-update.bash"

    local c1sha=$(short_sha "Feature test - 1")
    local c2sha=$(short_sha "Feature test - 2"); local c2href=$(sha_link "$c2sha")
    local c3sha=$(short_sha "Feature test - 3"); local c3href=$(sha_link "$c3sha")

    # Ensure remote branch is up-to-date
    git-push gitlab feature/AB-123-test-feature --force

    # Add new commit
    git commit --allow-empty -m "Feature test - 4"
    local c4shaNew=$(git rev-parse --short HEAD)

    run mr_update <<< 'n'
    assert_output "$(cat <<- EOF


		[AB-123 Test issue](https://mycompany.example.net/browse/AB-123)

		## Commits

		* **${c1sha}🔗✔ Feature test - descr 1**..
		* **${c2sha}🔗 Feature test - descr 2**..
		* **${c3sha}🔗 Feature test - descr 3**..
		* **${c4shaNew}🔗 Feature test - 4**..

		--------------------------------------------------------------------------------

		   upgraded links: 1 🔗
		      new commits: 1

		Remote branch on gitlab is not up-to-date with local branch feature/AB-123-test-feature.
		EOF
    )"

    run mr_update <<< 'y'
    assert_output "$(cat <<- EOF


		[AB-123 Test issue](https://mycompany.example.net/browse/AB-123)

		## Commits

		* **${c1sha}🔗✔ Feature test - descr 1**..
		* **${c2sha}🔗 Feature test - descr 2**..
		* **${c3sha}🔗 Feature test - descr 3**..
		* **${c4shaNew}🔗 Feature test - 4**..

		--------------------------------------------------------------------------------

		   upgraded links: 1 🔗
		      new commits: 1

		Remote branch on gitlab is not up-to-date with local branch feature/AB-123-test-feature.
		Updating merge request...OK
		EOF
    )"

    # Reset repo for next tests
    git reset --hard "$c3sha"
}

@test "Does not update MR target if target branch does not exist on remote" {
    load "test_helper/gitlab-mock-mr-description-simple.bash"
    load "test_helper/gitlab-mock-mr-update.bash"

    local c1sha=$(short_sha "Feature test - 1")
    local c2sha=$(short_sha "Feature test - 2"); local c2href=$(sha_link "$c2sha")
    local c3sha=$(short_sha "Feature test - 3"); local c3href=$(sha_link "$c3sha")

    # Create new branch which will be detected as base
    local baseCommit=$(short_sha "Feature base - 3")
    git branch newbase "$baseCommit"

    # Add new commit
    git commit --allow-empty -m "Feature test - 4"
    local c4shaNew=$(git rev-parse --short HEAD)

    # Ensure remote branch is up-to-date
    git-push gitlab feature/AB-123-test-feature --force

    run mr_update <<< 'y'$'\n''y'
    assert_output --partial "$(cat <<-EOF
		--------------------------------------------------------------------------------

		   upgraded links: 1 🔗
		      new commits: 1

		Target branch 'newbase' does not exist on remote.
		EOF
    )"

    # Reset repo for next tests
    git reset --hard "$c3sha"
    git-push gitlab feature/AB-123-test-feature --force
    git branch -d newbase
}

@test "Updates MR description with warning about misplaced target" {
    load "test_helper/gitlab-mock-mr-description-simple.bash"
    load "test_helper/gitlab-mock-mr-update.bash"

    local c1sha=$(short_sha "Feature test - 1")
    local c2sha=$(short_sha "Feature test - 2"); local c2href=$(sha_link "$c2sha")
    local c3sha=$(short_sha "Feature test - 3"); local c3href=$(sha_link "$c3sha")

    # simulate commit ref base (when 1st possible merge base is used)
    local baseCommit=$(short_sha "Feature base - 3")
    git_base_branch() {
        echo "$baseCommit"
    }

    # Add new commit
    git commit --allow-empty -m "Feature test - 4"
    local c4shaNew=$(git rev-parse --short HEAD)

    # Ensure remote branch is up-to-date
    git-push gitlab feature/AB-123-test-feature --force

    run mr_update <<< 'y'
    assert_output --partial "$(cat <<-EOF
		--------------------------------------------------------------------------------

		   upgraded links: 1 🔗
		      new commits: 1


		Guessed target '$baseCommit' is a commit reference.
		(No local base branch found, first possible merge base used.)
		You might need to rebase your branch.
		EOF
    )"

    # Reset repo for next tests
    git reset --hard "$c3sha"
    git-push gitlab feature/AB-123-test-feature --force
}

@test "Updates MR description with warning about unknown commits" {
    load "test_helper/gitlab-mock-mr-description-simple.bash"
    load "test_helper/gitlab-mock-mr-update.bash"

    local c1sha=$(short_sha "Feature test - 1")
    local c2sha=$(short_sha "Feature test - 2"); local c2href=$(sha_link "$c2sha")
    local c3sha=$(short_sha "Feature test - 3"); local c3href=$(sha_link "$c3sha")

    # Create new branch which will be detected as base
    baseCommit=$(short_sha "Feature base - 3")
    git branch newbase "$c1sha"

    run mr_update <<< 'y'
    assert_output --partial "$(cat <<-EOF
		--------------------------------------------------------------------------------

		   upgraded links: 1 🔗
		  updated commits: 2

		  unknown commits: 1

		Current description has 1 more commit(s) than found in branch, given target 'newbase'.
		You might want to check your target branch or update the description manually.
		EOF
    )"

    git branch -d newbase
}

@test "Replaces whole commit list in MR description" {
    load "test_helper/gitlab-mock-mr-description-extended.bash"
    load "test_helper/gitlab-mock-mr-update.bash"

    GIT_MR_EXTENDED=1
    GIT_MR_REPLACE_COMMITS=1

    local c1sha=$(short_sha "Feature test - 1")
    local c2sha=$(short_sha "Feature test - 2"); local c2href=$(sha_link "$c2sha")
    local c3sha=$(short_sha "Feature test - 3"); local c3href=$(sha_link "$c3sha")

    # Amend first commit
    git reset --soft "$c1sha"
    git commit --amend --allow-empty -m "Feature test - new 1" -m "Updated"
    local c1shaNew=$(git rev-parse --short HEAD)

    # Add new commit
    git commit --allow-empty -m "Feature test - new 2" -m "With extended message too"
    local c2shaNew=$(git rev-parse --short HEAD)

    # Ensure remote branch is up-to-date
    git-push gitlab feature/AB-123-test-feature --force

    run mr_update <<< 'n'
    local empty=""
    assert_output "$(cat <<-EOF


		[AB-123 Test issue](https://mycompany.example.net/browse/AB-123)

		## Commits

		* **${c1shaNew}🔗 Feature test - new 1**..
		  Updated..
		* **${c2shaNew}🔗 Feature test - new 2**..
		  With extended message too..

		--------------------------------------------------------------------------------

		      new commits: 2

		EOF
    )"

    # Reset repo for next tests
    git reset --hard "$c3sha"
    git-push gitlab feature/AB-123-test-feature --force
}

################################################################################
# Merge request labels utility functions

@test "Replaces labels" {
    run replace_labels ""     ""     "";     assert_output ""
    run replace_labels ""     "toto" "";     assert_output ""
    run replace_labels ""     ""     "toto"; assert_output "toto"
    run replace_labels "toto" ""     "";     assert_output "toto"

    run replace_labels "toto,tata" "titi" "";     assert_output "toto,tata"
    run replace_labels "toto,tata" ""     "titi"; assert_output "toto,tata,titi"

    run replace_labels "toto,tata,titi" "toto" "tutu"; assert_output "tata,titi,tutu"
    run replace_labels "toto,tata,titi" "tata" "tutu"; assert_output "toto,titi,tutu"
    run replace_labels "toto,tata,titi" "titi" "tutu"; assert_output "toto,tata,tutu"
    run replace_labels "toto,tata,titi" "plop" "tutu"; assert_output "toto,tata,titi,tutu"

    run replace_labels "toto,ta ta,titi" "plop,ta ta,plouf" "tutu,pouet"; assert_output "toto,titi,tutu,pouet"

    run replace_labels "to to,ta ta,ti ti" "to to,plop"    "ta ta,pouet"; assert_output "ti ti,ta ta,pouet"
    run replace_labels "to to,ta ta,ti ti" ",,plop,ta ta," "pouet,ti ti"; assert_output "to to,pouet,ti ti"
}

@test "Compares labels" {
    run labels_differ;                         assert_failure
    run labels_differ "aaa"         "aaa";     assert_failure
    run labels_differ "aaa,bbb"     "aaa,bbb"; assert_failure

    run labels_differ "aaa,bbb"     "";            assert_success
    run labels_differ "aaa,bbb"     "aaa,bbb,ccc"; assert_success
    run labels_differ "aaa,ccc"     "aaa,bbb,ccc"; assert_success
    run labels_differ "aaa,bbb,ccc" "aaa,bbb";     assert_success
    run labels_differ "aaa,bbb,ccc" "aaa,ccc";     assert_success
    run labels_differ ""            "aaa,bbb,ccc"; assert_success

    run labels_differ "aaa,bbb,ccc" "aaa,bbb,ccc"; assert_failure
    run labels_differ "aaa,bbb,ccc" "aaa,ccc,bbb"; assert_failure
    run labels_differ "aaa,bbb,ccc" "bbb,aaa,ccc"; assert_failure
    run labels_differ "aaa,bbb,ccc" "bbb,ccc,aaa"; assert_failure
    run labels_differ "aaa,bbb,ccc" "ccc,aaa,bbb"; assert_failure
    run labels_differ "aaa,bbb,ccc" "ccc,bbb,aaa"; assert_failure

    run labels_differ "aaa,bbb,ccc" "ccc,bbb,aaa,ccc"; assert_failure

    run labels_differ "aaa,b bb,cc c" ",,cc c,b bb,aaa,,cc c"; assert_failure
}

@test "Identifies workflow-specific labels" {
    GITLAB_IP_LABELS="wip1,wip2"
    GITLAB_CR_LABELS="cr1,cr2"
    GITLAB_QA_LABELS="qa1,qa2"
    GITLAB_OK_LABELS="ok1,ok2"

    run is_status_label "wip1"; assert_success; run is_status_ip_label "wip1"; assert_success
    run is_status_label "wip2"; assert_success; run is_status_ip_label "wip2"; assert_success
    run is_status_label "cr1";  assert_success; run is_status_cr_label "cr1";  assert_success
    run is_status_label "cr2";  assert_success; run is_status_cr_label "cr2";  assert_success
    run is_status_label "qa1";  assert_success; run is_status_qa_label "qa1";  assert_success
    run is_status_label "qa2";  assert_success; run is_status_qa_label "qa2";  assert_success
    run is_status_label "ok1";  assert_success; run is_status_ok_label "ok1";  assert_success
    run is_status_label "ok2";  assert_success; run is_status_ok_label "ok2";  assert_success

    run is_status_ip_label "cr1";  assert_failure
    run is_status_cr_label "qa1";  assert_failure
    run is_status_qa_label "ok1";  assert_failure
    run is_status_ok_label "wip1"; assert_failure

    run is_status_label "test";  assert_failure
    run is_status_label "zcr12"; assert_failure
    run is_status_label "zqa12"; assert_failure
    run is_status_label "zok12"; assert_failure

    # ----------------------

    GITLAB_IP_LABELS=""
    run is_status_label "wip1"; assert_failure; run is_status_ip_label "wip1"; assert_failure #
    run is_status_label "cr1";  assert_success; run is_status_cr_label "cr1";  assert_success
    run is_status_label "qa1";  assert_success; run is_status_qa_label "qa1";  assert_success
    run is_status_label "ok1";  assert_success; run is_status_ok_label "ok1";  assert_success

    run is_status_ip_label "cr1"; assert_failure
    run is_status_ip_label "qa1"; assert_failure
    run is_status_ip_label "ok1"; assert_failure
    GITLAB_IP_LABELS="wip1,wip2"

    GITLAB_CR_LABELS=""
    run is_status_label "wip1"; assert_success; run is_status_ip_label "wip1"; assert_success
    run is_status_label "cr1";  assert_failure; run is_status_cr_label "cr1";  assert_failure #
    run is_status_label "qa1";  assert_success; run is_status_qa_label "qa1";  assert_success
    run is_status_label "ok1";  assert_success; run is_status_ok_label "ok1";  assert_success

    run is_status_cr_label "wip1"; assert_failure
    run is_status_cr_label "qa1";  assert_failure
    run is_status_cr_label "ok1";  assert_failure
    GITLAB_CR_LABELS="cr1,cr2"

    GITLAB_QA_LABELS=""
    run is_status_label "wip1"; assert_success; run is_status_ip_label "wip1"; assert_success
    run is_status_label "cr1";  assert_success; run is_status_cr_label "cr1";  assert_success
    run is_status_label "qa1";  assert_failure; run is_status_qa_label "qa1";  assert_failure #
    run is_status_label "ok1";  assert_success; run is_status_ok_label "ok1";  assert_success

    run is_status_qa_label "wip1"; assert_failure
    run is_status_qa_label "cr1";  assert_failure
    run is_status_qa_label "ok1";  assert_failure
    GITLAB_QA_LABELS="qa1,qa2"

    GITLAB_OK_LABELS=""
    run is_status_label "wip1"; assert_success; run is_status_ip_label "wip1"; assert_success
    run is_status_label "cr1";  assert_success; run is_status_cr_label "cr1";  assert_success
    run is_status_label "qa1";  assert_success; run is_status_qa_label "qa1";  assert_success
    run is_status_label "ok1";  assert_failure; run is_status_ok_label "ok1";  assert_failure #

    run is_status_ok_label "wip1"; assert_failure
    run is_status_ok_label "cr1";  assert_failure
    run is_status_ok_label "qa1";  assert_failure
    GITLAB_OK_LABELS="ok1,ok2"
}

@test "Formats labels" {
    run mr_format_labels ""
    assert_output ""

    run mr_format_labels "abc 1"
    assert_output "[abc 1]"

    run mr_format_labels "abc 1,def-2"
    assert_output "[abc 1] [def-2]"
}

################################################################################
# Merge request menu utility functions

@test "Searches projects" {
    load "test_helper/gitlab-mock-search.bash"

    run gitlab_projects
    assert_success
    refute_output --partial '"path_with_namespace": "public-group/project-a"' # not a member
    refute_output --partial '"path_with_namespace": "public-group/project-b"' # not a member
    assert_output --partial '"path_with_namespace": "private-group/project-c"'
    assert_output --partial '"path_with_namespace": "private-group/project-d"'

    GITLAB_PROJECTS_LIMIT_MEMBER=0

    run gitlab_projects
    assert_success
    assert_output --partial '"path_with_namespace": "public-group/project-a"' # no membership filtering
    assert_output --partial '"path_with_namespace": "public-group/project-b"' # no membership filtering
    assert_output --partial '"path_with_namespace": "private-group/project-c"'
    assert_output --partial '"path_with_namespace": "private-group/project-d"'

    GITLAB_PROJECTS_LIMIT_MEMBER=1
}

@test "Searches MRs across projects filtering by group when configured" {
    load "test_helper/gitlab-mock-search.bash"

    run gitlab_merge_requests_search
    assert_failure "search_term required"


    run gitlab_merge_requests_search AB-123
    assert_success
    assert_output --partial "public-group/proj-C/-/merge_requests/31"
    assert_output --partial "public-group/proj-A/-/merge_requests/11"
    assert_output --partial "private-group/proj-B/-/merge_requests/21"
    refute_output --partial "private-group/proj-D/-/merge_requests/41" # closed


    GITLAB_MR_LIMIT_GROUP=private-group

    run gitlab_merge_requests_search AB-123
    assert_success

    refute_output --partial "public-group/proj-C/-/merge_requests/31" # not in private group
    refute_output --partial "public-group/proj-A/-/merge_requests/11" # not in private group
    assert_output --partial "private-group/proj-B/-/merge_requests/21"
    refute_output --partial "private-group/proj-D/-/merge_requests/41" # closed

    unset GITLAB_MR_LIMIT_GROUP
}

@test "Searches MRs across projects to build menu" {
    load "test_helper/gitlab-mock-menu.bash"

    run mr_menu XY-789
    assert_output "$(cat <<- EOF
		No merge requests found for 'XY-789'.
		EOF
    )"

    run mr_menu
    assert_output "$(cat <<- EOF

		================================================================================
		 AB-123 (3 merge requests)
		================================================================================

		## Menu

		* Project C: [MR 31 title](https://gitlab.example.net/proj-C/-/merge_requests/31)
		* Project A: [MR 11 title](https://gitlab.example.net/proj-A/-/merge_requests/11)
		* Project B: [MR 21 title](https://gitlab.example.net/proj-B/-/merge_requests/21)

		--------------------------------------------------------------------------------
		EOF
    )"
}

@test "Builds editable menu content" {
    test_menu_items='{"iid":31,"title":"MR 31 title","web_url":"https://gitlab.example.net/proj-C/-/merge_requests/31","state":"opened","project_id":3,"project_name":"Project C"}
{"iid":11,"title":"MR 11 title","web_url":"https://gitlab.example.net/proj-A/-/merge_requests/11","state":"opened","project_id":1,"project_name":"Project A"}
{"iid":21,"title":"MR 21 title","web_url":"https://gitlab.example.net/proj-B/-/merge_requests/21","state":"opened","project_id":2,"project_name":"Project B"}'

    run mr_menu_editable_content "$test_menu_items"
    assert_output "$(cat <<- EOF

		* Project C: [MR 31 title](https://gitlab.example.net/proj-C/-/merge_requests/31)
		* Project A: [MR 11 title](https://gitlab.example.net/proj-A/-/merge_requests/11)
		* Project B: [MR 21 title](https://gitlab.example.net/proj-B/-/merge_requests/21)


		<!------------------------------------------------------------------------->
		<!--                                                                     -->
		<!--  Here you can rearrange menu items and add additional description.  -->
		<!--                                                                     -->
		<!--  Current menu item will be highlighted in each merge request,       -->
		<!--  provided you keep the markdown list & link format.                 -->
		<!--                                                                     -->
		<!--  If you remove everything, menu update will be aborted.             -->
		<!--                                                                     -->
		<!------------------------------------------------------------------------->
		EOF
    )"
}

@test "Prints menu title" {
    run mr_menu_print_title "AB-123" "" "" "$(echo -e "a\nb\nc")"
    assert_output "$(cat <<- EOF
		================================================================================
		 AB-123 (3 merge requests)
		================================================================================
		EOF
    )"

    run mr_menu_print_title "AB-123" "" "" "$(echo -e "a\nb\nc")" 1
    assert_output "$(cat <<- EOF
		================================================================================
		 AB-123 (merge request 1/3)
		================================================================================
		EOF
    )"

    run mr_menu_print_title "AB-123" "My Issue" "https://example.com/AB-123" "$(echo -e "a\nb\nc")"
    assert_output "$(cat <<- EOF
		================================================================================
		 AB-123 My Issue  (3 merge requests)
		 ⇒ https://example.com/AB-123
		================================================================================
		EOF
    )"
}

@test "Prints menu status" {
    load "test_helper/gitlab-mock-menu.bash"
    load "test_helper/jira-mock.bash"

    GIT_MR_MENU_STATUS_SHOW=title

    run mr_menu_status "AB-123" "$(mr_menu_merge_requests "AB-123")"
    assert_output "$(cat <<-EOF

		================================================================================
		 AB-123 This is an issue  (3 merge requests)
		 ⇒ https://mycompany.example.net/browse/AB-123
		================================================================================

		* Project C: MR 31 title
		  ⇒ https://gitlab.example.net/proj-C/-/merge_requests/31

		   🏷  [Accepted]                                                      (↣ main)

		   👍 3  👎 0                Threads: 1/2       CI: ⏰       Can be merged: ✔


		* Project A: MR 11 title
		  ⇒ https://gitlab.example.net/proj-A/-/merge_requests/11

		   🏷  [QA]                                                            (↣ main)

		   ✅ 2/2   👍 2  👎 0                          CI: ⏱       Can be merged: ✔


		* Project B: MR 21 title
		  ⇒ https://gitlab.example.net/proj-B/-/merge_requests/21

		   🏷  [Review]                                                        (↣ main)

		   ☑️ 1/2   👍 0  👎 1                          CI: ❌       Can be merged: ❌
		EOF
    )"

    GIT_MR_MENU_STATUS_SHOW=both
    GIT_MR_MENU_STATUS_TITLE_BRANCH_SEPARATOR="  "

    run mr_menu_status "AB-123" "$(mr_menu_merge_requests "AB-123")"
    assert_output "$(cat <<-EOF

		================================================================================
		 AB-123 This is an issue  (3 merge requests)
		 ⇒ https://mycompany.example.net/browse/AB-123
		================================================================================

		* Project C: MR 31 title  ( feature/branch-31)
		  ⇒ https://gitlab.example.net/proj-C/-/merge_requests/31

		   🏷  [Accepted]                                                      (↣ main)

		   👍 3  👎 0                Threads: 1/2       CI: ⏰       Can be merged: ✔


		* Project A: MR 11 title  ( feature/branch-11)
		  ⇒ https://gitlab.example.net/proj-A/-/merge_requests/11

		   🏷  [QA]                                                            (↣ main)

		   ✅ 2/2   👍 2  👎 0                          CI: ⏱       Can be merged: ✔


		* Project B: MR 21 title  ( feature/branch-21)
		  ⇒ https://gitlab.example.net/proj-B/-/merge_requests/21

		   🏷  [Review]                                                        (↣ main)

		   ☑️ 1/2   👍 0  👎 1                          CI: ❌       Can be merged: ❌
		EOF
    )"
}

@test "Highlights current MR link in edited menu" {

    test_menu_content='## Menu

### Main feature

  * Project A: [MR 11 title](https://gitlab.example.net/proj-A/-/merge_requests/11)
  * Project Bee: [MR 21 title](https://gitlab.example.net/proj-B/-/merge_requests/21) (/!\ WIP)

### Documentation

  * Project Doc: [MR 31 title](https://gitlab.example.net/proj-C/-/merge_requests/31)

--------------------------------------------------------------------------------'

    run mr_menu_highlight_current "$test_menu_content" "https://gitlab.example.net/proj-B/-/merge_requests/21"
    assert_output "$(cat <<- EOF
		## Menu

		### Main feature

		  * Project A: [MR 11 title](https://gitlab.example.net/proj-A/-/merge_requests/11)
		  * **Project Bee: [MR 21 title](https://gitlab.example.net/proj-B/-/merge_requests/21) (/!\ WIP)**

		### Documentation

		  * Project Doc: [MR 31 title](https://gitlab.example.net/proj-C/-/merge_requests/31)

		--------------------------------------------------------------------------------
		EOF
    )"
}

@test "Replaces menu in MR descriptions" {

    local menu_content="## Menu
* New Menu item 1
* New Menu item 2
--------------------------------------------------------------------------------"

    # *** Replace menu in description ***
    mr_description="# [AB-123 Test feature](https://example.net/AB-123)

This is an example.

--------------------------------------------------------------------------------

## Menu

* Old Menu item 1

--------------------------------------------------------------------------------

## Commits

* Lorem
* Ipsum

--------------------------------------------------------------------------------"

    run mr_menu_replace_description "$mr_description" "$menu_content"
    assert_output "# [AB-123 Test feature](https://example.net/AB-123)

This is an example.

--------------------------------------------------------------------------------

## Menu
* New Menu item 1
* New Menu item 2
--------------------------------------------------------------------------------

## Commits

* Lorem
* Ipsum

--------------------------------------------------------------------------------"

    # *** Insert menu in description ***
    mr_description="# [AB-123 Test feature](https://example.net/AB-123)

This is an example without menu.

## Commits

* Lorem
* Ipsum"

    run mr_menu_replace_description "$mr_description" "$menu_content"
    assert_output "# [AB-123 Test feature](https://example.net/AB-123)

## Menu
* New Menu item 1
* New Menu item 2
--------------------------------------------------------------------------------

This is an example without menu.

## Commits

* Lorem
* Ipsum"

    # *** Insert menu in empty description ***

    mr_description=""
    run mr_menu_replace_description "$mr_description" "$menu_content"
    assert_output "
## Menu
* New Menu item 1
* New Menu item 2
--------------------------------------------------------------------------------"

    # *** Insert menu in minimal description ***

    mr_description="This is a merge request."
    run mr_menu_replace_description "$mr_description" "$menu_content"
    assert_output "This is a merge request.

## Menu
* New Menu item 1
* New Menu item 2
--------------------------------------------------------------------------------"

    mr_description="This is a merge request
paragraph."
    run mr_menu_replace_description "$mr_description" "$menu_content"
    assert_output "This is a merge request
paragraph.

## Menu
* New Menu item 1
* New Menu item 2
--------------------------------------------------------------------------------"

    mr_description="This is
a merge request
longer
paragraph."
    run mr_menu_replace_description "$mr_description" "$menu_content"
    assert_output "This is
a merge request
longer
paragraph.

## Menu
* New Menu item 1
* New Menu item 2
--------------------------------------------------------------------------------"

}

@test "Cleans up edited menu" {
    run mr_menu_edit_read_file ../../test-menu-contents.md
    assert_output "$(cat <<-EOF
		## Menu

		Content line: first

		Content line: before comments
		Content line: after comments

		* Menu item 1
		* Menu item 2
		  * [Menu item 3](https://example.net)

		    Content line ddd

		Content line eee

		--------------------------------------------------------------------------------
		EOF
    )"

    run mr_menu_edit_read_file ../../test-empty-menu-contents.md
    assert_output ""
}

@test "Allows menu edit before update" {
    load "test_helper/gitlab-mock-menu.bash"

    VISUAL="../../fake-menu-edit.sh"
    run mr_menu edit "AB-123" <<< 'y
y
n'

    assert_output --partial "$(cat <<-EOF
		================================================================================
		 AB-123 (merge request 1/3)
		================================================================================

		--------------------------------------------------------------------------------
		 Project C: MR 31 title
		--------------------------------------------------------------------------------

		# Merge request with only title

		## Menu

		* Fake edited menu
		* For test

		--------------------------------------------------------------------------------

		--------------------------------------------------------------------------------
		Updating merge request...OK
		EOF
    )"

    assert_output --partial "$(cat <<-EOF
		================================================================================
		 AB-123 (merge request 2/3)
		================================================================================

		--------------------------------------------------------------------------------
		 Project A: MR 11 title
		--------------------------------------------------------------------------------

		# Lorem ipsum

		## Menu

		* Fake edited menu
		* For test

		--------------------------------------------------------------------------------

		Merge request with description
		and previous menu to be updated.

		--------------------------------------------------------------------------------
		Updating merge request...OK
		EOF
    )"

    assert_output --partial "$(cat <<-EOF
		================================================================================
		 AB-123 (merge request 3/3)
		================================================================================

		--------------------------------------------------------------------------------
		 Project B: MR 21 title
		--------------------------------------------------------------------------------

		# Deserunt laborum nibh

		## Menu

		* Fake edited menu
		* For test

		--------------------------------------------------------------------------------

		Merge request with description,
		but missing menu.

		--------------------------------------------------------------------------------
		EOF
    )"

    assert_output --partial "2 merge requests updated"

    refute [ -e '.git/MR_MENU_EDITMSG.md' ]
}

@test "Aborts menu update when edited menu is empty" {
    load "test_helper/gitlab-mock-menu.bash"

    VISUAL="../../fake-menu-edit-empty.sh"
    GIT_MR_YES=1

    run mr_menu edit "AB-123"
    assert_output "Empty menu, aborting."
}

################################################################################
# Status change functions

@test "Toggles MR labels & Jira ticket status" {
    load "test_helper/gitlab-mock-transition.bash"

    labels_output() {
        cat <<- EOF

			Do you want to update the merge request labels to "${1}"? -> yes
			Updating merge request labels... OK
			EOF
    }

    jira_output() {
        cat <<- EOF

			Do you want to update the Jira ticket status to "${1}"? -> yes
			Updating Jira ticket status... OK
			EOF
    }

    draft_output() {
        cat <<- EOF

			Do you want to set draft status? -> yes
			Setting draft status... OK
			EOF
    }

    undraft_output() {
        cat <<- EOF

			Do you want to resolve draft status? -> yes
			Resolving draft status... OK
			EOF
    }

    separator=$'\n'"--------------------------------------------------------------------------------"
    tab=$'\t'

    GIT_MR_YES=1

    # In Progress ------------------------------------------------------------------

    git_mr_mock_labels='"Review","Testing","Accepted","My Team"'

    GITLAB_IP_LABELS="" # labels can be empty
    run mr_transition "IP"
    assert_output "$(cat <<-EOF
		${separator}
		$(labels_output "My Team")
		$(draft_output)
		$(jira_output "In Progress")
		EOF
    )"

    GITLAB_IP_LABELS="WIP"
    run mr_transition "IP"
    assert_output "$(cat <<- EOF
		${separator}
		$(labels_output "My Team,WIP")
		$(draft_output)
		$(jira_output "In Progress")
		EOF
    )"

    # Code Review ------------------------------------------------------------------

    git_mr_mock_labels='"WIP","Testing","Accepted","My Team"'

    GITLAB_CR_LABELS="" # labels can be empty
    run mr_transition "CR"
    assert_output "$(cat <<- EOF
		${separator}
		$(labels_output "My Team")
		$(jira_output "Code Review")
		EOF
    )"

    GITLAB_CR_LABELS="Review"
    run mr_transition "CR"
    assert_output "$(cat <<- EOF
		${separator}
		$(labels_output "My Team,Review")
		$(jira_output "Code Review")
		EOF
    )"

    # Quality Assurance ------------------------------------------------------------

    git_mr_mock_labels='"WIP","Review","Accepted","My Team"'

    GITLAB_QA_LABELS="" # labels can be empty
    run mr_transition "QA"
    assert_output "$(cat <<- EOF
		${separator}
		$(labels_output "My Team")
		$(jira_output "Quality Assurance")
		EOF
    )"

    GITLAB_QA_LABELS="Testing"
    run mr_transition "QA"
    assert_output "$(cat <<- EOF
		${separator}
		$(labels_output "My Team,Testing")
		$(jira_output "Quality Assurance")
		EOF
    )"

    # Accepted ---------------------------------------------------------------------

    git_mr_mock_labels='"WIP","Review","Testing","My Team"'
    git_mr_mock_title="Draft: My MR"

    GITLAB_OK_LABELS="" # labels can be empty
    run mr_transition "OK"
    assert_output "$(cat <<-EOF
		${separator}
		$(labels_output "My Team")
		$(undraft_output)
		$(jira_output "Accepted")
		EOF
    )"

    GITLAB_OK_LABELS="Accepted"
    run mr_transition "OK"
    assert_output "$(cat <<-EOF
		${separator}
		$(labels_output "My Team,Accepted")
		$(undraft_output)
		$(jira_output "Accepted")
		EOF
    )"

    # No label change --------------------------------------------------------------

    git_mr_mock_labels='"Testing","My Team"' # no label change
    run mr_transition "QA"
    assert_output "$(cat <<- EOF
		${separator}
		$(jira_output "Quality Assurance")
		EOF
    )"

    # No Jira transition -----------------------------------------------------------

    JIRA_OK_ID= # no Jira transition
    run mr_transition "OK"
    assert_output "$(cat <<-EOF
		${separator}
		$(labels_output "My Team,Accepted")
		$(undraft_output)

		Do you want to update the Jira ticket status to "Accepted"? -> yes
		Set JIRA_OK_ID to be able to update Jira status.
		Available Jira transitions:
		${tab}1${tab}"TODO"                   ${tab}-> TODO                   ${tab}[To Do]
		${tab}2${tab}"In Progress"            ${tab}-> In Progress            ${tab}[In Progress]
		${tab}3${tab}"Code Review"            ${tab}-> Code Review            ${tab}[In Progress]
		${tab}4${tab}"QA"                     ${tab}-> QA                     ${tab}[In Progress]
		${tab}5${tab}"Ready to go"            ${tab}-> Ready to go            ${tab}[In Progress]
		${tab}6${tab}"Delivered"              ${tab}-> Delivered              ${tab}[Done]
		EOF
    )"
}

################################################################################
# Merge request top-level functions

@test "Provides pre-commit-msg hook" {

    # standard .git directory

    run git commit --allow-empty -m "Test message 1"
    assert_output "[feature/AB-123-test-feature $(git rev-parse --short HEAD)] Test message 1"

    run git-mr hook
    assert [ -f ".git/hooks/prepare-commit-msg" ]

    run git commit --allow-empty -m "Test message 2"
    assert_line "Prefixing message with issue code: AB-123"
    assert_line "[feature/AB-123-test-feature $(git rev-parse --short HEAD)] AB-123 Test message 2"

    # standard .git directory - teardown
    git reset --hard HEAD~2
    rm -f .git/hooks/prepare-commit-msg

    # submodule

    cd "${BATS_TEST_DIRNAME}/data" || exit
    git init subrepo
    cd subrepo
    git commit --allow-empty -m "Sub commit"
    cd ../repo
    git -c protocol.file.allow=always submodule add ../subrepo sub
    cd sub
    configure-git-repo
    git switch -c feature/XY-345-test

    run git commit --allow-empty -m "Sub message 1"
    assert_output "[feature/XY-345-test $(git rev-parse --short HEAD)] Sub message 1"

    run git-mr hook
    assert [ -f "../.git/modules/sub/hooks/prepare-commit-msg" ]

    run git commit --allow-empty -m "Sub message 2"
    assert_line "Prefixing message with issue code: XY-345"
    assert_line "[feature/XY-345-test $(git rev-parse --short HEAD)] XY-345 Sub message 2"

    # submodule - teardown
    cd "${BATS_TEST_DIRNAME}/data" || exit
    cd repo; git submodule deinit -f sub; cd ..
    rm -rf subrepo repo/sub repo/.gitmodules repo/.git/modules
}

@test "pre-commit-msg hook can be skipped" {
    # setup
    git-mr hook

    run git commit --allow-empty -m "Test prefixed message"
    assert_line "Prefixing message with issue code: AB-123"
    assert_line "[feature/AB-123-test-feature $(git rev-parse --short HEAD)] AB-123 Test prefixed message"

    SKIP=aaa,prepare-commit-msg,zzz run git commit --allow-empty -m "Test unprefixed message"
    refute_line "Prefixing message with issue code: AB-123"
    assert_line "[feature/AB-123-test-feature $(git rev-parse --short HEAD)] Test unprefixed message"

    # teardown
    git reset --hard HEAD~2
    rm -f .git/hooks/prepare-commit-msg
}
