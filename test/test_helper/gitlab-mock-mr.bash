GITLAB_DOMAIN="example.com"
GITLAB_TOKEN="example"

function gitlab_merge_requests_for_branch {
    echo '[{"iid":1,"web_url":"https://example.com/some/project/-/merge_requests/1"}]'
}

function gitlab_merge_request {
    local oldDesc
    oldDesc="[AB-123 Test issue](https://mycompany.example.net/browse/AB-123)"
    oldDesc="${oldDesc}$(echo "\n\n## Commits")"
    oldDesc="${oldDesc}$(echo "\n\n* **${c1sha} Feature test - 1**..")"
    oldDesc="${oldDesc}$(echo "\n* **${c2sha} Feature test - 2**..")"
    oldDesc="${oldDesc}$(echo "\n* **${c3sha} Feature test - 3**")"

    echo '{
      "iid":1, "web_url":"https://example.com/some/project/-/merge_requests/1",
      "title":"My MR", "target_branch":"feature/base",
      "description":"'"$oldDesc"'"
    }'
}

function mr_actions {
    return 0
}
