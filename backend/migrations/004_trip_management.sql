ALTER TABLE trips
  ADD COLUMN status text NOT NULL DEFAULT 'AVAILABLE'
    CHECK (status IN ('AVAILABLE', 'CANCELLED')),
  ADD COLUMN created_at timestamptz NOT NULL DEFAULT now(),
  ADD COLUMN updated_at timestamptz NOT NULL DEFAULT now();

CREATE INDEX trips_available_departure
  ON trips(status, ((data->>'departureDate')), id);
CREATE INDEX trips_real_owner_created
  ON trips(traveler_user_id, created_at DESC, id DESC)
  WHERE traveler_user_id IS NOT NULL;

-- Actor IDs come only from a validated real or explicit demo session. Keeping the
-- scoped key as text supports both identity stores without weakening trip ownership.
CREATE TABLE trip_idempotency (
  actor_id text NOT NULL,
  operation text NOT NULL,
  key text NOT NULL,
  payload jsonb NOT NULL,
  trip_id text NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
  PRIMARY KEY(actor_id, operation, key)
);
