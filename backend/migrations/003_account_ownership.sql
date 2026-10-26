-- Keep legacy demo ownership while adding referentially constrained real users.
ALTER TABLE accounts ADD COLUMN owner_user_id uuid REFERENCES users(id) ON DELETE CASCADE;
ALTER TABLE accounts ADD CONSTRAINT accounts_single_owner
  CHECK (owner_id IS NULL OR owner_user_id IS NULL);
CREATE INDEX accounts_owner_user ON accounts(owner_user_id);
CREATE UNIQUE INDEX accounts_personal_owner_user
  ON accounts(owner_user_id) WHERE data->>'type' = 'PERSONAL';

CREATE TABLE account_memberships (
  account_id text NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role text NOT NULL CHECK (role IN ('MEMBER')),
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY(account_id, user_id)
);
CREATE INDEX account_memberships_user ON account_memberships(user_id, account_id) WHERE active;

-- Existing users from T04 also receive exactly one personal account.
INSERT INTO accounts(id, owner_user_id, data)
SELECT 'personal-' || u.id::text, u.id,
  jsonb_build_object('id', 'personal-' || u.id::text, 'type', 'PERSONAL',
    'displayName', 'Conta pessoal de ' || u.display_name)
FROM users u
WHERE NOT EXISTS (
  SELECT 1 FROM accounts a
  WHERE a.owner_user_id = u.id AND a.data->>'type' = 'PERSONAL'
);

ALTER TABLE trips ADD COLUMN traveler_user_id uuid REFERENCES users(id);
ALTER TABLE trips ALTER COLUMN traveler_id DROP NOT NULL;
ALTER TABLE trips ADD CONSTRAINT trips_exactly_one_traveler
  CHECK ((traveler_id IS NOT NULL) <> (traveler_user_id IS NOT NULL));
CREATE INDEX trips_traveler_user ON trips(traveler_user_id, id);

ALTER TABLE purchase_requests ADD COLUMN actor_user_id uuid REFERENCES users(id);
ALTER TABLE purchase_requests ALTER COLUMN actor_id DROP NOT NULL;
ALTER TABLE purchase_requests ADD CONSTRAINT purchase_requests_exactly_one_actor
  CHECK ((actor_id IS NOT NULL) <> (actor_user_id IS NOT NULL));

CREATE TABLE user_idempotency (
  actor_user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  account_id text NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  operation text NOT NULL,
  key text NOT NULL,
  payload jsonb NOT NULL,
  request_id text NOT NULL REFERENCES purchase_requests(id) ON DELETE CASCADE,
  PRIMARY KEY(actor_user_id, account_id, operation, key)
);
