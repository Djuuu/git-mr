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


GITLAB_IP_LABELS="WIP"
GITLAB_CR_LABELS="Review"
GITLAB_QA_LABELS="Testing"
GITLAB_OK_LABELS="Accepted"

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
        "labels":["WIP","My Team"], "target_branch": "main",
        "upvotes": 1, "downvotes": 1, "merge_status": "cannot_be_merged",
        "head_pipeline": {"status":"failed", "web_url":"https://myapp.gitlab.com/my/project/pipelines/6"}
    }'

    local threads='1	unresolved:true	note_id:1'

    echo
    mr_status_block "$mr" "$mr" "$threads"
}

sample_mr_update() {
    fake_prompt "git mr update -n \"QA feedback\""

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

$(colorize "## QA feedback" "bold")

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

sample_mr_update_links() {
    fake_prompt "git mr update"

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

* **$(c_same "78330c9")🔗✔ In vulputate quam ac ultrices volutpat**
* **$(c_same "0010a6a")🔗✔ Curabitur vel purus sed tortor finibus posuere**
* **$(c_same "aac348f")🔗✔ Aenean sed sem hendrerit ex egestas tincidunt**

--------------------------------------------------------------------------------

   upgraded links: $(c_same "3") 🔗

$(c_question "Do you want to update the merge request description?") [y/N]

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

$(mr_status_block "$mr" "$mr" "$threads")

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

EOF

    echo "* $(colorize "Some Project" "bold"): $(terminal_link "https://myapp.gitlab.com/some/project/-/merge_requests/12" "Feature/XY-1234 Lorem Ipsum")"
    has_links || echolor "  ⇒ https://myapp.gitlab.com/some/project/-/merge_requests/12" "midgray"
    mr_print_status "$mr1" "$threads1"
    echo

    echo "* $(colorize "Other Project" "bold"): $(terminal_link "https://myapp.gitlab.com/other/project/-/merge_requests/34" "Feature/XY-1234 Quisque sed")"
    has_links || echolor "  ⇒ https://myapp.gitlab.com/some/project/-/merge_requests/34" "midgray"
    mr_print_status "$mr2" "$threads2"
    echo

    echo "* $(colorize "Third Project" "bold"): $(terminal_link "https://myapp.gitlab.com/third/project/-/merge_requests/56" "Feature/XY-1234 Nunc vestibulum")"
    has_links || echolor "  ⇒ https://myapp.gitlab.com/some/project/-/merge_requests/56" "midgray"
    mr_print_status "$mr3" "$threads3"
    echo
}

sample_mr_menu_update() {
    fake_prompt "git mr menu update"

    mr_description="# [XY-1234 Quisque sed](https://jira.example.net/browse/XY-1234)

## Menu

* Some Project: [Feature/XY-1234 Lorem Ipsum](https://myapp.gitlab.com/some/project/...)
* **Other Project: [Feature/XY-1234 Quisque sed](https://myapp.gitlab.com/other/project/...)**
* Third Project: [Feature/XY-1234 Nunc vestibulum](https://myapp.gitlab.com/third/project/...)

--------------------------------------------------------------------------------


Quisque sed consectetur adipiscing elit.

Pellentesque eu lectus felis. Phasellus maximus, quam quis accumsan varius,
enim nunc egestas ante, ut venenatis nunc eros non lorem. Ut molestie elementum
nisi in sollicitudin.

Nullam tempus ultricies velit ut scelerisque. Curabitur at ex suscipit odio.

## Commits

* **97b0769f XY-1234 Sed id ultrices lorem**
* **86128e01 XY-1234 Pellentesque habitant morbi**
  tristique senectus et netus et malesuada fames ac turpis egestas
* **a1c23d36 XY-1234 Duis vehicula metus sit amet nulla ultrices dictum**
* **aa341612 XY-1234 Morbi condimentum sapien risus**
  Sit amet facilisis urna semper quis
* **40aa1e6a XY-1234 Sed iaculis dui id facilisis venenatis**
* **f3b2e6c3 XY-1234 Proin vitae lobortis nunc, sed dictum orci**
  Nullam vitae laoreet erat, et dignissim lectus
  Nullam ornare, nibh et posuere rhoncus
  Mauris tellus accumsan purus, in congue sapien nisl eu ante
* **969d26a6 XY-1234 Curabitur pretium sed justo in vehicula**
* **2c1422c6 XY-1234 Mauris id nunc odio**
"

mr_url="https://myapp.gitlab.com/other/project/..."
mr_title="Feature/XY-1234 Quisque sed"
project_name="Other Project"

    cat <<EOF

================================================================================
 $(terminal_link "$search_url" "$issue_code") (merge request 2/3)
================================================================================
EOF

    mr_menu_print_description "$mr_description" "$mr_url" "$mr_title" "$project_name"

    echo "$(colorize "Do you want to update the menu in the merge request description?" "lightcyan" "bold") [y/N] "
    echo
}

sample_mr_prepare_commit_msg() {

    local branch="feature/xy-1234-lorem-ipsum"
    colorize "\n___________________________________________________________________________________________\n\n\n" "gray"
    echo "$(colorize "me@mystation" "green"):$(colorize "~/my-project" "lightblue") $(colorize "($branch)" "purple") $(colorize "↔ ✔" "green")"
    echo "$ git commit -m \"Consectetur adipiscing elit\""

    cat <<EOF
Prefixing message with issue code: XY-1234
[feature/xy-1234-lorem-ipsum 2ba273f865] XY-1234 Consectetur adipiscing elit
 1 file changed, 5 insertions(+), 3 deletions(-)
EOF
    echo
}

# ----------------------------------------------------------------------------------------------------------------------

if [[ "$#" -gt 0 ]]; then
    for arg in "$@"; do
        case "$arg" in
            mr)
                sample_mr
                sample_mr_extended
                ;;
            status)
                sample_mr_status
                ;;
            update)
                sample_mr_update
                sample_mr_update_links
                ;;
            menu)
                sample_mr_menu
                sample_mr_menu_status
                sample_mr_menu_update
                ;;
            merge)
                sample_mr_merge
                ;;
            hook)
                sample_mr_prepare_commit_msg
                ;;
        esac
    done
else
    sample_mr
    sample_mr_extended

    sample_mr_status

    sample_mr_update
    sample_mr_update_links

    sample_mr_menu
    sample_mr_menu_status
    sample_mr_menu_update

    sample_mr_merge

    sample_mr_prepare_commit_msg
fi
