#!/usr/bin/env bash

cat << EOF

################################################################################
#                                                                              #
#                         git-mr output examples                               #
#                                                                              #
################################################################################

EOF

pushd "$(dirname "${BASH_SOURCE[0]}")" > /dev/null
. ../git-mr


GITLAB_OK_LABELS="Accepted"
GITLAB_QA_LABELS="Testing"
GITLAB_CR_LABELS="Review"

issue_code="XY-1234"

ticket_title="${issue_code} Lorem Ipsum"
ticket_url="https://mycompany.atlassian.net/browse/${issue_code}"
ticket_link="$(markdown_link "$ticket_title" "$ticket_url")"

mr_title="Feature/${issue_code} Lorem Ipsum"
mr_url="https://myapp.gitlab.com/my/project/merge_requests/6"
new_mr_url="https://myapp.gitlab.com/my/project/merge_requests/new?..."
search_url="https://myapp.gitlab.com/dashboard/merge_requests?scope=all&state=all&search=$(urlencode "$issue_code")&in=title&sort=created_asc"

# ----------------------------------------------------------------------------------------------------------------------

fake_prompt() {
    local cmd=$1
    local branch=${2:-"feature/xy-1234-lorem-ipsum"}

    colorize "\n___________________________________________________________________________________________\n\n\n" "gray"
    echo "$(colorize "me@mystation" "green"):$(colorize "~/my-project" "lightblue") $(colorize "($branch)" "purple") $(colorize "↔ ✔" "green") $ $cmd"
}

c_same() {
    colorize "$1" "lightblue"
}
c_updated() {
    colorize "$1" "orange"
}
c_new() {
    colorize "$1" "green"
}
c_question() {
    colorize "$1" "lightcyan" "bold"
}

# ----------------------------------------------------------------------------------------------------------------------

sample_mr() {
    fake_prompt "git mr"
    cat <<EOF

--------------------------------------------------------------------------------
$(mr_print_description "$ticket_link" "* **78330c9 In vulputate quam ac ultrices volutpat**
* **0010a6a Curabitur vel purus sed tortor finibus posuere**
* **3621817 Aenean sed sem hendrerit ex egestas**  ")

--------------------------------------------------------------------------------

To create a new merge request:

  ${new_mr_url}

EOF
}

sample_mr_extended() {
    fake_prompt "git mr -e"
    cat <<EOF

--------------------------------------------------------------------------------
$(mr_print_description "$ticket_link" "* **78330c9 In vulputate quam ac ultrices volutpat**
  Some commit description
* **0010a6a Curabitur vel purus sed tortor finibus posuere**
  Extended description
  - stuff
  - other stuff
* **3621817 Aenean sed sem hendrerit ex egestas**")

--------------------------------------------------------------------------------

To create a new merge request:

  ${new_mr_url}

EOF
}

sample_mr_status() {
    fake_prompt "git mr status"

    local mr='{
        "title": "Draft: '"$mr_title"'", "web_url":"'"$mr_url"'",
        "labels":["Review","My Team"], "target_branch": "main",
        "upvotes": 1, "downvotes": 1, "merge_status": "cannot_be_merged",
        "head_pipeline": {"status":"failed", "web_url":"https://myapp.gitlab.com/my/project/pipelines/6"}
    }'

    local threads='1	unresolved:true	note_id:1'

    echo
    mr_status_block "" "$mr" "" "" "$threads"
}

sample_mr_update() {
    fake_prompt "git mr update -n"

    local mr='{
        "title": "Draft: '"$mr_title"'", "web_url":"'"$mr_url"'",
        "labels":["Testing","My Team"], "target_branch": "main",
        "upvotes": 2, "downvotes": 0, "merge_status": "can_be_merged",
        "head_pipeline": {"status":"running", "web_url":"https://myapp.gitlab.com/my/project/pipelines/6"}
    }'

    local threads='1	unresolved:false	note_id:2
2	unresolved:true	note_id:2'

    cat << EOF

$(mr_print_title "$mr_title" "$mr_url")

$(markdown_title "$ticket_link")

Vivamus venenatis tortor et neque sollicitudin, eget suscipit est malesuada.
Suspendisse nec odio id arcu sagittis pulvinar ut nec lacus.

Sed non nulla ac metus congue consectetur et vel magna.

## Commits

* **$(c_same "78330c9") In vulputate quam ac ultrices volutpat**
  In vulputate quam
  ac ultrices volutpat
* **$(c_same "0010a6a") Curabitur vel purus sed tortor finibus posuere**
  Curabitur vel
* **$(c_updated "aac348f") Aenean sed sem hendrerit ex egestas tincidunt**
  Hendrerit ex egestas
  egestas sed

## Update

* **$(colorize "e9642b7" "green") Ut consectetur leo ut leo commodo porttitor**
  Nam tincidunt ligula lectus

--------------------------------------------------------------------------------

  updated commits: $(c_updated "1")
      new commits: $(c_new "1")

$(c_question "Do you want to update the merge request description?") [y/N] y
$(c_question "Do you want to update the merge request target branch from 'oldtrgt' to 'main'?") [y/N] y
Updating merge request...OK

--------------------------------------------------------------------------------
$(mr_print_status "$mr" "$threads")

EOF
}

sample_mr_merge() {
    fake_prompt "git mr merge"

    local mr='{
        "title": "Draft: '"$mr_title"'", "web_url":"'"$mr_url"'",
        "labels":["Accepted","My Team"], "target_branch": "main",
        "upvotes": 2, "downvotes": 0, "merge_status": "can_be_merged",
        "head_pipeline": {"status":"success", "web_url":"https://myapp.gitlab.com/my/project/pipelines/6"}
    }'

    local threads="1	unresolved:false	note_id:2
2	unresolved:false	note_id:2"

    cat << EOF

$(mr_status_block "" "$mr" "" "" "$threads")

--------------------------------------------------------------------------------

$(colorize "Merge request is a draft (work in progress)" "orange")
$(c_question "Do you want to resolve draft status?") [y/N] y
Resolving draft status... OK

$(c_question "Do you want to merge 'feature/xy-1234-lorem-ipsum'?") [y/N] y
Merging 'feature/xy-1234-lorem-ipsum'... OK

$(c_question "Do you want to checkout 'main' and pull changes?") [y/N] y
$(colorize "git checkout main && git pull --rebase" "lightgray")
Switched to branch 'main'
Your branch is up to date with 'origin/main'.
From myapp.gitlab.com:me/my/project
 - [deleted]         (none)     -> origin/feature/xy-1234-lorem-ipsum
remote: Enumerating objects: 1, done.
remote: Counting objects: 100% (1/1), done.
remote: Total 1 (delta 0), reused 0 (delta 0), pack-reused 0
remote:
Unpacking objects: 100% (1/1), 263 bytes | 263.00 KiB/s, done.
   c17b3a1..9545ecd  main    -> origin/main
Updating c17b3a1..9545ecd
Fast-forward

$(c_question "Do you want to delete local branch 'feature/xy-1234-lorem-ipsum'?") [y/N] y
$(colorize "git branch -d feature/xy-1234-lorem-ipsum" "lightgray")
Deleted branch feature/xy-1234-lorem-ipsum (was e9642b7).

EOF
}

sample_mr_menu() {
    fake_prompt "git mr menu"

    cat <<EOF

================================================================================
 $(terminal_link "$search_url" "$issue_code") (3 merge requests)
================================================================================

## Menu

* Some Project: [Feature/XY-1234 Lorem](https://myapp.gitlab.com/some/project/...)
* Other Project: [Feature/XY-1234 Ipsum](https://myapp.gitlab.com/other/project/...)
* Third Project: [Feature/XY-1234 Dolor](https://myapp.gitlab.com/third/project/...)

--------------------------------------------------------------------------------
EOF

}

sample_mr_menu_status() {
    fake_prompt "git mr menu status"

    local mr1='{
        "title": "Draft: Feature/XY-1234 Lorem Ipsum",
        "web_url":"https://myapp.gitlab.com/some/project/-/merge_requests/12",
        "labels":["Review","My Team"], "target_branch": "main",
        "upvotes": 1, "downvotes": 1, "merge_status": "cannot_be_merged",
        "head_pipeline": {"status":"pending", "web_url":"https://myapp.gitlab.com/my/project/pipelines/6"}
    }'
    local threads1='1	unresolved:true	note_id:1'

    local mr2='{
        "title": "Draft: Feature/XY-1234 Quisque sed",
        "web_url":"https://myapp.gitlab.com/other/project/-/merge_requests/34",
        "labels":["Testing","My Team"], "target_branch": "master",
        "upvotes": 2, "downvotes": 1, "merge_status": "can_be_merged",
        "head_pipeline": {"status":"skipped", "web_url":"https://myapp.gitlab.com/my/project/pipelines/6"}
    }'
    local threads2='1	unresolved:false	note_id:1
2	unresolved:true	note_id:2'

    local mr3='{
        "title": "Feature/XY-1234 Nunc vestibulum",
        "web_url":"https://myapp.gitlab.com/third/project/-/merge_requests/56",
        "labels":["Accepted","My Team"], "target_branch": "epic/stuff",
        "upvotes": 2, "downvotes": 0, "merge_status": "can_be_merged",
        "head_pipeline": {"status":"success", "web_url":"https://myapp.gitlab.com/my/project/pipelines/6"}
    }'
    local threads3='1	unresolved:false	note_id:1
2	unresolved:false	note_id:2'

    cat <<EOF

================================================================================
 $(terminal_link "$search_url" "$issue_code") (3 merge requests)
================================================================================

* $(colorize "Some Project" "bold"): $(terminal_link "https://myapp.gitlab.com/some/project/-/merge_requests/12" "Feature/XY-1234 Lorem Ipsum")
$(mr_print_status "$mr1" "$threads1")


* $(colorize "Other Project" "bold"): $(terminal_link "https://myapp.gitlab.com/other/project/-/merge_requests/34" "Feature/XY-1234 Quisque sed")
$(mr_print_status "$mr2" "$threads2")


* $(colorize "Third Project" "bold"): $(terminal_link "https://myapp.gitlab.com/third/project/-/merge_requests/56" "Feature/XY-1234 Nunc vestibulum")
$(mr_print_status "$mr3" "$threads3")


EOF
}

# ----------------------------------------------------------------------------------------------------------------------

sample_mr
sample_mr_extended

sample_mr_status

sample_mr_update
sample_mr_merge

sample_mr_menu
sample_mr_menu_status
