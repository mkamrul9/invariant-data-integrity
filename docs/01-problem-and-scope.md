# Invariant — Problem & Scope

## 1. Problem
Applications often have data that appears correct to traditional monitoring systems but violates fundamental business logic. An application can be perfectly healthy—returning HTTP 200s, utilizing normal CPU/memory, and maintaining database connections—while silently writing invalid data. For example, a system might record a `$150` refund for a `$100` order. From an infrastructure perspective, this is fine; from a business perspective, it is a critical correctness failure.

## 2. Why Existing Monitoring Is Not Enough
Existing monitoring tools (Prometheus, Datadog, OpenTelemetry) excel at measuring **availability** ("Is it up?") and **performance** ("Is it fast?"). They measure latency, error rates, and resource utilization. However, they do not inherently understand **correctness** ("Is it right?"). They cannot look at two valid database rows and determine that their relationship violates business rules. Invariant focuses exclusively on correctness.

## 3. What Is a Data Invariant?
An invariant is a condition or business rule that must remain true for the system to be considered logically correct. It goes beyond database constraints (like foreign keys or non-null fields) and encapsulates complex application logic.
Examples include:
*   **Order invariant:** `order.total_amount >= 0`
*   **Relationship invariant:** `refund.amount <= order.total_amount`
*   **State invariant:** `shipped_at IS NOT NULL` requires `order.status = 'SHIPPED'`

## 4. Example Failure
Consider a standard e-commerce database:
*   `Order #1001` with `total = $100`
*   `Payment #501` with `amount = $100`

A developer accidentally introduces a bug where refunds are doubled.
*   `Refund #701` is processed with `amount = $150`.

The application doesn't crash. The database successfully commits the transaction. CPU and latency are normal. Yet, a fundamental business rule (`refund <= order_total`) has been broken.

## 5. Target Users
Invariant is designed to be useful across the engineering spectrum:
*   **Junior Developers:** Can easily write simple rules in YAML (e.g., `orders.total_amount >= 0`) to safeguard their data.
*   **Backend Developers:** Can express complex cross-table constraints and run them locally or in CI pipelines.
*   **Production Teams:** Can run Invariant continuously (`invariant watch`) to detect production violations in real-time.
*   **Large Organizations:** Can eventually use Invariant to track CDC (Change Data Capture), identify exactly which deployment caused a regression, and perform forensics on corrupted data.

## 6. MVP
The Minimum Viable Product (Phase 1-6) will consist of:
*   **Database:** PostgreSQL integration.
*   **Configuration:** YAML-based rules definition.
*   **Validation Engine:** Translating YAML invariants into SQL queries that find violating records.
*   **CLI:** `invariant check` for manual and CI/CD validation.
*   **Output:** Human-readable terminal reports and machine-readable JSON formats.
*   **Exit Codes:** Proper distinguishing between data correctness failures (exit code 1) and tool/connection failures (exit code 2).

## 7. Non-Goals
To prevent feature creep and ensure a focused initial release, we are explicitly **NOT** building:
*   Machine Learning or "AI-powered" anomaly detection (problems are deterministic).
*   Graph databases or complex multi-database orchestration.
*   Streaming platforms (Kafka).
*   Kubernetes deployments or infrastructure orchestration.
*   A web frontend/dashboard (the CLI is sufficient).
*   Microservice architectures (a single process is fine).

## 8. Initial Architecture
The system follows a strict, unidirectional pipeline to separate concerns:
`YAML Config` → `Parser` → `Validated Rules` → `Validation Engine` → `SQL Generation` → `PostgreSQL` → `Violation Results` → `Report Formatter`

Configuration parsing must never directly execute SQL. This separation ensures security, testability, and future extensibility.

## 9. Technology Choices
*   **Language:** Python 3.12+ (Excellent for CLI tooling, parsing, DB interaction, and DevOps familiarity).
*   **Database Driver:** `psycopg` 3 (Direct database interaction is required to understand SQL, transactions, and execution; an ORM hides necessary complexity).
*   **CLI Framework:** `Typer` (Clean, modern Python CLI development).
*   **Configuration:** `YAML` (Human-readable, easy to diff in version control).
*   **Testing:** `pytest` (For unit, integration, and E2E database tests).

## 10. Alternatives Considered
*   **Building a generic ORM-based tool:** Rejected because we need to directly leverage database-specific execution, metadata, and optimization.
*   **Supporting multiple databases (MySQL, SQLite) at MVP:** Rejected because abstracting away differences in SQL dialects, execution models, and metadata APIs early on distracts from solving the core correctness problem.
*   **Using a complex DSL instead of SQL inside YAML:** Rejected because SQL is universally understood for querying data; inventing a new DSL creates unnecessary friction.

## 11. Security Risks
*   **SQL Injection:** Since Invariant generates SQL based on user-provided YAML, a malicious user could potentially execute destructive queries (e.g., `check: "...; DROP TABLE users;"`).
    *   *Mitigation:* Strict validation of rule inputs. The engine will safely construct validation queries, separating trusted configuration from untrusted runtime input, and potentially restricting the database user's privileges to read-only access.

## 12. Performance Risks
*   **Full-Table Scans:** Running complex invariants across tables with hundreds of millions of rows can destroy database performance.
    *   *Mitigation:* For the MVP, we assume moderate data volumes and prioritize correctness. Later phases will introduce incremental validation (only checking changed rows via CDC) and query optimization. We will measure before optimizing.

## 13. Success Criteria
Phase 1 is successful when:
*   A clear specification exists (this document).
*   The problem space is narrowly defined (correctness monitoring, not infrastructure monitoring).
*   The architecture securely separates parsing from execution.
*   A concrete MVP scope is established (PostgreSQL, CLI, YAML).

The MVP itself is successful when:
*   A developer can run `invariant check` and it correctly exits with `0` for healthy data, `1` for violations, and `2` for systemic errors.
*   The tool outputs clear, actionable reports pinpointing violating records.

## 14. Future Evolution
Once the MVP proves valuable, the system can evolve to support:
*   **Incremental Checking:** Validating only records that have changed using CDC.
*   **Temporal Invariants:** Checking event ordering (e.g., "refund must occur after payment").
*   **Forensics:** Linking violations to specific Git commits or deployments.
*   **Multi-system Validation:** Ensuring consistency across PostgreSQL, Kafka, and Redis.

## 15. Phase 1 Lessons
*   **Problem definition is critical:** Focusing on "correctness" instead of general "monitoring" changes the entire trajectory of the project.
*   **Restraint is a feature:** Explicitly rejecting ML, Kafka, and dashboards for the MVP ensures we actually ship a useful tool rather than getting bogged down in infrastructure.
*   **Architecture follows responsibility:** Separating the YAML parser from SQL generation is a foundational security and testability decision.
*   **Inversion of logic:** Instead of trying to prove a rule is true everywhere, the engine is designed to search for records where the rule is false. This is the core algorithmic insight.
