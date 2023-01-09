JIRA_INSTANCE="mycompany.example.net"

function jira_ticket_data {
    echo '{
      "key":"AB-123",
      "fields":{"summary":"This is an issue"}
    }'
}
