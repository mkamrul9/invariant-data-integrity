# Invariant

Continuous data integrity monitoring for production applications.

Your application can be:

✓ Running
✓ Healthy
✓ Passing health checks
✓ Returning HTTP 200

...and still be corrupting your data.

Invariant continuously checks the business rules your data must obey.

## Example

Define your rules in a simple YAML file:

```yaml
rules:
  - name: positive_order_amount
    check: "orders.total_amount > 0"

  - name: valid_order_status
    check: "orders.status IN ('pending', 'paid', 'shipped', 'cancelled')"

  - name: refund_limit
    check: "refunds.amount <= orders.total_amount"
```

Run Invariant against your database:

```bash
$ pip install invariant-cli
$ invariant check
```

Output:

```
Invariant v0.1

Database: PostgreSQL
Records checked: 284,921
Rules: 23

✓ positive_order_amount
✓ valid_order_status
✓ payment_matches_order
✓ refund_within_order
✓ shipment_after_payment

✗ user_balance_matches_transactions

3 violations found.

Exit code: 1
```

## Why Invariant?

Existing monitoring tools (like Prometheus or Datadog) tell you if your application is *up* and *fast*. Invariant tells you if your application is *correct*.

Invariant is designed to be run:
*   **Locally** by developers to test complex logic.
*   **In CI/CD pipelines** to prevent regressions before they reach production.
*   **Continuously in production** (`invariant watch`) to alert immediately when data becomes inconsistent.

## Documentation

*   [Problem & Scope](docs/01-problem-and-scope.md)

## License
MIT
