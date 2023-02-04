JIRA_INSTANCE="mycompany.example.net"

jira_ticket_data() {
    case $1 in
        "AB-123") echo '{"key":"AB-123", "fields":{"summary":"This is an issue"}}' ;;
        *) return 1 ;;
    esac
}
