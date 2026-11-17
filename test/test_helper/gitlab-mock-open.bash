

git_mr_mock_summary='' # merge request summary returned by Gitlab ('' = no merge request)

open_in_browser() {
    echo "[mock] open $1"
}

mr_status_block() {
    echo "[mock] mr_status_block"
}

git_check_branches() {
    return 0
}

mr_description() {
    echo "[mock] description"
}

gitlab_merge_request_summary() {
    echo "$git_mr_mock_summary"
}

gitlab_new_merge_request_url() {
    echo "https://${GITLAB_DOMAIN}/my/project/-/merge_requests/new"
}
