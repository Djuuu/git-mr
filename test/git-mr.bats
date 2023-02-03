#!/usr/bin/env bats

load "test_helper/bats-support/load"
load "test_helper/bats-assert/load"

################################################################################
# Setup

setup_file() {
    export LANG=C.UTF-8 # ensure tests handle UTF-8 properly

    export GIT_MR_NO_COLORS=1
    export GIT_MR_NO_TERMINAL_LINK=1

    export JIRA_CODE_PATTERN="[A-Z]{2,3}-[0-9]+"
    export JIRA_INSTANCE=
    export JIRA_USER=
    export GITLAB_DOMAIN="gitlab.example.net"
    export GITLAB_TOKEN="test"

    export MD_BR='..' # for easier visualization

    cd "${BATS_TEST_DIRNAME}" || exit

    mkdir data && cd data || exit

    git init --bare remote
    git init --bare gitlab
    git init repo && cd repo || exit
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
    # Source git-mr to load functions
    . "${BATS_TEST_DIRNAME}"/../git-mr >&3

    cd "${BATS_TEST_DIRNAME}/data" || exit
    cd repo
    git switch feature/AB-123-test-feature
}

################################################################################
# Wrappers & utilities

git() {
    command git \
        -c init.defaultBranch=main \
        -c user.email=test@example.com \
        -c user.name=Test \
        -c init.templatedir= \
        "$@"
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

################################################################################
# Git functions

@test "Fails outside a Git repository" {
    cd /tmp
    run git-mr
    assert_failure
}

@test "Uses GNU commands" {
    run sed --version
    assert_success
    assert_output --partial "GNU sed"

    run grep --version
    assert_success
    assert_output --partial "GNU grep"
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
    assert_failure

    git switch main
    run git-mr base
    assert_failure
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
    assert_failure
    assert_output "Not on any branch"

    run git_check_branches test main
    assert_failure
    assert_output "Branch 'test' does not exist"

    run git_check_branches main epic/big-feature
    assert_failure
    assert_output "On default branch"

    run git_check_branches master epic/big-feature
    assert_failure
    assert_output "On default branch"

    run git_check_branches feature/base ""
    assert_failure
    assert_output "Unable to determine target branch"
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

    run git_commit_extended "$sha2"

    assert_output "$(cat <<- EOF
		* **${sha2} Feature test - 2**..
		This is my second commit
		EOF
    )"
}

@test "Makes title from branch" {
    run git_titlize_branch feature/AB-123-some_branch_title
    assert_output "Feature/AB-123 Some branch title"
}

################################################################################
# Misc. utilities

@test "Exits with error" {
    run exit_error 3 "Nope!"
    assert_failure
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
    run regex_escape '[] \/ $ * . ^ []'
    assert_output '\[\] \\\/ \$ \* \. \^ \[\]'
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
		two
		three
		EOF
    )"
    assert_output "$(cat <<- EOF
		* **one**..
		* **two**..
		* **three**..
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
    assert_failure

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
    assert_failure
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

    run gitlab_project_request 'test' 'POST' '{"test":1}'
    assert_success
    assert_output "gitlab_request('projects/my%2Fproject/test' 'POST' '{\"test\":1}')"
}

@test "Warns for Gitlab API request errors" {
    run gitlab_check_error '{"error":"failed"}'
    assert_output "$(cat <<- EOF

		Gitlab error:
		  {"error":"failed"}
		ko
		EOF
    )"

    run gitlab_check_error '{"message":"failed"}'
    assert_output "$(cat <<- EOF

		Gitlab error:
		  {"message":"failed"}
		ko
		EOF
    )"
}

@test "Determines new merge request URL" {
    GITLAB_DEFAULT_LABELS="Label A,Label C"
    gitlab_project_request() {
        [[ $1 = "labels" ]] &&
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
    gitlab_project_request() {
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
            *) return ;;
        esac
    }

    mr_summary=$(gitlab_merge_request_summary "feature/xy-1234-lorem-ipsum")

    run gitlab_extract_iid   "$mr_summary"; assert_output 123
    run gitlab_extract_url   "$mr_summary"; assert_output "https://gitlab.example.net/mr/123"
    run gitlab_extract_title "$mr_summary"; assert_output "Draft: Feature/XY-1234 Lorem Ipsum"

    mr_summary=$(gitlab_merge_request_summary "feature/nope")

    run gitlab_extract_iid   "$mr_summary"; assert_output ''
    run gitlab_extract_url   "$mr_summary"; assert_output ''
    run gitlab_extract_title "$mr_summary"; assert_output ''

    mr_summary=$(gitlab_merge_request_summary "nope")

    run gitlab_extract_iid   "$mr_summary"; assert_output ''
    run gitlab_extract_url   "$mr_summary"; assert_output ''
    run gitlab_extract_title "$mr_summary"; assert_output ''
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

    run gitlab_extract_project_url "$mr_url"
    assert_output "some%2Fproject"
}

@test "Extracts Gitlab merge request threads" {
    gitlab_request() {
        [[ $1 = "projects/test/merge_requests/123/discussions?per_page=100&page=1" ]] &&
            echo '[
                {"id": "n1","notes": [{"id": 11},{"id": 12,"resolvable": false}]},
                {"id": "n2","notes": [{"id": 21},{"id": 22,"resolvable": true, "resolved": false}]},
                {"id": "n3","notes": [{"id": 31},{"id": 32,"resolvable": true, "resolved": true}]}
            ]'
    }

    run gitlab_merge_request_threads "test" "123"
    assert_output "$(cat <<- EOF
		n2	unresolved:true	note_id:22
		n3	unresolved:false	note_id:null
		EOF
    )"
}

@test "Fetches default Gitlab label ids" {
    GITLAB_DEFAULT_LABELS="Label A,Label C"
    gitlab_project_request() {
        [[ $1 = "labels" ]] &&
            echo '[{"id":1,"name":"Label A"},{"id":2,"name":"Label B"},{"id":3,"name":"Label C"}]'
    }

    run gitlab_default_label_ids
    assert_output "$(cat <<- EOF
		1
		3
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
}

@test "Generates MR title from Jira issue title" {
    load "test_helper/jira-mock.bash"

    run mr_title
    assert_output "[AB-123 This is an issue](https://mycompany.example.net/browse/AB-123)"
}

@test "Generates MR description from commits" {
    load "test_helper/jira-mock.bash"

    c1sha=$(short_sha "Feature test - 1")
    c2sha=$(short_sha "Feature test - 2")
    c3sha=$(short_sha "Feature test - 3")

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

    empty=""
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
    threads='1	unresolved:false	note_id:1
2	unresolved:true	note_id:2'

    run mr_status_block "1" "$mr" "" "" "$threads"
    assert_output "$(cat <<- EOF
		--------------------------------------------------------------------------------
		 Feature/XY-1234 Lorem Ipsum
		 ⇒ https://gitlab.example.net/my/project/merge_requests/6
		--------------------------------------------------------------------------------

		   🏷  [Review] [My Team]                       🚧 Draft               (↣ main)

		   👍  1   👎  1     Resolved threads: 1/2      CI: ❌       Can be merged: ❌
		EOF
    )"

    # ------------------------------------------------------------------------------------------------------------------

    mr='{
        "title": "Feature/XY-1234 Lorem Ipsum", "web_url":"https://gitlab.example.net/my/project/merge_requests/6",
        "labels":["Testing","My Team"], "target_branch": "main", "upvotes": 2, "downvotes": 0, "merge_status": "can_be_merged",
        "head_pipeline": {"status":"success", "web_url":"https://example.net/ci/1"}
    }'
    threads='1	unresolved:false	note_id:1
2	unresolved:false	note_id:2'

    run mr_status_block "1" "$mr" "" "" "$threads"
    assert_output "$(cat <<- EOF
		--------------------------------------------------------------------------------
		 Feature/XY-1234 Lorem Ipsum
		 ⇒ https://gitlab.example.net/my/project/merge_requests/6
		--------------------------------------------------------------------------------

		   🏷  [Testing] [My Team]                                             (↣ main)

		   👍  2   👎  0     Resolved threads: 2/2      CI: ✔       Can be merged: ✔
		EOF
    )"

    # ------------------------------------------------------------------------------------------------------------------

    mr='{
        "title": "Feature/XY-1234 Lorem Ipsum", "web_url":"https://gitlab.example.net/my/project/merge_requests/6",
        "labels":["Accepted","My Team"], "target_branch": "main", "upvotes": 2, "downvotes": 0, "state":"merged"
    }'
    threads="\n"

    run mr_status_block "1" "$mr" "" "" "$threads"
    assert_output "$(cat <<- EOF
		--------------------------------------------------------------------------------
		 Feature/XY-1234 Lorem Ipsum
		 ⇒ https://gitlab.example.net/my/project/merge_requests/6
		--------------------------------------------------------------------------------

		   🏷  [Accepted] [My Team]                                            (↣ main)

		   👍  2   👎  0                                                   Merged
		EOF
    )"
}

@test "Updates MR description with new commits in new section" {
    load "test_helper/gitlab-mock-mr.bash"

    GIT_MR_EXTENDED=
    GIT_MR_UPDATE_NEW_SECTION=1

    c1sha=$(short_sha "Feature test - 1")
    c2sha=$(short_sha "Feature test - 2")
    c3sha=$(short_sha "Feature test - 3")

    # Amend last commit
    git reset --hard HEAD~1
    git commit --allow-empty -m "Feature test - 3" -m "Updated"
    c3shaNew=$(git rev-parse --short HEAD)

    # Add new commits
    git commit --allow-empty -m "Feature test - 4" -m "With extended message too"
    c4shaNew=$(git rev-parse --short HEAD)

    git commit --allow-empty -m "Feature test - 5"
    c5shaNew=$(git rev-parse --short HEAD)

    run mr_update <<< 'n'

    assert_output "$(cat <<- EOF

		--------------------------------------------------------------------------------
		 My MR
		 ⇒ https://gitlab.example.net/some/project/-/merge_requests/1
		--------------------------------------------------------------------------------

		[AB-123 Test issue](https://mycompany.example.net/browse/AB-123)

		## Commits

		* **${c1sha} Feature test - 1**..
		* **${c2sha} Feature test - 2**..
		* **${c3shaNew} Feature test - 3**

		## Update

		* **${c4shaNew} Feature test - 4**..
		* **${c5shaNew} Feature test - 5**..

		--------------------------------------------------------------------------------

		  updated commits: 1
		      new commits: 2


		--------------------------------------------------------------------------------
		EOF
    )"

    git reset --hard "$c3sha"
}

@test "Updates MR description with new commits with extended description" {
    load "test_helper/gitlab-mock-mr-extended.bash"

    GIT_MR_EXTENDED=1
    GIT_MR_UPDATE_NEW_SECTION=

    c1sha=$(short_sha "Feature test - 1")
    c2sha=$(short_sha "Feature test - 2")
    c3sha=$(short_sha "Feature test - 3")

    # Amend last commit
    git reset --hard HEAD~1
    git commit --allow-empty -m "Feature test - 3" -m "Updated"
    c3shaNew=$(git rev-parse --short HEAD)

    # Add new commits
    git commit --allow-empty -m "Feature test - 4" -m "With extended message too"
    c4shaNew=$(git rev-parse --short HEAD)

    git commit --allow-empty -m "Feature test - 5"
    c5shaNew=$(git rev-parse --short HEAD)

    run mr_update <<< 'n'

    empty=""
    assert_output "$(cat <<-EOF

		--------------------------------------------------------------------------------
		 My MR
		 ⇒ https://gitlab.example.net/some/project/-/merge_requests/1
		--------------------------------------------------------------------------------

		[AB-123 Test issue](https://mycompany.example.net/browse/AB-123)

		## Commits

		* **${c1sha} Feature test - 1**..
		* **${c2sha} Feature test - 2**..
		  This is my second commit..
		* **${c3shaNew} Feature test - 3**..
		  This is my third commit..
		  ${empty}
		  With an extended description
		* **${c4shaNew} Feature test - 4**..
		  With extended message too..
		* **${c5shaNew} Feature test - 5**..

		--------------------------------------------------------------------------------

		  updated commits: 1
		      new commits: 2


		--------------------------------------------------------------------------------
		EOF
    )"

    git reset --hard "$c3sha"
}

################################################################################
# Merge request labels utility functions

@test "Replaces labels" {
    run replace_labels "toto,tata,titi" "tata" "tutu"
    assert_output "toto,titi,tutu"

    run replace_labels "toto,tata" "tata,toto"
    assert_output ""

    run replace_labels "toto,tata" "nope" "plop,pouet"
    assert_output "toto,tata,plop,pouet"
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

    run labels_differ "aaa,bbb,ccc" ",,ccc,bbb,aaa,,ccc"; assert_failure
}

@test "Identifies workflow-specific labels" {
    GITLAB_IP_LABELS="wip1,wip2"
    GITLAB_CR_LABELS="cr1,cr2"
    GITLAB_QA_LABELS="qa1,qa2"
    GITLAB_OK_LABELS="ok1,ok2"

    run is_status_label "wip1"; assert_output "wip1"
    run is_status_label "wip2"; assert_output "wip2"
    run is_status_label "cr1";  assert_output "cr1"
    run is_status_label "cr2";  assert_output "cr2"
    run is_status_label "qa1";  assert_output "qa1"
    run is_status_label "qa2";  assert_output "qa2"
    run is_status_label "ok1";  assert_output "ok1"
    run is_status_label "ok2";  assert_output "ok2"

    run is_status_ip_label "wip1"; assert_output "wip1"; run is_status_ip_label "cr1";  assert_output ""
    run is_status_cr_label "cr1";  assert_output "cr1";  run is_status_cr_label "qa1";  assert_output ""
    run is_status_qa_label "qa1";  assert_output "qa1";  run is_status_qa_label "ok1";  assert_output ""
    run is_status_ok_label "ok1";  assert_output "ok1";  run is_status_ok_label "wip1"; assert_output ""

    run is_status_label "test"; assert_output ""
    run is_status_label "zcr12"; assert_output ""
    run is_status_label "zqa12"; assert_output ""
    run is_status_label "zok12"; assert_output ""
}

@test "Formats labels" {
    run mr_format_labels "abc-1,def-2"
    assert_output "[abc-1] [def-2]"
}

################################################################################
# Merge request menu utility functions

@test "Searches MRs across projects to build menu" {
    load "test_helper/gitlab-mock-menu.bash"

    run mr_menu

    assert_output "$(cat <<- EOF

		================================================================================
		 AB-123 (3 merge requests)
		================================================================================

		## Menu

		* Project C: [MR 31 title](https://example.net/31)
		* Project A: [MR 11 title](https://example.net/11)
		* Project B: [MR 21 title](https://example.net/21)

		--------------------------------------------------------------------------------
		EOF
    )"
}

@test "Replaces menu in MR descriptions" {

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

    menu_content="## Menu

* New Menu item 1
* New Menu item 2

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


    mr_description="# [AB-123 Test feature](https://example.net/AB-123)

This is an example without menu.

## Commits

* Lorem
* Ipsum"

    menu_content="## Menu

* New Menu item 1
* New Menu item 2

--------------------------------------------------------------------------------"

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
}

################################################################################
# Status change functions

@test "Toggles MR labels & Jira ticket status" {
    load "test_helper/gitlab-mock-toggle-status.bash"

    GIT_MR_YES=1

    GITLAB_IP_LABELS="" # labels can be empty for a given step
    GIT_MR_MOCK_LABELS='"Review","Testing","Accepted","My Team"'
    run mr_ip
    assert_output "$(cat <<- EOF

		--------------------------------------------------------------------------------

		Do you want to update the merge request labels to "My Team"? -> yes
		Updating merge request labels... OK

		Do you want to update the Jira ticket status to "In Progress"? -> yes
		Updating Jira ticket status... OK
		EOF
    )"

    GITLAB_IP_LABELS="WIP"
    GIT_MR_MOCK_LABELS='"Review","Testing","Accepted","My Team"'
    run mr_ip
    assert_output "$(cat <<- EOF

		--------------------------------------------------------------------------------

		Do you want to update the merge request labels to "My Team,WIP"? -> yes
		Updating merge request labels... OK

		Do you want to update the Jira ticket status to "In Progress"? -> yes
		Updating Jira ticket status... OK
		EOF
    )"

    GIT_MR_MOCK_LABELS='"WIP","Testing","Accepted","My Team"'
    run mr_cr
    assert_output "$(cat <<- EOF

		--------------------------------------------------------------------------------

		Do you want to update the merge request labels to "My Team,Review"? -> yes
		Updating merge request labels... OK

		Do you want to update the Jira ticket status to "Code Review"? -> yes
		Updating Jira ticket status... OK
		EOF
    )"

    GIT_MR_MOCK_LABELS='"WIP","Review","Accepted","My Team"'
    run mr_qa
    assert_output "$(cat <<- EOF

		--------------------------------------------------------------------------------

		Do you want to update the merge request labels to "My Team,Testing"? -> yes
		Updating merge request labels... OK

		Do you want to update the Jira ticket status to "Quality Assurance"? -> yes
		Updating Jira ticket status... OK
		EOF
    )"

    GIT_MR_MOCK_LABELS='"Testing","My Team"' # no label change
    run mr_qa
    assert_output "$(cat <<- EOF

		--------------------------------------------------------------------------------

		Do you want to update the Jira ticket status to "Quality Assurance"? -> yes
		Updating Jira ticket status... OK
		EOF
    )"

    GIT_MR_MOCK_LABELS='"WIP","Review","Testing","My Team"'
    JIRA_OK_ID= # no Jira transition
    run mr_accept
    tab=$'\t'
    assert_output "$(cat <<-EOF

		--------------------------------------------------------------------------------

		Do you want to update the merge request labels to "My Team,Accepted"? -> yes
		Updating merge request labels... OK

		Do you want to resolve draft status? -> yes
		Resolving draft status... OK

		Do you want to update the Jira ticket status to "Accepted"? -> yes

		Set JIRA_OK_ID to be able to update Jira status

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

    git reset --hard HEAD~2

    # submodule

    cd "${BATS_TEST_DIRNAME}/data" || exit
    git init subrepo
    cd subrepo
    git commit --allow-empty -m "Sub commit"
    cd ../repo
    git -c protocol.file.allow=always submodule add ../subrepo sub
    cd sub
    git switch -c feature/XY-345-test

    run git commit --allow-empty -m "Sub message 1"
    assert_output "[feature/XY-345-test $(git rev-parse --short HEAD)] Sub message 1"

    run git-mr hook
    assert [ -f "../.git/modules/sub/hooks/prepare-commit-msg" ]

    run git commit --allow-empty -m "Sub message 2"
    assert_line "Prefixing message with issue code: XY-345"
    assert_line "[feature/XY-345-test $(git rev-parse --short HEAD)] XY-345 Sub message 2"
}
