ALTER TABLE purchase_requests
  ADD COLUMN status text NOT NULL DEFAULT 'PENDING',
  ADD COLUMN updated_at timestamptz NOT NULL DEFAULT now(),
  ADD COLUMN decided_at timestamptz;

UPDATE purchase_requests
SET status = CASE
    WHEN data->>'status' IN ('ACCEPTED', 'REJECTED') THEN data->>'status'
    ELSE 'PENDING'
  END,
  data = jsonb_set(data, '{status}', to_jsonb(CASE
    WHEN data->>'status' IN ('ACCEPTED', 'REJECTED') THEN data->>'status'
    ELSE 'PENDING'
  END), true);

ALTER TABLE purchase_requests
  ADD CONSTRAINT purchase_requests_status
  CHECK (status IN ('PENDING', 'ACCEPTED', 'REJECTED'));

CREATE INDEX purchase_requests_trip_status_created
  ON purchase_requests(trip_id, status, updated_at DESC, id DESC);

CREATE TABLE purchase_request_events (
  id bigserial PRIMARY KEY,
  request_id text NOT NULL REFERENCES purchase_requests(id) ON DELETE CASCADE,
  actor_id text REFERENCES demo_users(id),
  actor_user_id uuid REFERENCES users(id),
  from_status text NOT NULL CHECK (from_status IN ('PENDING', 'ACCEPTED', 'REJECTED')),
  to_status text NOT NULL CHECK (to_status IN ('ACCEPTED', 'REJECTED')),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT purchase_request_events_one_actor
    CHECK ((actor_id IS NOT NULL) <> (actor_user_id IS NOT NULL))
);

CREATE INDEX purchase_request_events_request_created
  ON purchase_request_events(request_id, created_at, id);
