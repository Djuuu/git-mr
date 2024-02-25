
gitlab_mr_description() {
    echo -n "[AB-123 Test issue](https://mycompany.example.net/browse/AB-123)"
    echo -n "\n\n## Commits"
    echo -n "\n\n* **${c1sha} Feature test - descr 1**"
    echo -n "\n* **${c2href} Feature test - descr 2**.."
    echo -n "\n  This is my second commit.."
    echo -n "\n* **${c3href} Feature test - descr 3**.."
    echo -n "\n  This is my third commit.."
    echo -n "\n  "
    echo -n "\n  With an extended description"
}
