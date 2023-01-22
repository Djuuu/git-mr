
gitlab_request() {
    case "$1" in
        "projects/my%2Fproject/merge_requests?state=opened&view=simple&source_branch=feature/AB-123-test-feature")
            echo '[{"iid":1,"web_url":"https://gitlab.example.net/some/project/-/merge_requests/1"}]'
            return 0
            ;;

        "projects/my%2Fproject/merge_requests/1")
            local oldDesc
            oldDesc="[AB-123 Test issue](https://mycompany.example.net/browse/AB-123)"
            oldDesc="${oldDesc}$(echo "\n\n## Commits")"
            oldDesc="${oldDesc}$(echo "\n\n* **${c1sha} Feature test - 1**..")"
            oldDesc="${oldDesc}$(echo "\n* **${c2sha} Feature test - 2**..")"
            oldDesc="${oldDesc}$(echo "\n  This is my second commit..")"
            oldDesc="${oldDesc}$(echo "\n* **${c3sha} Feature test - 3**..")"
            oldDesc="${oldDesc}$(echo "\n  This is my third commit..")"
            oldDesc="${oldDesc}$(echo "\n  ")"
            oldDesc="${oldDesc}$(echo "\n  With an extended description")"

            echo '{
                "iid":1, "web_url":"https://gitlab.example.net/some/project/-/merge_requests/1",
                "title":"My MR", "target_branch":"feature/base",
                "description":"'"$oldDesc"'"
            }'
            return 0
            ;;

        *)
            echo "$1" >> mr-extended-gitlab_request.log
            return 1
            ;;
    esac
}

mr_show_status() {
    return 0
}
