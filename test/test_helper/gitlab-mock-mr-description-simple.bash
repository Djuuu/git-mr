
gitlab_mr_description() {
    echo -n "[AB-123 Test issue](https://mycompany.example.net/browse/AB-123)"
    echo -n "\n\n## Commits"
    echo -n "\n\n* **${c1sha} Feature test - 1**.."
    echo -n "\n* **${c2sha} Feature test - 2**.."
    echo -n "\n* **${c3sha} Feature test - 3**"
}
