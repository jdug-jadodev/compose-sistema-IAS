CREATE TABLE customers (
    customer_id TEXT PRIMARY KEY,
    status TEXT NOT NULL,
    approval_limit NUMERIC NOT NULL,

    CONSTRAINT chk_customers_id_not_blank
        CHECK (btrim(customer_id) <> ''),

    CONSTRAINT chk_customers_status
        CHECK (status IN ('ELIGIBLE', 'BLOCKED')),

    CONSTRAINT chk_customers_approval_limit
        CHECK (
            approval_limit >= 0
            AND approval_limit NOT IN (
                'NaN'::NUMERIC,
                'Infinity'::NUMERIC,
                '-Infinity'::NUMERIC
            )
        )
);


CREATE TABLE credit_applications (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    application_reference TEXT NOT NULL,

    requested_customer_id TEXT NOT NULL,

    customer_id TEXT NULL,

    amount NUMERIC NOT NULL,

    term_months INTEGER NOT NULL,

    status TEXT NOT NULL,

    reason_code TEXT NULL,

    reason TEXT NULL,

    processed_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),

    CONSTRAINT uq_credit_applications_reference
        UNIQUE (application_reference),

    CONSTRAINT fk_credit_applications_customer
        FOREIGN KEY (customer_id)
        REFERENCES customers(customer_id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT chk_credit_applications_reference_not_blank
        CHECK (btrim(application_reference) <> ''),

    CONSTRAINT chk_credit_applications_requested_customer_not_blank
        CHECK (btrim(requested_customer_id) <> ''),

    CONSTRAINT chk_credit_applications_amount_finite
        CHECK (
            amount NOT IN (
                'NaN'::NUMERIC,
                'Infinity'::NUMERIC,
                '-Infinity'::NUMERIC
            )
        ),

    CONSTRAINT chk_credit_applications_status
        CHECK (status IN ('APPROVED', 'REJECTED')),

    CONSTRAINT chk_credit_applications_customer_match
        CHECK (
            customer_id IS NULL
            OR customer_id = requested_customer_id
        ),

    CONSTRAINT chk_credit_applications_approved
        CHECK (
            status <> 'APPROVED'
            OR (
                customer_id IS NOT NULL
                AND amount > 0
                AND term_months BETWEEN 6 AND 60
                AND reason_code IS NULL
                AND reason IS NULL
            )
        ),

    CONSTRAINT chk_credit_applications_rejected
        CHECK (
            status <> 'REJECTED'
            OR (
                reason_code IS NOT NULL
                AND btrim(reason_code) <> ''
                AND reason IS NOT NULL
                AND btrim(reason) <> ''
            )
        ),

    CONSTRAINT chk_credit_applications_reason_code
        CHECK (
            reason_code IS NULL
            OR reason_code IN (
                'INVALID_AMOUNT',
                'INVALID_TERM',
                'CUSTOMER_BLOCKED',
                'INSUFFICIENT_LIMIT',
                'CUSTOMER_NOT_FOUND'
            )
        ),

    CONSTRAINT chk_credit_applications_customer_not_found
        CHECK (
            reason_code IS DISTINCT FROM 'CUSTOMER_NOT_FOUND'
            OR customer_id IS NULL
        )
);


CREATE INDEX idx_credit_applications_customer_status
    ON credit_applications (customer_id, status);


CREATE INDEX idx_credit_applications_processed_at
    ON credit_applications (processed_at DESC, id DESC);