
gitlab_request() {

    local mrSummaryFields; mrSummaryFields='
        "iid":1,
        "title":"My MR",
        "web_url":"https://gitlab.example.net/some/project/-/merge_requests/1",
        "description":"'"$(gitlab_mr_description)"'"
    '

    case "$1" in
        "projects/my%2Fproject/merge_requests?state=opened&view=simple&source_branch=feature/AB-123-test-feature")
            echo '[{'"$mrSummaryFields"'}]'
            ;;

        "projects/my%2Fproject/merge_requests/1")
            echo '{'"$mrSummaryFields"', "target_branch":"feature/base"}'
            ;;

        "projects/some%2Fproject/merge_requests/1/discussions?per_page=100&page=1")
            echo '[]'
            ;;

        *)
            echo "$1" > mr-gitlab_request.log
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
