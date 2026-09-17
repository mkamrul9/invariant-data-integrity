# Phase 2 — Understanding and Connecting to PostgreSQL

## 1. Introduction
Before writing any validation logic, Invariant needs to understand its environment. It must connect to PostgreSQL, discover the existing schema, and safely execute SQL. This document traces the theoretical journey of how a Python application communicates with a PostgreSQL database, highlighting why each layer exists and why we chose our specific tools.

## 2. The Connection Journey
When Invariant runs, what actually happens between our Python code and the database?

### Python → psycopg
Our Python application uses `psycopg` (specifically `psycopg 3`), a database adapter. `psycopg` implements the Python DB-API 2.0 specification but, crucially, it acts as a highly optimized wrapper around `libpq`, the official C library for PostgreSQL. We use `psycopg` because it allows us to interact with PostgreSQL *directly*—handling data types, binary protocols, and asynchronous connections without the obfuscation of an ORM.

### psycopg → TCP Connection
`psycopg` asks the operating system to open a TCP socket to the PostgreSQL server (typically port `5432`). 

### TCP Connection → PostgreSQL Server
PostgreSQL receives the connection request. Before any SQL can be executed, the connection goes through several phases:
1. **Startup:** Python sends a startup message with the requested database and user.
2. **Authentication:** PostgreSQL challenges the client (e.g., asking for a password, which `psycopg` hashes using SCRAM-SHA-256 and returns).
3. **Session:** Once authenticated, a session is established. PostgreSQL assigns a backend process (or worker) specifically to handle our connection.

## 3. Database vs. Schema
It is a common misconception that "Database" and "Schema" are synonymous. In PostgreSQL:
- A **Cluster** contains multiple **Databases**.
- A **Database** contains multiple **Schemas** (by default, `public`).
- A **Schema** is a namespace that contains **Tables**, **Views**, **Functions**, etc.

Invariant needs to know which database *and* which schema it is validating to accurately resolve table names like `orders` or `payments`.

## 4. SQL Execution and Parameterized Queries
When we want to execute a query, we do not concatenate strings:
```python
# ❌ DANGEROUS: SQL Injection Risk
cursor.execute(f"SELECT * FROM users WHERE id = {user_id}")
```
Instead, we use parameterized queries:
```python
# ✅ SAFE: Parameterized Query
cursor.execute("SELECT * FROM users WHERE id = %s", (user_id,))
```
Why? Because with parameterized queries, `psycopg` separates the SQL *statement* from the *data*. PostgreSQL parses the statement, compiles an execution plan, and *then* safely injects the data. This makes SQL injection mathematically impossible because the data is never parsed as executable code.

## 5. Transactions and Isolation
PostgreSQL is fully ACID compliant. By default, `psycopg` operates within a transaction block.
- `BEGIN`: Starts the transaction.
- `COMMIT`: Saves the changes.
- `ROLLBACK`: Aborts the changes.

For Invariant, we are primarily **reading** data. However, **Transaction Isolation** is crucial. If an order is currently being inserted by the application, we don't want Invariant to read half-committed data (a dirty read). PostgreSQL uses **MVCC (Multi-Version Concurrency Control)**, ensuring that Invariant always sees a consistent snapshot of the database at the exact moment its transaction began, even while other applications are actively writing to it.

## 6. System Catalogs (Introspection)
How does Invariant know that the `orders` table exists or that `total_amount` is a decimal?
PostgreSQL stores metadata about itself in specialized tables called **System Catalogs** (prefixed with `pg_`).
For example:
- `pg_class`: Contains information about tables and indexes.
- `pg_attribute`: Contains information about table columns.
- `pg_type`: Contains data types.

Before Invariant evaluates a rule like `orders.total_amount >= 0`, it will query these system catalogs to verify:
1. Does `orders` exist?
2. Does `total_amount` exist?
3. Is it a numeric type that supports `>= 0`?

This prevents the engine from crashing on malformed rules or sending garbage SQL to the execution engine.

## 7. Resource Management and Failure Handling
Connections are expensive. While an application might use connection pooling (like `PgBouncer`), a CLI tool like Invariant will likely open a single connection, perform its checks, and close it.

We must handle failures gracefully:
- **Connection Refused:** PostgreSQL isn't running or the port is blocked.
- **Authentication Failed:** Wrong password or user.
- **Query Timeout:** A rule took too long (we must set `statement_timeout` to prevent blocking the database).
- **Resource Cleanup:** We must ensure `cursor.close()` and `connection.close()` are always called (using Python context managers `with psycopg.connect(...) as conn:`), even if an error occurs.

## 8. Summary
By understanding the entire lifecycle—from the Python adapter down to the TCP socket, MVCC transactions, and system catalogs—we can build a tool that safely, securely, and efficiently introspects the database without causing performance degradation or relying on fragile string manipulation.
