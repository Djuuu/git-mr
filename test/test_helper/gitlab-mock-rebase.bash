git_mr_mock_rebase_state="done"   # done | error | progress

mr_status_block() { return 0; }   # Irrelevant to test
sleep() { return 0; }             # No actual waiting

git_mr_mock_pull_status=0
git() {
    if [[ $1 == "pull" ]]; then
        echo "[mock] git pull"
        return "$git_mr_mock_pull_status"
    fi
    command git -c include.path="${BATS_TEST_DIRNAME}/.gitconfig" "$@"
}
mr_update() { echo "[mock] mr_update $1"; }

gitlab_request() {
    case "$1" in
        "projects/my%2Fproject/merge_requests?state=opened&view=simple&source_branch=feature/AB-123-test-feature")
            echo "$1 $2" >> mr-rebase-gitlab_request.log
            echo '[{"iid":1, "title":"My MR"}]'
            ;;

        "projects/my%2Fproject/merge_requests/1/rebase"|"projects/my%2Fproject/merge_requests/1/rebase?skip_ci=true")
            echo "$1 $2" >> mr-rebase-gitlab_request.log
            echo '{"rebase_in_progress":true}'
            ;;

        "projects/my%2Fproject/merge_requests/1?include_rebase_in_progress=true")
            echo "$1" >> mr-rebase-gitlab_request.log
            case "$git_mr_mock_rebase_state" in
                done)  echo '{"rebase_in_progress":false, "merge_error":null}' ;;
                error) echo '{"rebase_in_progress":false, "merge_error":"Rebase failed. Please rebase locally"}' ;;
                progress)
                    # in progress on first call, done on following ones
                    if [[ -f mr-rebase-polled ]]; then
                        echo '{"rebase_in_progress":false, "merge_error":null}'
                    else
                        touch mr-rebase-polled
                        echo '{"rebase_in_progress":true}'
                    fi
                    ;;
            esac
            ;;

        *)
            echo "$1" > mr-rebase-unexpected_request.log
            return 1
            ;;
    esac
}
