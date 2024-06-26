
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

        "projects?simple=true&archived=false&order_by=last_activity_at&per_page="*)
            # echo "$f✔️ $1" >> gitlab-mock-search.log
            echo '[
                {"id": 1, "name": "Project A", "path_with_namespace": "public-group/project-a"},
                {"id": 2, "name": "Project B", "path_with_namespace": "public-group/project-b"},
                {"id": 3, "name": "Project C", "path_with_namespace": "private-group/project-c"},
                {"id": 4, "name": "Project D", "path_with_namespace": "private-group/project-d"}
            ]'
            ;;

        "projects?simple=true&membership=true&archived=false&order_by=last_activity_at&per_page="*)
            # echo "$f✔️ $1" >> gitlab-mock-search.log
            echo '[
                {"id": 3, "name": "Project C", "path_with_namespace": "private-group/project-c"},
                {"id": 4, "name": "Project D", "path_with_namespace": "private-group/project-d"}
            ]'
            ;;

        *)
            echo "$f❌ $1" >> gitlab-mock-search.log
            return 1
            ;;
    esac
}
