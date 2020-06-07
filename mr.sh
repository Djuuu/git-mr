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

    To create a Jira API Token, go to: https://id.atlassian.com/manage-profile/security/api-tokens
    (Account Settings -> Security -> API Token -> Create and manage API tokens)

EOF
}

function guess_issue_code
{
    if [ -z "$JIRA_CODE_PATTERN" ]; then
        echo "JIRA_CODE_PATTERN not set" >&2;
        return
    fi

    local current_branch=$(git rev-parse --abbrev-ref HEAD)

    echo $(echo "${current_branch}" | grep -iEo $JIRA_CODE_PATTERN | tail -n1)
}

function get_jira_ticket_data
{
    local auth_token=$(echo -n ${JIRA_USER}:${JIRA_TOKEN} | base64 -w 0)
    local issue_url="https://${JIRA_INSTANCE}/rest/api/3/issue/${1}?fields=summary"

    curl -Ss -X GET \
        -H "Authorization: Basic ${auth_token}" \
        -H "Content-Type: application/json" \
        ${issue_url}
}

function extract_json_value
{
    local key=$1
    local content=$2

    echo $content | grep -Po '"'${key}'"\s*:\s*"\K.*?[^\\]"' | perl -pe 's/\\"/"/g; s/"$//'
}

function get_commits
{
    local current_branch=$(git rev-parse --abbrev-ref HEAD)

    # Base branch param
    local base_branch=$BASE_BRANCH

    # Nearest branch in commit history
    if [ -z "$base_branch" ]; then
        local base_branch=$(git show-branch | grep '*' | grep -v "${current_branch}" | head -n1 | sed 's/.*\[\(.*\)\].*/\1/' | sed 's/[\^~].*//')
    fi

    # First possible merge base
    if [ -z "$base_branch" ]; then
        base_branch=$(git show-branch  --merge-base | head -n1)
    fi

    git log --oneline --reverse --no-decorate ${base_branch}..${current_branch}
}

function print_mr_description
{
    local issue_content=$(get_jira_ticket_data $ISSUE_CODE)

    local issue_key=$(extract_json_value "key" "$issue_content")
    local issue_title=$(extract_json_value "summary" "$issue_content")

    if [ -z "$issue_key" ]; then
        issue_key=${ISSUE_CODE^^}
    fi
    if [ -z "$issue_title" ]; then
        echo "Unable to get issue title from Jira" >&2
        echo "$issue_content" >&2
        echo
    fi

    local mr_title="${issue_key} ${issue_title}"
    local issue_url="https://${JIRA_INSTANCE}/browse/${issue_key}"

    local commit_prefix="* **"
    local commit_suffix="**<br>"

    cat << EOF
--------------------------------------------------------------------------------

# [${mr_title}](${issue_url})


## Commits

$(get_commits | sed "s/^/${commit_prefix}/g" | sed "s/$/${commit_suffix}/g")

--------------------------------------------------------------------------------
EOF
}


################################################################################
# Run

ISSUE_CODE=${1:-$(guess_issue_code)}
BASE_BRANCH=$2

if [ -z "$JIRA_USER" ];     then echo "JIRA_USER not set"          >&2; usage; exit 1; fi
if [ -z "$JIRA_INSTANCE" ]; then echo "JIRA_INSTANCE not set"      >&2; usage; exit 2; fi
if [ -z "$JIRA_TOKEN" ];    then echo "JIRA_TOKEN not set"         >&2; usage; exit 3; fi
if [ -z "$ISSUE_CODE" ];    then echo "Unable to guess issue code" >&2; usage; exit 4; fi

case $1 in
    help) usage ;;
    *)    print_mr_description ;;
esac
