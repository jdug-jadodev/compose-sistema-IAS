#!/bin/bash

set -e

psql \
  -v ON_ERROR_STOP=1 \
  --username "$POSTGRES_USER" \
  --dbname "$POSTGRES_DB" \
  --set=app_user="$APP_DB_USER" \
  --set=app_password="$APP_DB_PASSWORD" <<'EOSQL'

SELECT format(
    'CREATE ROLE %I LOGIN PASSWORD %L',
    :'app_user',
    :'app_password'
)
WHERE NOT EXISTS (
    SELECT 1
    FROM pg_roles
    WHERE rolname = :'app_user'
)
\gexec


SELECT format(
    'GRANT CONNECT ON DATABASE %I TO %I',
    current_database(),
    :'app_user'
)
\gexec


SELECT format(
    'GRANT USAGE ON SCHEMA public TO %I',
    :'app_user'
)
\gexec


SELECT format(
    'GRANT SELECT ON TABLE customers TO %I',
    :'app_user'
)
\gexec


-- Necesario para poder ejecutar SELECT ... FOR UPDATE
SELECT format(
    'GRANT UPDATE (status) ON TABLE customers TO %I',
    :'app_user'
)
\gexec


SELECT format(
    'GRANT SELECT, INSERT ON TABLE credit_applications TO %I',
    :'app_user'
)
\gexec


SELECT format(
    'GRANT USAGE, SELECT ON SEQUENCE credit_applications_id_seq TO %I',
    :'app_user'
)
\gexec

EOSQL