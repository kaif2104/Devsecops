-- Migration V2: Add Stock / Inventory Column (Controlled Schema Evolution)

ALTER TABLE products ADD COLUMN IF NOT EXISTS stock INT DEFAULT 100;

INSERT INTO schema_migrations (version) VALUES ('V2__add_inventory.sql')
ON CONFLICT (version) DO NOTHING;
