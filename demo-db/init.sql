-- demo-db/init.sql
-- Create our laboratory schema

CREATE TABLE customers (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE
);

CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    customer_id INTEGER REFERENCES customers(id),
    total_amount DECIMAL(10, 2) NOT NULL,
    status VARCHAR(50) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE payments (
    id SERIAL PRIMARY KEY,
    order_id INTEGER REFERENCES orders(id),
    amount DECIMAL(10, 2) NOT NULL,
    status VARCHAR(50) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE refunds (
    id SERIAL PRIMARY KEY,
    order_id INTEGER REFERENCES orders(id),
    amount DECIMAL(10, 2) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE shipments (
    id SERIAL PRIMARY KEY,
    order_id INTEGER REFERENCES orders(id),
    shipped_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Seed Valid Data
INSERT INTO customers (id, email) VALUES 
(1, 'alice@example.com'),
(2, 'bob@example.com');

-- Valid Order #1: Order 100, Payment 100, Refund 20, Shipment after order
INSERT INTO orders (id, customer_id, total_amount, status, created_at) 
VALUES (1, 1, 100.00, 'SHIPPED', '2026-09-01 10:00:00');

INSERT INTO payments (id, order_id, amount, status, created_at) 
VALUES (1, 1, 100.00, 'SUCCESS', '2026-09-01 10:05:00');

INSERT INTO refunds (id, order_id, amount, created_at) 
VALUES (1, 1, 20.00, '2026-09-02 14:00:00');

INSERT INTO shipments (id, order_id, shipped_at) 
VALUES (1, 1, '2026-09-01 15:00:00');

-- Valid Order #2: Order 50, Payment 50, No Refund
INSERT INTO orders (id, customer_id, total_amount, status, created_at) 
VALUES (2, 2, 50.00, 'PAID', '2026-09-10 11:00:00');

INSERT INTO payments (id, order_id, amount, status, created_at) 
VALUES (2, 2, 50.00, 'SUCCESS', '2026-09-10 11:01:00');


-- Seed Intentional Bugs (Invalid Data)

-- Bug 1: Refund amount > Order total (Order 3)
INSERT INTO orders (id, customer_id, total_amount, status, created_at) 
VALUES (3, 1, 100.00, 'CANCELLED', '2026-09-12 09:00:00');
INSERT INTO payments (id, order_id, amount, status, created_at) 
VALUES (3, 3, 100.00, 'SUCCESS', '2026-09-12 09:05:00');
-- 🚨 INVARIANT VIOLATION: Refund > Order total
INSERT INTO refunds (id, order_id, amount, created_at) 
VALUES (2, 3, 150.00, '2026-09-13 10:00:00'); 

-- Bug 2: Payment amount < Order total but order is 'PAID' (Order 4)
INSERT INTO orders (id, customer_id, total_amount, status, created_at) 
VALUES (4, 2, 200.00, 'PAID', '2026-09-14 08:00:00');
-- 🚨 INVARIANT VIOLATION: Payment < Order total for a 'PAID' order
INSERT INTO payments (id, order_id, amount, status, created_at) 
VALUES (4, 4, 150.00, 'SUCCESS', '2026-09-14 08:15:00');

-- Bug 3: Shipment timestamp < Order timestamp (Order 5)
INSERT INTO orders (id, customer_id, total_amount, status, created_at) 
VALUES (5, 1, 75.00, 'SHIPPED', '2026-09-15 12:00:00');
INSERT INTO payments (id, order_id, amount, status, created_at) 
VALUES (5, 5, 75.00, 'SUCCESS', '2026-09-15 12:05:00');
-- 🚨 INVARIANT VIOLATION: Shipped BEFORE it was ordered
INSERT INTO shipments (id, order_id, shipped_at) 
VALUES (2, 5, '2026-09-15 10:00:00');

-- Bug 4: Negative order total (Order 6)
-- 🚨 INVARIANT VIOLATION: Order total < 0
INSERT INTO orders (id, customer_id, total_amount, status, created_at) 
VALUES (6, 2, -25.00, 'PENDING', '2026-09-16 14:00:00');

-- Bug 5: Orphan payment (Payment 6 points to non-existent Order 999)
-- 🚨 INVARIANT VIOLATION: Payment has no valid order (Wait, FK will block this!)
-- Let's drop the FK constraint for this specific test case temporarily, or 
-- just omit the FK on the payments table if we want to simulate a broken database.
-- Actually, a better "orphan payment" is one where the order_id IS NULL or it points 
-- to a deleted order if ON DELETE CASCADE wasn't used. Let's make order_id nullable to allow the bug.

ALTER TABLE payments ALTER COLUMN order_id DROP NOT NULL;

-- 🚨 INVARIANT VIOLATION: Orphan payment (order_id is NULL)
INSERT INTO payments (id, order_id, amount, status, created_at) 
VALUES (6, NULL, 50.00, 'SUCCESS', '2026-09-17 09:00:00');

-- Adjust sequences so future inserts don't fail
SELECT setval('customers_id_seq', (SELECT MAX(id) FROM customers));
SELECT setval('orders_id_seq', (SELECT MAX(id) FROM orders));
SELECT setval('payments_id_seq', (SELECT MAX(id) FROM payments));
SELECT setval('refunds_id_seq', (SELECT MAX(id) FROM refunds));
SELECT setval('shipments_id_seq', (SELECT MAX(id) FROM shipments));
