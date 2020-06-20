#!/usr/bin/env bash


################################################################################
# Git functions

function git_current_branch
{
    git rev-parse --abbrev-ref HEAD
}

function git_base_branch
{
    # Base branch param
    local base_branch=$BASE_BRANCH

    # Nearest branch in commit history
    if [ -z "$base_branch" ]; then
        # selects only commits with a branch or tag
        # removes current head (and branch)
        # selects only the closest decoration
        # filters out everything but decorations
        # splits decorations
        # ignore "tag: ...", "origin/..." and ".../HEAD"
        # keep only first decoration
        local base_branch=$(git log --decorate --simplify-by-decoration --oneline \
            | grep -v "(HEAD"            \
            | head -n1                   \
            | sed 's/.* (\(.*\)) .*/\1/' \
            | sed -e 's/, /\n/g'         \
            | grep -v 'tag:' | grep -vE '^origin\/' | grep -vE '\/HEAD$' \
            | head -n1)
    fi

    # First possible merge base
    if [ -z "$base_branch" ]; then
        base_branch=$(git show-branch  --merge-base | head -n1)
    fi

    echo "$base_branch"
}

function git_commits
{
    local current_branch=${1:-$(git_current_branch)}
    local base_branch=${2:-$(git_base_branch)}

    git log --oneline --reverse --no-decorate ${base_branch}..${current_branch}
}


################################################################################
# Misc. utilities

function extract_json_string
{
    local key=$1
    local content=$2

    echo "$content" \
        | grep -Po '"'${key}'"\s*:\s*"\K.*?[^\\]"' \
        | sed 's/\\"/"/g' \
        | sed 's/"$//'
}

function extract_json_int
{
    local key=$1
    local content=$2

    echo "$content" \
        | grep -Po '"'${key}'"\s*:\s*\K.*?[,}]' \
        | sed 's/[,}]$//'
}

# https://gist.github.com/cdown/1163649
function urlencode
{
    old_lc_collate=$LC_COLLATE
    LC_COLLATE=C

    local length="${#1}"
    for (( i = 0; i < length; i++ )); do
        local c="${1:i:1}"
        case $c in
            [a-zA-Z0-9.~_-]) printf "$c" ;;
            *) printf '%%%02X' "'$c" ;;
        esac
    done

    LC_COLLATE=$old_lc_collate
}

function echo_error
{
    local orange
    local nocolor

    if which tput > /dev/null 2>&1 && [ ! -z "$TERM" ] && [ $(tput -T$TERM colors) -ge 8 ]; then
        orange='\033[0;33m'
        nocolor='\033[0m'
    fi

    printf "${orange}${1}${nocolor}\n" >&2
}

function confirm
{
    local question=$1
    read -r -p "$question [y/N] " response
    case "$response" in
        [yY][eE][sS]|[yY]) echo "yes" ;;
        *)                 echo "no" ;;
    esac
}

function jq_build
{
    local key=${1}
    local value=${2}
    local initial_data=${3:-"{}"}

    local current_object="$(jq --null-input --compact-output \
        --arg value "$value"   "{\"${key}\": \$value}")"

    jq --null-input --compact-output \
            --argjson initial_data "$initial_data"     \
            --argjson current_object "$current_object" \
            '$initial_data + $current_object'
}

################################################################################
# Markdown formatting

function markdown_title
{
    local label=$1
    local level=${2:-1}

    for ((i=1; i<=$level; i++)); do
        echo -n '#'
    done

    echo " ${label}"
}

function markdown_link
{
    local label=$1
    local url=$2

    if [ -z "$url" ]; then
        echo "[$label]"
        return
    fi

    echo "[$label]($url)"
}

function markdown_list
{
    local content=$1
    local wrap=$2

    local prefix="* ${wrap}"
    local suffix="${wrap}<br>"

    echo "$content" \
        | sed "s/^/${prefix}/g" \
        | sed "s/$/${suffix}/g"
}


################################################################################
# Jira functions

function jira_ticket_data
{
    if [ -z "$JIRA_USER" ] || [ -z "$JIRA_TOKEN" ] || [ -z "$JIRA_INSTANCE" ]; then return; fi

    local auth_token=$(echo -n ${JIRA_USER}:${JIRA_TOKEN} | base64 -w 0)
    local issue_url="https://${JIRA_INSTANCE}/rest/api/3/issue/${1}?fields=summary"

    curl -Ss -X GET \
        --max-time 5 \
        -H "Authorization: Basic ${auth_token}" \
        -H "Content-Type: application/json" \
        ${issue_url}
}


################################################################################
# Gitlab functions

function gitlab_project_url
{
    if [ -z "$GITLAB_DOMAIN" ] || [ -z "$GITLAB_TOKEN" ]; then return; fi

    local gitlab_remote=$(git remote get-url --push origin)
    local project_url=$(git remote get-url --push origin | sed "s/git\@${GITLAB_DOMAIN}:\(.*\).git/\1/")

    echo "$project_url"
}

function gitlab_check_error
{
    local result=$1

    local error=$(extract_json_string "error" "${result}")
    local message=$(extract_json_string "message" "${result}")

    if [ ! -z "$error" ] || [ ! -z "$message" ]; then
        echo_error "Gitlab error:"
        echo_error "  ${result}"
        echo_error

        echo "ko"
    fi
}

function gitlab_merge_requests
{
    if [ -z "$GITLAB_DOMAIN" ] || [ -z "$GITLAB_TOKEN" ]; then return; fi

    local project_id=$(urlencode $(gitlab_project_url))

    if [ -z "$project_id" ]; then return; fi

    local source_branch=${1:-$(git_current_branch)}

    local gitlab_base_url="https://${GITLAB_DOMAIN}/api/v4"

    local merge_requests=$(curl -Ss -X GET \
        --max-time 3 \
        -H "Private-Token: ${GITLAB_TOKEN}" \
        -H "Content-Type: application/json" \
        "${gitlab_base_url}/projects/${project_id}/merge_requests?state=opened&view=simple&source_branch=${source_branch}")

    if [ ! -z "$(gitlab_check_error "$merge_requests")" ]; then return; fi

    echo "$merge_requests"
}

function gitlab_merge_request
{
    if [ -z "$GITLAB_DOMAIN" ] || [ -z "$GITLAB_TOKEN" ]; then return; fi

    local gitlab_base_url="https://${GITLAB_DOMAIN}/api/v4"
    local project_id=$(urlencode "$(gitlab_project_url)")
    local mr_iid=$1

    if [ -z "$mr_iid" ]; then return; fi
    if [ -z "$project_id" ]; then return; fi

    local merge_request=$(curl -Ss -X GET \
        --max-time 3 \
        -H "Private-Token: ${GITLAB_TOKEN}" \
        -H "Content-Type: application/json" \
        "${gitlab_base_url}/projects/${project_id}/merge_requests/$mr_iid")

    echo "$merge_request"
}

function gitlab_merge_request_notes
{
    if [ -z "$GITLAB_DOMAIN" ] || [ -z "$GITLAB_TOKEN" ]; then return; fi

    local gitlab_base_url="https://${GITLAB_DOMAIN}/api/v4"
    local project_id=$(urlencode $(gitlab_project_url))
    local mr_iid=$1

    if [ -z "$mr_iid" ]; then return; fi
    if [ -z "$project_id" ]; then return; fi

    local notes=$(curl -Ss -X GET \
        --max-time 3 \
        -H "Private-Token: ${GITLAB_TOKEN}" \
        -H "Content-Type: application/json" \
        "${gitlab_base_url}/projects/${project_id}/merge_requests/$mr_iid/notes")

    echo "$notes"
}

function gitlab_merge_request_url
{
    local source_branch=${1:-$(git_current_branch)}
    local merge_requests=${2:-$(gitlab_merge_requests "$source_branch")}

    extract_json_string "web_url" "${merge_requests}"
}

function gitlab_default_label_ids
{
    if [ ! -z "$GITLAB_DEFAULT_LABEL_IDS" ] || [ -z "$GITLAB_DOMAIN" ] || [ -z "$GITLAB_TOKEN" ]; then return; fi

    local project_id=$(urlencode $(gitlab_project_url))

    local gitlab_base_url="https://${GITLAB_DOMAIN}/api/v4"

    local gitlab_labels=$(curl -Ss -X GET \
        --max-time 3 \
        -H "Private-Token: ${GITLAB_TOKEN}" \
        -H "Content-Type: application/json" \
        "${gitlab_base_url}/projects/${project_id}/labels")

    # split in multiple lines
    gitlab_labels=$(echo "$gitlab_labels" | sed "s/},/},\n/g")

    # extact ids
    oIFS="$IFS"; IFS=','; read -ra default_labels <<< "$GITLAB_DEFAULT_LABELS"; IFS="$oIFS"; unset oIFS
    for label in "${default_labels[@]}"; do

        local label_row=$(echo "$gitlab_labels" | grep "\"name\":\"$label\"")
        local label_id=$(extract_json_int "id" "$label_row")

        if [ ! -z "$label_id" ]; then
            echo "$label_id"
        fi
    done
}

function gitlab_new_merge_request_url
{
    if [ -z "$GITLAB_DOMAIN" ] || [ -z "$GITLAB_TOKEN" ]; then return; fi

    local gitlab_remote=$(git remote get-url --push origin)
    local project_url=$(gitlab_project_url)

    if [ -z "$project_url" ]; then return; fi

    local source_branch=${1:-$(git_current_branch)}
    local target_branch=${2:-$(git_base_branch)}

    local gitlab_mr_url="https://${GITLAB_DOMAIN}/${project_url}/merge_requests/new"

    gitlab_mr_url="${gitlab_mr_url}?"$(urlencode "merge_request[source_branch]")"=${source_branch}"
    gitlab_mr_url="${gitlab_mr_url}&"$(urlencode "merge_request[target_branch]")"=${target_branch}"

    # default labels
    for label_id in $(gitlab_default_label_ids); do
        gitlab_mr_url="${gitlab_mr_url}&"$(urlencode "merge_request[label_ids][]")"=${label_id}"
    done

    # other options
    if [ ! -z "$GITLAB_DEFAULT_FORCE_REMOVE_SOURCE_BRANCH" ] && [ "$GITLAB_DEFAULT_FORCE_REMOVE_SOURCE_BRANCH" -gt 0 ]; then
        gitlab_mr_url="${gitlab_mr_url}&"$(urlencode "merge_request[force_remove_source_branch]")"=1"
    fi

    echo "$gitlab_mr_url"
}

function gitlab_merge_request_update
{
    if [ -z "$GITLAB_DOMAIN" ] || [ -z "$GITLAB_TOKEN" ]; then return; fi

    command -v jq >/dev/null 2>&1 || { echo_error "Please install jq to be able to update merge request"; return; }

    local gitlab_base_url="https://${GITLAB_DOMAIN}/api/v4"

    local project_id=$1
    local mr_iid=$2
    local description=$3
    local new_target=$4

    if [ -z "$project_id" ];  then echo_error "No project_id provided";  return; fi
    if [ -z "$mr_iid" ];      then echo_error "No mr_iid provided";      return; fi

    local mr_data='{}'

    if [ ! -z "$description" ]; then
        mr_data=$(jq_build "description" "$description" "$mr_data")
    fi

    if [ ! -z "$new_target" ]; then
        mr_data=$(jq_build "target_branch" "$new_target" "$mr_data")
    fi

    if [ "$mr_data" = "{}" ]; then
        echo_error "Nothing to update"
        echo
        return
    fi

    local result=$(curl -Ss -X PUT \
        --max-time 5 \
        -H "Private-Token: ${GITLAB_TOKEN}" \
        -H "Content-Type: application/json" \
        --data "${mr_data}" \
        "${gitlab_base_url}/projects/${project_id}/merge_requests/${mr_iid}")

    local error=$(extract_json_string "error" "${result}")
    local message=$(extract_json_string "message" "${result}")

    if [ ! -z "$error" ] || [ ! -z "$message" ]; then
        echo_error "Gitlab error:"
        echo_error "  ${result}"
        echo_error
        return
    fi

    echo "OK"
    echo
}

################################################################################
# Merge request

function guess_issue_code
{
    if [ -z "$JIRA_CODE_PATTERN" ]; then
        echo_error "JIRA_CODE_PATTERN not set"
        return
    fi

    local current_branch=$(git_current_branch)

    echo "${current_branch}" | grep -iEo $JIRA_CODE_PATTERN | tail -n1
}

function mr_title
{
    local current_branch=${1:-$(git_current_branch)}

    if [ -z "$ISSUE_CODE" ]; then
        echo "$current_branch"
        return
    fi

    local issue_content=$(jira_ticket_data $ISSUE_CODE)

    local issue_key=$(extract_json_string "key" "$issue_content")
    local issue_title=$(extract_json_string "summary" "$issue_content")

    if [ -z "$issue_key" ]; then
        issue_key=${ISSUE_CODE^^}
    fi

    if [ -z "$issue_title" ]; then
        echo_error "Unable to get issue title from Jira"
        echo_error "  ISSUE_CODE: $ISSUE_CODE"
        if [ ! -z "$issue_content" ]; then
            echo_error "  $issue_content"
        fi

        echo "$issue_key"
        return
    fi

    issue_url="https://${JIRA_INSTANCE}/browse/${issue_key}"

    markdown_link "${issue_key} ${issue_title}" "$issue_url"
}

function mr_description
{
    local current_branch=${1:-$(git_current_branch)}
    local base_branch=${2:-$(git_base_branch)}

    local title=$(mr_title "$current_branch")
    local commits=$(git_commits "$current_branch" "$base_branch")

    cat << EOF

--------------------------------------------------------------------------------
$(markdown_title "$title")


## Commits

$(markdown_list "$commits" "**")

--------------------------------------------------------------------------------

EOF
}

function mr_actions
{
    local current_branch=${1:-$(git_current_branch)}
    local base_branch=${2:-$(git_base_branch)}

    local merge_requests=$(gitlab_merge_requests "$current_branch")

    local current_mr_iid=$(extract_json_int "iid" "${merge_requests}")
    local current_mr_url=$(gitlab_merge_request_url ${current_branch} "$merge_requests")

    if [ ! -z "${current_mr_url}" ]; then
        cat << EOF
Merge request:

  ${current_mr_url}

EOF

        mr_status ${current_mr_iid}

        return
    fi

    local new_mr_url=$(gitlab_new_merge_request_url ${current_branch} ${base_branch})

cat << EOF
To create a new merge request:

  ${new_mr_url}

EOF
}

function mr_status
{
    local mr_iid=$1
    local merge_request=${2:-$(gitlab_merge_request $mr_iid)}

    local upvotes=$(extract_json_int "upvotes" "$merge_request")
    local downvotes=$(extract_json_int "downvotes" "$merge_request")
    local state=$(extract_json_string "state" "$merge_request")
    local merge_status=$(extract_json_string "merge_status" "$merge_request")

    local merge_status_icon
    if [ "$merge_status" = "can_be_merged" ]; then
        merge_status_icon="\U00002705"; # white heavy check mark
    else
        merge_status_icon="\U0000274C"; # cross mark
    fi

    local notes=$(gitlab_merge_request_notes $mr_iid \
        | sed 's/\\n//g' \
        | sed 's/[^:]{"id":/\n\n\n{"id":/g')

    local threads=$(echo "$notes" | grep '"resolvable":true')
    local resolved=$(echo "$notes" | grep '"resolved":true')

    local thread_count=$(echo "$threads" | wc -l)
    local resolved_count=$(echo "$resolved" | wc -l)

    if [ -z "$threads" ];  then thread_count=0;   fi
    if [ -z "$resolved" ]; then resolved_count=0; fi

    echo -en "    \U0001F44D  ${upvotes}"   # thumbs up
    echo -en "    \U0001F44E  ${downvotes}" # thumbs down
    if [ "$thread_count" -gt 0 ]; then
        echo -n "        Resolved threads: ${resolved_count}/${thread_count}"
    fi
    echo -en "        Can be merged: $merge_status_icon"
    echo
    echo
}

function print_mr
{
    local current_branch=${1:-$(git_current_branch)}
    local base_branch=${2:-$(git_base_branch)}

    mr_description $current_branch $base_branch
    mr_actions     $current_branch $base_branch
}

function print_mr_update
{
    local current_branch=$(git_current_branch)
    local base_branch=${1:-$(git_base_branch)}

    # Search existing merge request

    local merge_requests=$(gitlab_merge_requests "$current_branch")

    local project_id=$(urlencode $(gitlab_project_url))
    local current_mr_iid=$(extract_json_int "iid" "${merge_requests}")
    local current_mr_url=$(gitlab_merge_request_url ${current_branch} "$merge_requests")

    if [ -z "${current_mr_iid}" ] || [ -z "${current_mr_url}" ]; then
        echo_error "Merge request not found"
        ISSUE_CODE=$(guess_issue_code)
        print_mr ${current_branch} ${base_branch}
        return
    fi

    # Load existing merge request details

    local merge_request=$(gitlab_merge_request $current_mr_iid)

    local current_description=$(extract_json_string "description" "$merge_request" \
        | sed 's/\\r//g' \
        | sed 's/\\n/\n/g' \
        | sed 's/\\u003c/</g' \
        | sed 's/\\u003e/>/g' \
        | sed 's/\\\\/\\/g' \
    )

    local current_target=$(extract_json_string "target_branch" "$merge_request")

    # Init commit lists

    local commit_messages=$(git_commits $current_branch $base_branch)

    local current_commits=$(echo "$commit_messages" | cut -d ' ' -f1)
    local old_commits=$(echo "$current_description" \
        | grep -Po '^[^0-9a-fA-F]*[0-9a-fA-F]{7,}\s' \
        | sed -r 's/^[^0-9a-fA-F]*([0-9a-fA-F]{7,})\s/\1/g' \
    )

    local current_commits_array=($(echo "$current_commits" | tr "\n" " "))
    local old_commits_array=($(echo "$old_commits" | tr "\n" " "))

    local updated_commit_count=0
    local new_commit_messages_display=()
    local new_commit_messages_content=()

    local new_description_display="$current_description"
    local new_description_content="$current_description"

    local green='\033[0;32m'
    local orange='\033[0;33m'
    local bblue='\033[0;94m'
    local nocolor='\033[0m'

    local sameColor="${bblue}"
    local updatedColor="${orange}"
    local newColor="${green}"

    # Iterate over commit lists, compare sha-1 and update description
    for i in ${!current_commits_array[*]}; do

        local curr=${current_commits_array[$i]}
        local old=${old_commits_array[$i]}

        if [ ! -z "$old" ]; then
            if [ "$old" = "$curr" ]; then
                # same sha-1 - only decorate
                new_description_display=$(echo "$new_description_display" | sed "s/${old}/\\${sameColor}${curr}\\${nocolor}/" )
                new_description_content=$(echo "$new_description_content" | sed "s/${old}/${curr}/" )
            else
                # different sha-1 - replace & decorate
                new_description_display=$(echo "$new_description_display" | sed "s/${old}/\\${updatedColor}${curr}\\${nocolor}/" )
                new_description_content=$(echo "$new_description_content" | sed "s/${old}/${curr}/" )
                updated_commit_count=$((updated_commit_count+1))
            fi
        else
            # new commits
            new_commit_messages_display+=("$(echo "$commit_messages" | grep "${curr}" | sed "s/${curr}/\\${newColor}${curr}\\${nocolor}/")")
            new_commit_messages_content+=("$(echo "$commit_messages" | grep "${curr}" | sed "s/${curr}/${curr}/")")
        fi
    done

    local new_commit_count=${#new_commit_messages_display[@]}

    # implode arrays
    new_commit_messages_display=$(printf "%s\n" "${new_commit_messages_display[@]}")
    new_commit_messages_content=$(printf "%s\n" "${new_commit_messages_content[@]}")

    # Print updated merge request description
    echo
    echo "-------------------------------------------------------------------"
    echo -e "$new_description_display"
    echo
    echo
    if [ "$new_commit_count" -gt 0 ]; then
        echo "## Update"
        echo
        echo -e "$(markdown_list "$new_commit_messages_display" "**")"
        echo
    fi
    echo "--------------------------------------------------------------------------------"
    echo
    echo -e "  updated commits: ${updatedColor}${updated_commit_count}${nocolor}"
    echo -e "      new commits: ${newColor}${new_commit_count}${nocolor}"
    echo

    # Propose update if changes are detected

    local new_description
    local new_target

    if [ "$updated_commit_count" -gt 0 ] || [ "$new_commit_count" -gt 0 ]; then
        read -r -p "Do you want to update the merge request description? [y/N] " response
        case "$response" in
            [yY][eE][sS]|[yY])
                new_description="$new_description_content"
                if [ "$new_commit_count" -gt 0 ]; then
                    new_description=$(echo -e "${new_description}")
                    new_description=$(echo -e "\n\n${new_description}## Update")
                    new_description=$(echo -e "\n\n${new_description}$(markdown_list "$new_commit_messages_content" "**")")
                fi
                new_description=$(echo -e "${new_description}\n ")
                ;;
        esac
    fi

    if [ "$base_branch" != "$current_target" ]; then
        read -r -p "Do you want to update the merge request target branch from '$current_target' to '$base_branch'? [y/N] " response
        case "$response" in
            [yY][eE][sS]|[yY])
                new_target="$base_branch"
                ;;
        esac
    fi

    if [ ! -z "$new_description" ] || [ ! -z "$new_target" ]; then
        if [ -x "$(command -v jq)" ]; then
            gitlab_merge_request_update "$project_id" "$current_mr_iid" "$new_description" "$new_target"
        else
            echo_error "Please install jq to be able to update merge request"
        fi
    else
        echo
    fi

    echo "--------------------------------------------------------------------------------"
    echo
    mr_actions $current_branch $base_branch
}

function usage
{
    cat << EOF

USAGE

    mr [issue_code] [base_branch]

    mr update [base_branch]

INSTALLATION

    As a standalone script:

        alias mr=/path/to/mr.sh

    As a git alias:

        Define this alias in your .gitconfig:

        [alias]
            mr = "!bash /path/to/mr.sh"

CONFIGURATION

    You need to configure the following environment variables:

        export JIRA_USER="user.name@mycompany.com"
        export JIRA_INSTANCE="mycompany.atlassian.net"
        export JIRA_TOKEN="abcdefghijklmnopqrstuvwx"
        export JIRA_CODE_PATTERN="XY-[0-9]+"

        export GITLAB_DOMAIN="myapp.gitlab.com"
        export GITLAB_TOKEN="Zyxwvutsrqponmlkjihg"

        export GITLAB_DEFAULT_LABELS="Review,My Team"      # Default labels for new merge requests
        export GITLAB_DEFAULT_FORCE_REMOVE_SOURCE_BRANCH=1 # Check "Delete source branch" by default

    To create a Jira API Token, go to: https://id.atlassian.com/manage-profile/security/api-tokens
    (Account Settings -> Security -> API Token -> Create and manage API tokens)

    To create a Gitlab API Token, go to: https://myapp.gitlab.com/profile/personal_access_tokens<br>
    (Settings -> Access Tokens)

EOF
}


################################################################################
# Run


if [ -z "$JIRA_USER" ];     then echo_error "JIRA_USER not set";          fi
if [ -z "$JIRA_INSTANCE" ]; then echo_error "JIRA_INSTANCE not set";      fi
if [ -z "$JIRA_TOKEN" ];    then echo_error "JIRA_TOKEN not set";         fi
if [ -z "$GITLAB_DOMAIN" ]; then echo_error "GITLAB_DOMAIN not set";      fi
if [ -z "$GITLAB_TOKEN" ];  then echo_error "GITLAB_TOKEN not set";       fi

case $1 in
    help)
        usage
        ;;

    update)
        print_mr_update "${@:2}"
        ;;

    *)
        ISSUE_CODE=${1:-$(guess_issue_code)}
        BASE_BRANCH=$2

        if [ -z "$ISSUE_CODE" ]; then echo_error "Unable to guess issue code"; fi

        print_mr
        ;;
esac
