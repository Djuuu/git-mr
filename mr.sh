#!/usr/bin/env bash


################################################################################
# Functions

function usage
{
    cat << EOF

USAGE

    mr [issue_code] [base_branch]

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

    To create a Jira API Token, go to: https://id.atlassian.com/manage-profile/security/api-tokens
    (Account Settings -> Security -> API Token -> Create and manage API tokens)

    To create a Gitlab API Token, go to: https://myapp.gitlab.com/profile/personal_access_tokens<br>
    (Settings -> Access Tokens)

EOF
}

function guess_issue_code
{
    if [ -z "$JIRA_CODE_PATTERN" ]; then
        echo "JIRA_CODE_PATTERN not set" >&2;
        return
    fi

    local current_branch=$(git rev-parse --abbrev-ref HEAD)

    echo "${current_branch}" | grep -iEo $JIRA_CODE_PATTERN | tail -n1
}

function get_jira_ticket_data
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

function extract_json_value
{
    local key=$1
    local content=$2

    echo $content | grep -Po '"'${key}'"\s*:\s*"\K.*?[^\\]"' | sed 's/\\"/"/g' | sed 's/"$//'
}

function get_git_current_branch
{
    git rev-parse --abbrev-ref HEAD
}

function get_git_base_branch
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

    echo $base_branch
}

function get_git_commits
{
    local current_branch=${1:-$(get_git_current_branch)}
    local base_branch=${2:-$(get_git_base_branch)}

    git log --oneline --reverse --no-decorate ${base_branch}..${current_branch}
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

function get_gitlab_merge_request_url
{
    if [ -z "$GITLAB_DOMAIN" ] || [ -z "$GITLAB_TOKEN" ]; then return; fi

    local gitlab_remote=$(git remote get-url --push origin)
    local project_url=$(git remote get-url --push origin | sed "s/git\@${GITLAB_DOMAIN}:\(.*\).git/\1/")

    if [ -z "$project_url" ]; then return; fi

    local source_branch=${1:-$(get_git_current_branch)}
    local project_id=$(urlencode $project_url)

    local gitlab_base_url="https://${GITLAB_DOMAIN}/api/v4"

    local merge_requests=$(curl -Ss -X GET \
            --max-time 3 \
            -H "Private-Token: ${GITLAB_TOKEN}" \
            -H "Content-Type: application/json" \
            "${gitlab_base_url}/projects/${project_id}/merge_requests?state=opened&view=simple&source_branch=${source_branch}")

    local error=$(extract_json_value "error" "${merge_requests}")
    local message=$(extract_json_value "message" "${merge_requests}")

    if [ ! -z "$error" ] || [ ! -z "$message" ]; then
        echo "Gitlab error:"       >&2
        echo "  ${merge_requests}" >&2
        echo                       >&2
        return
    fi

    extract_json_value "web_url" "${merge_requests}"
}

function get_gitlab_new_merge_request_url
{
    if [ -z "$GITLAB_DOMAIN" ] || [ -z "$GITLAB_TOKEN" ]; then return; fi

    local gitlab_remote=$(git remote get-url --push origin)
    local project_url=$(git remote get-url --push origin | sed "s/git\@${GITLAB_DOMAIN}:\(.*\).git/\1/")

    if [ -z "$project_url" ]; then return; fi

    local source_branch=${1:-$(get_git_current_branch)}
    local target_branch=$2

    local gitlab_mr_url="https://${GITLAB_DOMAIN}/${project_url}/merge_requests/new"

    gitlab_mr_url="${gitlab_mr_url}?"$(urlencode "merge_request[source_branch]")"=${source_branch}"
    gitlab_mr_url="${gitlab_mr_url}&"$(urlencode "merge_request[target_branch]")"=${target_branch}"

    echo $gitlab_mr_url
}

function print_mr_description
{
    local current_branch=$(get_git_current_branch)
    local base_branch=$(get_git_base_branch)

    ### Jira issue - title

    local mr_name=${current_branch}
    local issue_url
    local mr_title

    if [ ! -z "$ISSUE_CODE" ]; then
        local issue_content=$(get_jira_ticket_data $ISSUE_CODE)

        local issue_key=$(extract_json_value "key" "$issue_content")
        local issue_title=$(extract_json_value "summary" "$issue_content")

        if [ -z "$issue_key" ]; then
            issue_key=${ISSUE_CODE^^}
        fi

        mr_name="${issue_key}"

        if [ ! -z "$issue_title" ]; then
            mr_name="${mr_name} ${issue_title}"
            issue_url="https://${JIRA_INSTANCE}/browse/${issue_key}"
        else
            echo "Unable to get issue title from Jira" >&2
            if [ ! -z "$issue_content" ]; then
                echo "  $issue_content" >&2
            fi
        fi
    fi

    if [ ! -z "$issue_url" ]; then
        mr_title="[${mr_name}](${issue_url})"
    else
        mr_title=${mr_name}
    fi

    ### Commits

    local commits=$(get_git_commits ${current_branch} ${base_branch})

    local commit_prefix="* **"
    local commit_suffix="**<br>"

    commits=$(echo "$commits" | sed "s/^/${commit_prefix}/g")
    commits=$(echo "$commits" | sed "s/$/${commit_suffix}/g")

    cat << EOF

--------------------------------------------------------------------------------

# ${mr_title}


## Commits

${commits}

--------------------------------------------------------------------------------

EOF

    ### Gitlab merge request

    local current_mr_url=$(get_gitlab_merge_request_url ${current_branch})
    local new_mr_url=$(get_gitlab_new_merge_request_url ${current_branch} ${base_branch})
    local mr_url_label
    local mr_url

    if [ ! -z "${current_mr_url}" ]; then
        mr_url_label="Merge request:"
        mr_url=$current_mr_url
    elif [ ! -z "${new_mr_url}" ]; then
        mr_url_label="To create a new merge request:"
        mr_url=$new_mr_url
    fi

    if [ ! -z "$mr_url_label" ]; then
        cat << EOF
${mr_url_label}

  ${mr_url}

EOF
    fi
}


################################################################################
# Run

ISSUE_CODE=${1:-$(guess_issue_code)}
BASE_BRANCH=$2


if [ -z "$JIRA_USER" ];     then echo "JIRA_USER not set"          >&2; fi
if [ -z "$JIRA_INSTANCE" ]; then echo "JIRA_INSTANCE not set"      >&2; fi
if [ -z "$JIRA_TOKEN" ];    then echo "JIRA_TOKEN not set"         >&2; fi
if [ -z "$ISSUE_CODE" ];    then echo "Unable to guess issue code" >&2; fi
if [ -z "$GITLAB_DOMAIN" ]; then echo "GITLAB_DOMAIN not set"      >&2; fi
if [ -z "$GITLAB_TOKEN" ];  then echo "GITLAB_TOKEN not set"       >&2; fi

case $1 in
    help) usage ;;
    *)    print_mr_description ;;
esac
