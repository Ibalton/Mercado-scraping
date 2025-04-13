-- +goose Up
-- +goose StatementBegin
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE TABLE clients (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE queries (
    id SERIAL PRIMARY KEY,
    query_text TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    removed_at TIMESTAMP DEFAULT NULL
);

CREATE TYPE query_frequency AS ENUM (
    'hourly',
    'daily',
    'weekly',
    'monthly'
);

CREATE TABLE client_queries (
    id SERIAL PRIMARY KEY,
    client_id INT NOT NULL,
    query_id INT NOT NULL,
    frequency query_frequency NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    removed_at TIMESTAMP DEFAULT NULL,
    FOREIGN KEY (client_id) REFERENCES clients(id),
    FOREIGN KEY (query_id) REFERENCES queries(id)
);

CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    manual_override BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE product_embeddings (
    id SERIAL PRIMARY KEY,
    product_id INT UNIQUE REFERENCES products(id),
    embedding VECTOR(384) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE product_candidates (
    id SERIAL PRIMARY KEY,
    new_product_name TEXT NOT NULL,
    matched_product_id INT REFERENCES products(id),
    match_method TEXT NOT NULL,  -- 'vector', 'levenshtein', 'manual'
    distance FLOAT,
    decided BOOLEAN DEFAULT FALSE,
    decided_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE marketplaces (
    id SERIAL PRIMARY KEY,
    name TEXT,
    region TEXT,
    domain TEXT
);

CREATE TABLE listings (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id INT REFERENCES products(id),
    marketplace_id INT REFERENCES marketplaces(id),
    external_id TEXT,
    title TEXT,
    url TEXT,
    seller TEXT,
    condition TEXT,
    availability TEXT,
    last_seen TIMESTAMP
);

CREATE TABLE prices (
    id SERIAL PRIMARY KEY,
    listing_id TEXT REFERENCES listings(id),
    price NUMERIC,
    currency TEXT,
    scraped_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_products_name_trgm ON products USING gin (name gin_trgm_ops);
-- +goose StatementEnd


-- +goose Down
-- +goose StatementBegin
DROP TABLE IF EXISTS product_candidates;
DROP TABLE IF EXISTS product_embeddings;
DROP TABLE IF EXISTS prices;
DROP TABLE IF EXISTS listings;
DROP TABLE IF EXISTS marketplaces;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS client_queries;
DROP TABLE IF EXISTS queries;
DROP TABLE IF EXISTS clients;
DROP TYPE IF EXISTS query_frequency;
DROP EXTENSION IF EXISTS pg_trgm;
DROP EXTENSION IF EXISTS vector;
-- +goose StatementEnd
