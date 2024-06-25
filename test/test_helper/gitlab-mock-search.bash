
gitlab_request() {
    local f="gitlab_request               "
    case "$1" in
        "merge_requests?scope=all&state=all&view=simple&search=AB-123"*)
            # echo "$f✔️ $1" >> gitlab-mock-search.log
            echo '[
                {"iid": 31,"title":"MR 31 title","web_url":"https://'${GITLAB_DOMAIN}'/public-group/proj-C/-/merge_requests/31","state":"opened", "project_id": 3},
                {"iid": 11,"title":"MR 11 title","web_url":"https://'${GITLAB_DOMAIN}'/public-group/proj-A/-/merge_requests/11","state":"opened", "project_id": 1},
                {"iid": 21,"title":"MR 21 title","web_url":"https://'${GITLAB_DOMAIN}'/private-group/proj-B/-/merge_requests/21","state":"opened", "project_id": 2},
                {"iid": 41,"title":"MR 41 title","web_url":"https://'${GITLAB_DOMAIN}'/private-group/proj-D/-/merge_requests/41","state":"closed", "project_id": 4}
            ]'
            ;;

        "groups/private-group/merge_requests?scope=all&state=all&view=simple&search=AB-123"*)
            # echo "$f✔️ $1" >> gitlab-mock-search.log
            echo '[
                {"iid": 21,"title":"MR 21 title","web_url":"https://'${GITLAB_DOMAIN}'/private-group/proj-B/-/merge_requests/21","state":"opened", "project_id": 2},
                {"iid": 41,"title":"MR 41 title","web_url":"https://'${GITLAB_DOMAIN}'/private-group/proj-D/-/merge_requests/41","state":"closed", "project_id": 4}
            ]'
            ;;

        *)
            echo "$f❌ $1" >> gitlab-mock-search.log
            return 1
            ;;
    esac
}
