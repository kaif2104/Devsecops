-- Migration V1: Initial Products Table & Schema Versioning

CREATE TABLE IF NOT EXISTS schema_migrations (
    version VARCHAR(100) PRIMARY KEY,
    applied_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS products (
    id SERIAL PRIMARY KEY,
    productname VARCHAR(255) NOT NULL,
    price NUMERIC(10, 2) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Seed initial data if empty
INSERT INTO products (productname, price) VALUES
('Cloud DevOps Laptop', 84999.00),
('Wireless Ergonomic Mouse', 1499.50),
('Mechanical RGB Keyboard', 3999.00)
ON CONFLICT DO NOTHING;

INSERT INTO schema_migrations (version) VALUES ('V1__init.sql')
ON CONFLICT (version) DO NOTHING;
