CREATE TABLE IF NOT EXISTS demo_users (id text PRIMARY KEY);
CREATE TABLE IF NOT EXISTS accounts (
 id text PRIMARY KEY, owner_id text REFERENCES demo_users(id), data jsonb NOT NULL
);
CREATE TABLE IF NOT EXISTS memberships (
 user_id text NOT NULL REFERENCES demo_users(id), account_id text NOT NULL REFERENCES accounts(id),
 active boolean NOT NULL, PRIMARY KEY(user_id,account_id)
);
CREATE TABLE IF NOT EXISTS trips (
 id text PRIMARY KEY, traveler_id text NOT NULL REFERENCES demo_users(id), data jsonb NOT NULL
);
CREATE TABLE IF NOT EXISTS purchase_requests (
 id text PRIMARY KEY, account_id text NOT NULL REFERENCES accounts(id), trip_id text NOT NULL REFERENCES trips(id),
 actor_id text NOT NULL REFERENCES demo_users(id), data jsonb NOT NULL
);
CREATE INDEX IF NOT EXISTS purchase_requests_account ON purchase_requests(account_id,id);
CREATE TABLE IF NOT EXISTS idempotency (
 actor_id text NOT NULL REFERENCES demo_users(id), account_id text NOT NULL REFERENCES accounts(id),
 operation text NOT NULL, key text NOT NULL, payload jsonb NOT NULL,
 request_id text NOT NULL REFERENCES purchase_requests(id),
 PRIMARY KEY(actor_id,account_id,operation,key)
);
