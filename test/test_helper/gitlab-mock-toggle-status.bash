GITLAB_CR_LABELS="Review"
GITLAB_QA_LABELS="Testing"
GITLAB_OK_LABELS="Accepted"

JIRA_INSTANCE="mycompany.example.net"
JIRA_USER="me"
JIRA_TOKEN="hcnoiuyrsqgl"
JIRA_IP_ID="110"
JIRA_CR_ID="120"
JIRA_QA_ID="130"
JIRA_OK_ID="140"

mr_status_block() {
    return 0
}

gitlab_request() {
    case "$1" in
        "projects/my%2Fproject/merge_requests?state=opened&view=simple&source_branch=feature/AB-123-test-feature")
            echo '[{"iid":1, "title":"Draft: My MR"}]'
            ;;

        "projects/my%2Fproject/merge_requests/1")
            echo '{"iid":1, "title":"Draft: My MR", "labels":['"$GIT_MR_MOCK_LABELS"']}'
            ;;

        *)
            echo "$1" > mr-accept-gitlab_request.log
            return 1
            ;;
    esac
}

jira_request() {
    case "$1" in
        "issue/AB-123/transitions")
            ;;
        *)
            echo "$1" > mr-accept-jira_request.log
            return 1
            ;;
    esac
}
