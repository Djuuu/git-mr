GITLAB_DOMAIN="example.com"
GITLAB_TOKEN="example"

gitlab_merge_requests_search() {
    echo '{"iid": 31,"title":"MR 31 title","web_url":"https://example.net/31","state":"opened","project_id": 3}
          {"iid": 11,"title":"MR 11 title","web_url":"https://example.net/11","state":"opened","project_id": 1}
          {"iid": 21,"title":"MR 21 title","web_url":"https://example.net/21","state":"opened","project_id": 2}
          {"iid": 41,"title":"MR 41 title","web_url":"https://example.net/21","state":"closed","project_id": 4}'
}

gitlab_projects() {
    echo '[{"id":1,"name":"Project A"},
           {"id":2,"name":"Project B"},
           {"id":3,"name":"Project C"},
           {"id":4,"name":"Project D"}]'
}
