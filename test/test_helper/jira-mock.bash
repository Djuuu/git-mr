
jira_ticket_data() {
    case $1 in
        "AB-123") echo '{"key":"AB-123", "fields":{"summary":"This is an issue"}}' ;;
        "EF-789") echo '{"key":"EF-789", "fields":{}}' ;;
        *) return 1 ;;
    esac
}
