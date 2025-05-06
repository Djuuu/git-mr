
gitlab_request() {
    local f="gitlab_request               "

    local url="$1"
    local method="${2:-GET}"

    case "$method" in
        "GET") case "$url" in
            "merge_requests?scope=all&state=all&view=simple&search=AB-123"*)
                # echo "$f✔️ $method $url" >> gitlab-mock-menu.log
                echo '[
                    {"iid": 31,"title":"MR 31 title","web_url":"https://'${GITLAB_DOMAIN}'/proj-C/-/merge_requests/31","state":"opened","project_id":3},
                    {"iid": 11,"title":"MR 11 title","web_url":"https://'${GITLAB_DOMAIN}'/proj-A/-/merge_requests/11","state":"opened","project_id":1},
                    {"iid": 21,"title":"MR 21 title","web_url":"https://'${GITLAB_DOMAIN}'/proj-B/-/merge_requests/21","state":"opened","project_id":2},
                    {"iid": 41,"title":"MR 41 title","web_url":"https://'${GITLAB_DOMAIN}'/proj-D/-/merge_requests/41","state":"closed","project_id":4}
                ]' ;;

            "projects/proj-A/merge_requests/11/discussions"*)
                # echo "$f✔️ $method $url" >> gitlab-mock-menu.log;
                echo '[]'; ;;
            "projects/proj-B/merge_requests/21/discussions"*)
                # echo "$f✔️ $method $url" >> gitlab-mock-menu.log;
                echo '[]'; ;;
            "projects/proj-C/merge_requests/31/discussions"*)
                # echo "$f✔️ $method $url" >> gitlab-mock-menu.log;
                echo '[]'; ;;
            "projects/proj-D/merge_requests/41/discussions"*)
                # echo "$f✔️ $method $url" >> gitlab-mock-menu.log;
                echo '[]'; ;;

            "projects?"*)
                # echo "$f✔️ $method $url" >> gitlab-mock-menu.log
                echo '[
                    {"id":1,"name":"Project A"},
                    {"id":2,"name":"Project B"},
                    {"id":3,"name":"Project C"},
                    {"id":4,"name":"Project D"}
                ]' ;;
            *)
                echo "$f❌ $method $url" >> gitlab-mock-menu.log
                return 1 ;;
        esac ;;

        "PUT") case "$url" in
            "projects/proj-A/merge_requests/11"*)
                # echo "$f✔️ $method $url" >> gitlab-mock-menu.log;
                echo '{"fake": "ok"}'; ;;
            "projects/proj-B/merge_requests/21"*)
                # echo "$f✔️ $method $url" >> gitlab-mock-menu.log;
                echo '{"fake": "ok"}'; ;;
            "projects/proj-C/merge_requests/31"*)
                # echo "$f✔️ $method $url" >> gitlab-mock-menu.log;
                echo '{"fake": "ok"}'; ;;
            *)
                echo "$f❌ $method $url" >> gitlab-mock-menu.log
                return 1 ;;
        esac ;;
    esac
}

gitlab_merge_request() {
    local descr11="# Lorem ipsum\n\n"
    descr11="${descr11}## Menu\n\n"
    descr11="${descr11}* Blabla\n\n"
    descr11="${descr11}--------------------------------------------------------------------------------\n\n"
    descr11="${descr11}Merge request with description\n"
    descr11="${descr11}and previous menu to be updated.\n"

    local descr21="# Deserunt laborum nibh\n\n"
    descr21="${descr21}Merge request with description,\n"
    descr21="${descr21}but missing menu.\n"

    local descr31="# Merge request with only title"

    local f="gitlab_merge_request         "
    case $1 in
        11)
            # echo "$f✔️ $1 $2" >> gitlab-mock-menu.log
            echo '{"iid": 11, "title": "MR 11 title", "project_id": 1, "description": "'${descr11}'",
                "source_branch":"feature/branch-11",
                "web_url": "https://'${GITLAB_DOMAIN}'/proj-A/-/merge_requests/11",
                "head_pipeline": {"status": "running", "web_url": "https://'${GITLAB_DOMAIN}'/proj-A/-/pipelines/11"},
                "state": "opened", "labels": ["QA"], "upvotes": 2, "downvotes": 0, "target_branch": "main", "merge_status": "can_be_merged"}';;
        21)
            # echo "$f✔️ $1 $2" >> gitlab-mock-menu.log
            echo '{"iid": 21, "title": "MR 21 title", "project_id": 2, "description": "'${descr21}'",
                "source_branch":"feature/branch-21",
                "web_url": "https://'${GITLAB_DOMAIN}'/proj-B/-/merge_requests/21",
                "head_pipeline": {"status": "failed", "web_url": "https://'${GITLAB_DOMAIN}'/proj-B/-/pipelines/21"},
                "state": "opened", "labels": ["Review"], "upvotes": 0, "downvotes": 1, "target_branch": "main"}';;
        31)
            # echo "$f✔️ $1 $2" >> gitlab-mock-menu.log
            echo '{"iid": 31, "title": "MR 31 title", "project_id": 3, "description": "'${descr31}'",
                "source_branch":"feature/branch-31",
                "web_url": "https://'${GITLAB_DOMAIN}'/proj-C/-/merge_requests/31",
                "head_pipeline": {"status": "scheduled", "web_url": "https://'${GITLAB_DOMAIN}'/proj-C/-/pipelines/31"},
                "state": "opened", "labels": ["Accepted"], "upvotes": 3, "downvotes": 0, "target_branch": "main", "merge_status": "can_be_merged"}';;
        41)
            # echo "$f✔️ $1 $2" >> gitlab-mock-menu.log
            echo '{"iid": 41, "title": "MR 41 title", "project_id": 4,
                "source_branch":"feature/branch-41",
                "web_url": "https://'${GITLAB_DOMAIN}'/proj-D/-/merge_requests/41",
                "head_pipeline": {"status": "failed", "web_url": "https://'${GITLAB_DOMAIN}'/proj-D/-/pipelines/41"},
                "state": "closed", "labels": ["Review"], "upvotes": 0, "downvotes": 1, "merge_status": }';;
        *)
            echo "$f❌ $1 $2" >> gitlab-mock-menu.log
            return 1 ;;
    esac
}

gitlab_merge_request_approvals() {
    local f="gitlab_merge_request_approvals "
    case $1 in
        'https://gitlab.example.net/proj-A/-/merge_requests/11')
            # echo "$f✔️ $1 $2" >> gitlab-mock-menu.log;
            echo 'true 2/2'; ;;
        'https://gitlab.example.net/proj-B/-/merge_requests/21')
            # echo "$f✔️ $1 $2" >> gitlab-mock-menu.log;
            echo 'false 1/2'; ;;
        'https://gitlab.example.net/proj-C/-/merge_requests/31')
            # echo "$f✔️ $1 $2" >> gitlab-mock-menu.log;
            echo 'true 0/0'; ;;
        'https://gitlab.example.net/proj-D/-/merge_requests/41')
            # echo "$f✔️ $1 $2" >> gitlab-mock-menu.log;
            echo 'true 2/2'; ;;
        *)
            echo "$f❌ $1 $2" >> gitlab-mock-menu.log;
            return 1; ;;
    esac
}

gitlab_merge_request_threads() {
    local f="gitlab_merge_request_threads "
    case $1 in
        'https://gitlab.example.net/proj-A/-/merge_requests/11')
            # echo "$f✔️ $1 $2" >> gitlab-mock-menu.log;
            echo '[]'; ;;
        'https://gitlab.example.net/proj-B/-/merge_requests/21')
            # echo "$f✔️ $1 $2" >> gitlab-mock-menu.log;
            echo '[]'; ;;
        'https://gitlab.example.net/proj-C/-/merge_requests/31')
            # echo "$f✔️ $1 $2" >> gitlab-mock-menu.log;
            echo -e '1	unresolved:false	note_id:1\n2	unresolved:true	note_id:2'; ;;
        'https://gitlab.example.net/proj-D/-/merge_requests/41')
            # echo "$f✔️ $1 $2" >> gitlab-mock-menu.log;
            echo '[]'; ;;
        *)
            echo "$f❌ $1 $2" >> gitlab-mock-menu.log;
            return 1; ;;
    esac
}

clear_screen() {
    return 0 # noop
}
