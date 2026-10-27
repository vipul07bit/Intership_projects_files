-- Virtual Retail Environment
-- PostgreSQL schema for Task 1: Data Modeling and Architecture Design
-- Run this script in a new/empty database. Review the README before use.

BEGIN;

CREATE TABLE customers (
    customer_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    full_name VARCHAR(150) NOT NULL,
    email VARCHAR(255) UNIQUE,
    phone VARCHAR(30),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE categories (
    category_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT
);

CREATE TABLE products (
    product_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    category_id BIGINT REFERENCES categories(category_id) ON DELETE SET NULL,
    sku VARCHAR(60) NOT NULL UNIQUE,
    product_name VARCHAR(200) NOT NULL,
    description TEXT,
    current_price NUMERIC(12,2) NOT NULL CHECK (current_price >= 0),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE suppliers (
    supplier_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    supplier_name VARCHAR(200) NOT NULL,
    email VARCHAR(255),
    phone VARCHAR(30),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Resolves the many-to-many relationship between products and suppliers.
CREATE TABLE product_suppliers (
    product_id BIGINT NOT NULL REFERENCES products(product_id) ON DELETE RESTRICT,
    supplier_id BIGINT NOT NULL REFERENCES suppliers(supplier_id) ON DELETE RESTRICT,
    supplier_sku VARCHAR(80),
    supply_cost NUMERIC(12,2) CHECK (supply_cost IS NULL OR supply_cost >= 0),
    PRIMARY KEY (product_id, supplier_id)
);

CREATE TABLE warehouses (
    warehouse_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    warehouse_name VARCHAR(150) NOT NULL UNIQUE,
    location_description VARCHAR(255),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- One row per product per warehouse.
CREATE TABLE inventory (
    product_id BIGINT NOT NULL REFERENCES products(product_id) ON DELETE RESTRICT,
    warehouse_id BIGINT NOT NULL REFERENCES warehouses(warehouse_id) ON DELETE RESTRICT,
    quantity_on_hand INTEGER NOT NULL DEFAULT 0 CHECK (quantity_on_hand >= 0),
    reorder_level INTEGER NOT NULL DEFAULT 0 CHECK (reorder_level >= 0),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (product_id, warehouse_id)
);

CREATE TABLE orders (
    order_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id BIGINT NOT NULL REFERENCES customers(customer_id) ON DELETE RESTRICT,
    order_date TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    order_status VARCHAR(30) NOT NULL DEFAULT 'pending'
        CHECK (order_status IN ('pending', 'confirmed', 'processing', 'shipped', 'delivered', 'cancelled', 'refunded')),
    shipping_address TEXT NOT NULL,
    notes TEXT
);

CREATE TABLE order_items (
    order_item_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id BIGINT NOT NULL REFERENCES orders(order_id) ON DELETE RESTRICT,
    product_id BIGINT NOT NULL REFERENCES products(product_id) ON DELETE RESTRICT,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(12,2) NOT NULL CHECK (unit_price >= 0),
    CONSTRAINT uq_order_product UNIQUE (order_id, product_id)
);

CREATE TABLE payments (
    payment_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id BIGINT NOT NULL REFERENCES orders(order_id) ON DELETE RESTRICT,
    amount NUMERIC(12,2) NOT NULL CHECK (amount >= 0),
    payment_method VARCHAR(30) NOT NULL
        CHECK (payment_method IN ('card', 'upi', 'net_banking', 'wallet', 'cash_on_delivery', 'other')),
    payment_status VARCHAR(30) NOT NULL DEFAULT 'pending'
        CHECK (payment_status IN ('pending', 'authorized', 'paid', 'failed', 'refunded', 'partially_refunded')),
    provider_reference VARCHAR(150) UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE shipments (
    shipment_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id BIGINT NOT NULL REFERENCES orders(order_id) ON DELETE RESTRICT,
    carrier_name VARCHAR(100),
    tracking_number VARCHAR(150) UNIQUE,
    shipment_status VARCHAR(30) NOT NULL DEFAULT 'pending'
        CHECK (shipment_status IN ('pending', 'packed', 'shipped', 'in_transit', 'delivered', 'returned', 'exception')),
    shipped_at TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CHECK (delivered_at IS NULL OR shipped_at IS NULL OR delivered_at >= shipped_at)
);

-- Indexes for common joins and operational filters.
-- PK/UNIQUE constraints already create indexes on their constrained columns.
CREATE INDEX idx_orders_customer_date
    ON orders(customer_id, order_date DESC);

CREATE INDEX idx_orders_status_date
    ON orders(order_status, order_date DESC);

CREATE INDEX idx_order_items_order_id
    ON order_items(order_id);

CREATE INDEX idx_order_items_product_id
    ON order_items(product_id);

CREATE INDEX idx_payments_order_id
    ON payments(order_id);

CREATE INDEX idx_shipments_order_id
    ON shipments(order_id);

CREATE INDEX idx_inventory_reorder
    ON inventory(warehouse_id, quantity_on_hand)
    WHERE quantity_on_hand <= reorder_level;

COMMIT;
