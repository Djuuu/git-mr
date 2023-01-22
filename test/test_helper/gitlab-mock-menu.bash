
gitlab_request() {
    case "$1" in
        "merge_requests?scope=all&state=all&view=simple&search=AB-123"*)
            echo '[
                {"iid": 31,"title":"MR 31 title","web_url":"https://example.net/31","state":"opened","project_id": 3},
                {"iid": 11,"title":"MR 11 title","web_url":"https://example.net/11","state":"opened","project_id": 1},
                {"iid": 21,"title":"MR 21 title","web_url":"https://example.net/21","state":"opened","project_id": 2},
                {"iid": 41,"title":"MR 41 title","web_url":"https://example.net/21","state":"closed","project_id": 4}
            ]'
            return 0
            ;;

        "projects?"*)
            echo '[
                {"id":1,"name":"Project A"},
                {"id":2,"name":"Project B"},
                {"id":3,"name":"Project C"},
                {"id":4,"name":"Project D"}
            ]'
            return 0
            ;;

        *)
            echo "$1" > mr-menu-gitlab_request.log
            return 1
            ;;
    esac
}
