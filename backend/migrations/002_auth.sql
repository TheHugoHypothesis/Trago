-- Real users are separate from demo_users. Account ownership migration is T06.
CREATE TABLE users (
 id uuid PRIMARY KEY,
 email text NOT NULL UNIQUE CHECK (email = lower(btrim(email)) AND length(email) <= 254),
 display_name text NOT NULL CHECK (length(btrim(display_name)) BETWEEN 1 AND 100),
 password_hash text NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE auth_sessions (
 id uuid PRIMARY KEY,
 user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 created_at timestamptz NOT NULL DEFAULT now(),
 expires_at timestamptz NOT NULL,
 revoked_at timestamptz,
 CHECK (expires_at > created_at)
);
CREATE INDEX auth_sessions_user ON auth_sessions(user_id);
CREATE INDEX auth_sessions_expiration ON auth_sessions(expires_at);

-- Shared by all API processes; values are keyed HMACs, not raw emails/IPs.
CREATE TABLE auth_rate_limits (
 key text PRIMARY KEY,
 window_started_at timestamptz NOT NULL DEFAULT now(),
 attempts integer NOT NULL CHECK (attempts > 0)
);
CREATE INDEX auth_rate_limits_window ON auth_rate_limits(window_started_at);
