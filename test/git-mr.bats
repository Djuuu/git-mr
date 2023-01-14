#!/usr/bin/env bats

load "test_helper/bats-support/load"
load "test_helper/bats-assert/load"

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

setup_file() {
    export JIRA_CODE_PATTERN="[A-Z]{2,3}-[0-9]+"
    export JIRA_INSTANCE=
    export JIRA_USER=
    export GITLAB_DOMAIN=
    export GITLAB_TOKEN=

    export MD_BR='..' # for easier visualization

    cd "${BATS_TEST_DIRNAME}" || exit

    mkdir data && cd data || exit

    git init --bare remote
    git init repo && cd repo || exit
    git remote add origin ../remote

    git switch -c main
    git commit --allow-empty -m "Main 1"
    git commit --allow-empty -m "Main 2"
    git branch feature/local
    git commit --allow-empty -m "Main 3"

    git switch -c epic/big-feature main
    git commit --allow-empty -m "Epic 1"
    git commit --allow-empty -m "Epic 2"
    git commit --allow-empty -m "Epic 3"

    git switch -c feature/base
    git commit --allow-empty -m "Feature base - 1"
    git tag fbc1
    git push origin feature/base # remote branch should not be considered as base
    git commit --allow-empty -m "Feature base - 2" -m "This is my second commit"
    git tag fbc2
    git commit --allow-empty -m "Feature base - 3" -m "This is my third commit" -m "With an extended description"
    git tag fbc3

    git switch -c feature/AB-123-test-feature
    git commit --allow-empty -m "Feature test - 1"
    git tag f1c1
    git push origin feature/AB-123-test-feature # remote branch should not be considered as base
    git commit --allow-empty -m "Feature test - 2" -m "This is my second commit"
    git tag f1c2
    git commit --allow-empty -m "Feature test - 3" -m "This is my third commit" -m "With an extended description"
    git tag f1c3

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
# Git functions

@test "Fails outside a Git repository" {
    cd /tmp
    run git-mr
    assert_failure
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

    git checkout -f "$(git rev-parse HEAD)"
    run git-mr base
    assert_failure

    git switch main
    run git-mr base
    assert_failure
}

@test "Determines remote name" {
    run git_remote
    assert_output origin
}

@test "Checks branch existence" {
    run git_branch_exists feature/base
    assert_success

    run git_branch_exists whatever
    assert_failure
}

@test "Determines default branch" {
    run git_default_branch
    assert_output "main"
}

@test "Checks remote branch existence" {
    run git_remote_branch_exists feature/base
    assert_success

    run git_branch_exists feature/local
    assert_success
    run git_remote_branch_exists feature/local
    assert_failure

    run git_remote_branch_exists feature/whatever
    assert_failure
}

@test "Checks branch coherence" {
    run git_check_branches feature/base main
    assert_success
    assert_output ""

    run git_check_branches "" main
    assert_failure
    assert_output --partial "Not on any branch"

    run git_check_branches test main
    assert_failure
    assert_output --partial "Branch 'test' does not exist"

    run git_check_branches main epic/big-feature
    assert_failure
    assert_output --partial "On default branch"

    run git_check_branches master epic/big-feature
    assert_failure
    assert_output --partial "On default branch"

    run git_check_branches feature/base ""
    assert_failure
    assert_output --partial "Unable to determine target branch"
}

@test "Lists current branch commits" {

    cb1sha=$(git rev-parse --short fbc1)
    cb2sha=$(git rev-parse --short fbc2)
    cb3sha=$(git rev-parse --short fbc3)

    cf1sha=$(git rev-parse --short f1c1)
    cf2sha=$(git rev-parse --short f1c2)
    cf3sha=$(git rev-parse --short f1c3)

    run git_commits

    assert_output "$(cat <<- EOF
		${cf1sha} Feature test - 1
		${cf2sha} Feature test - 2
		${cf3sha} Feature test - 3
		EOF
    )"

    git switch main

    run git_commits "feature/base"

    assert_output "$(cat <<- EOF
		${cb1sha} Feature base - 1
		${cb2sha} Feature base - 2
		${cb3sha} Feature base - 3
		EOF
    )"

    run git_commits "feature/AB-123-test-feature" "epic/big-feature"

    assert_output "$(cat <<- EOF
		${cb1sha} Feature base - 1
		${cb2sha} Feature base - 2
		${cb3sha} Feature base - 3
		${cf1sha} Feature test - 1
		${cf2sha} Feature test - 2
		${cf3sha} Feature test - 3
		EOF
    )"
}

@test "Lists current branch commits with commit body" {
    c1sha=$(git rev-parse --short f1c1)
    c2sha=$(git rev-parse --short f1c2)
    c3sha=$(git rev-parse --short f1c3)

    run git_commits_extended

    assert_output "$(cat <<- EOF
		* **${c1sha} Feature test - 1**..
		* **${c2sha} Feature test - 2**..
		This is my second commit
		* **${c3sha} Feature test - 3**..
		This is my third commit

		With an extended description
		EOF
    )"
}

@test "Shows commit with commit body" {
    c2sha=$(git rev-parse --short f1c2)

    run git_commit_extended "$c2sha"

    assert_output "$(cat <<- EOF
		* **${c2sha} Feature test - 2**..
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

@test "Encodes URL arguments" {
    run urlencode "Some 'string'&\"stuff\" (that needs [to] be) encoded!"
    assert_output "Some%20%27string%27%26%22stuff%22%20%28that%20needs%20%5Bto%5D%20be%29%20encoded%21"
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
    if [ "$(confirm "Do you want to resolve draft status?" <<< "yes")" = "yes" ]; then confirmed=1; else confirmed=0; fi
    assert_equal $confirmed 1

    if [ "$(confirm "Do you want to resolve draft status?" <<< "y")" = "yes" ]; then confirmed=1; else confirmed=0; fi
    assert_equal $confirmed 1

    if [ "$(confirm "Do you want to resolve draft status?" <<< "no")" = "yes" ]; then confirmed=1; else confirmed=0; fi
    assert_equal $confirmed 0

    if [ "$(confirm "Do you want to resolve draft status?" <<< "n")" = "yes" ]; then confirmed=1; else confirmed=0; fi
    assert_equal $confirmed 0

    GIT_MR_YES=1
    if [ "$(confirm "Do you want to resolve draft status?" <<< "n")" = "yes" ]; then confirmed=1; else confirmed=0; fi
    assert_equal $confirmed 1
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

################################################################################
# Markdown formatting

@test "Formats markdown titles" {
    run markdown_title "This is a title"
    assert_output "# This is a title"
}

@test "Formats markdown links" {
    run markdown_link "Link" "https://example.net/"
    assert_output "[Link](https://example.net/)"
}

@test "Formats markdown lists" {
    input=$(echo -e "one\ntwo\nthree")
    expected=$(echo -e "* **one**..\n* **two**..\n* **three**..")

    run markdown_list "$input"
    assert_output "$expected"
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

@test "Extracts MR info from merge request summary" {

    GITLAB_DOMAIN="example.com"
    GITLAB_TOKEN="example"
    gitlab_project_request() {
        case "$1" in
            "merge_requests?state=opened&view=simple&source_branch=feature/xy-1234-lorem-ipsum")
                echo '[{
                    "id": 1234, "iid": 123, "project_id": 12,
                    "title": "Draft: Feature/XY-1234 Lorem Ipsum",
                    "web_url": "https://gitlab.com/mr/123"
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
    run gitlab_extract_url   "$mr_summary"; assert_output "https://gitlab.com/mr/123"
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
    assert_equal "$(gitlab_extract_target_branch "$mr_detail")" 'main'
    assert_equal "$(gitlab_extract_labels "$mr_detail")" 'aaa,b b,c-c'
    assert_equal "$(gitlab_extract_pipeline_status "$mr_detail")" 'success'
    assert_equal "$(gitlab_extract_pipeline_url "$mr_detail")" 'https://example.net/ci'

    mr_detail='{"title":"MR title","state":"merged"}'
    assert_equal "$(gitlab_extract_merge_status "$mr_detail")" 'merged'
}

@test "Extracts Gitlab project part from MR URL" {
    GITLAB_DOMAIN="example.com"
    mr_url="https://example.com/some/project/-/merge_requests/123"

    run gitlab_extract_project_url "$mr_url"
    assert_output "some%2Fproject"
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
    assert_output --partial "Unable to guess issue code"
}

@test "Generates MR title from Jira issue title" {
    load "test_helper/jira-mock.bash"

    run mr_title
    assert_output "[AB-123 This is an issue](https://mycompany.example.net/browse/AB-123)"
}

@test "Generates MR description from commits" {
    load "test_helper/jira-mock.bash"

    c1sha=$(git rev-parse --short f1c1)
    c2sha=$(git rev-parse --short f1c2)
    c3sha=$(git rev-parse --short f1c3)

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

    TERM=xterm-mono # disable colors

    mr='{
        "title": "Draft: Feature/XY-1234 Lorem Ipsum", "web_url":"https://myapp.gitlab.com/my/project/merge_requests/6",
        "labels":["Review","My Team"], "target_branch": "main", "upvotes": 1, "downvotes": 1, "merge_status": "cannot_be_merged",
        "head_pipeline": {"status":"failed", "web_url":"https://example.net/ci/1"}
    }'
    threads='1	unresolved:false	note_id:1
2	unresolved:true	note_id:2'

    run mr_print_status "$mr" "$threads"

    assert_output --partial "
   🏷  [Review] [My Team]                       🚧 Draft               (↣ main)

   👍  1   👎  1     Resolved threads: 1/2      CI: ❌       Can be merged: ❌"

    # ------------------------------------------------------------------------------------------------------------------

    mr='{
        "title": "Feature/XY-1234 Lorem Ipsum", "web_url":"https://myapp.gitlab.com/my/project/merge_requests/6",
        "labels":["Testing","My Team"], "target_branch": "main", "upvotes": 2, "downvotes": 0, "merge_status": "can_be_merged",
        "head_pipeline": {"status":"success", "web_url":"https://example.net/ci/1"}
    }'
    threads='1	unresolved:false	note_id:1
2	unresolved:false	note_id:2'

    run mr_print_status "$mr" "$threads"

    assert_output --partial  "
   🏷  [Testing] [My Team]                                             (↣ main)

   👍  2   👎  0     Resolved threads: 2/2      CI: ✔       Can be merged: ✔"

    # ------------------------------------------------------------------------------------------------------------------

    mr='{
        "title": "Feature/XY-1234 Lorem Ipsum", "web_url":"https://myapp.gitlab.com/my/project/merge_requests/6",
        "labels":["Accepted","My Team"], "target_branch": "main", "upvotes": 2, "downvotes": 0, "state":"merged"
    }'
    threads=

    run mr_print_status "$mr" "$threads"

    assert_output --partial "
   🏷  [Accepted] [My Team]                                            (↣ main)

   👍  2   👎  0                                                   Merged"
}

@test "Updates MR description with new commits in new section" {
    load "test_helper/gitlab-mock-mr.bash"

    TERM=xterm-mono # disable colors
    GIT_MR_EXTENDED=
    GIT_MR_UPDATE_NEW_SECTION=1

    c1sha=$(git rev-parse --short f1c1)
    c2sha=$(git rev-parse --short f1c2)
    c3sha=$(git rev-parse --short f1c3)

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

		-------------------------------------------------------------------
		My MR
		-------------------------------------------------------------------
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

    TERM=xterm-mono # disable colors
    GIT_MR_EXTENDED=1
    GIT_MR_UPDATE_NEW_SECTION=

    c1sha=$(git rev-parse --short f1c1)
    c2sha=$(git rev-parse --short f1c2)
    c3sha=$(git rev-parse --short f1c3)

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

		-------------------------------------------------------------------
		My MR
		-------------------------------------------------------------------
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

################################################################################
# Merge request menu utility functions

@test "Searches MRs across projects to build menu" {
    load "test_helper/gitlab-mock-menu.bash"

    TERM=xterm-mono # disable colors

    run mr_menu

    assert_output "$(cat <<- EOF

		================================================================================
		 AB-123 (4 merge requests)
		================================================================================

		## Menu

		* Project C: [MR 31 title](https://example.net/31)
		* Project A: [MR 11 title](https://example.net/11)
		* Project B: [MR 21 title](https://example.net/21)
		* Project D: [MR 41 title](https://example.net/21)

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
