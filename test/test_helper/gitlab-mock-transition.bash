
git_mr_mock_labels='"My Team"'
git_mr_mock_title="My MR"

gitlab_request() {
    case "$1" in
        "projects/my%2Fproject/merge_requests?state=opened&view=simple&source_branch=feature/AB-123-test-feature")
            echo '[{"iid":1, "title":"'"$git_mr_mock_title"'"}]'
            ;;

        "projects/my%2Fproject/merge_requests/1")
            echo '{"iid":1, "title":"'"$git_mr_mock_title"'", "labels":['"$git_mr_mock_labels"']}'
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

            if [[ "$2" == "POST" ]]; then
                return 0;
            fi

            echo '{"transitions": [
                {"id":"1", "name":"TODO",        "to":{"id":"1", "name":"TODO",        "statusCategory":{"name":"To Do"}}},
                {"id":"2", "name":"In Progress", "to":{"id":"2", "name":"In Progress", "statusCategory":{"name":"In Progress"}}},
                {"id":"3", "name":"Code Review", "to":{"id":"3", "name":"Code Review", "statusCategory":{"name":"In Progress"}}},
                {"id":"4", "name":"QA",          "to":{"id":"4", "name":"QA",          "statusCategory":{"name":"In Progress"}}},
                {"id":"5", "name":"Ready to go", "to":{"id":"5", "name":"Ready to go", "statusCategory":{"name":"In Progress"}}},
                {"id":"6", "name":"Delivered",   "to":{"id":"6", "name":"Delivered",   "statusCategory":{"name":"Done"}}}
            ]}'
            ;;

        *)
            echo "$1" > mr-accept-jira_request.log
            return 1
            ;;
    esac
}

# Irrelevant to test
mr_print_title () {
    return 0
}

# Irrelevant to test
mr_print_status () {
    return 0
}
