ALTER TABLE trips
  ADD COLUMN total_capacity_grams integer,
  ADD COLUMN reserved_capacity_grams integer NOT NULL DEFAULT 0;

UPDATE trips
SET total_capacity_grams = (data->>'availableWeightGrams')::integer;

UPDATE trips t
SET reserved_capacity_grams = accepted.reserved
FROM (
  SELECT trip_id,
    sum((data#>>'{product,estimatedWeightGrams}')::integer)::integer AS reserved
  FROM purchase_requests
  WHERE status = 'ACCEPTED'
  GROUP BY trip_id
) accepted
WHERE accepted.trip_id = t.id;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM trips
    WHERE total_capacity_grams IS NULL
      OR total_capacity_grams < 1
      OR total_capacity_grams > 100000
      OR reserved_capacity_grams < 0
      OR reserved_capacity_grams > total_capacity_grams
  ) THEN
    RAISE EXCEPTION 'Existing accepted requests exceed or invalidate declared trip capacity';
  END IF;
END $$;

ALTER TABLE trips
  ALTER COLUMN total_capacity_grams SET NOT NULL,
  ADD CONSTRAINT trips_total_capacity_range
    CHECK (total_capacity_grams BETWEEN 1 AND 100000),
  ADD CONSTRAINT trips_reserved_capacity_range
    CHECK (reserved_capacity_grams BETWEEN 0 AND total_capacity_grams);

CREATE INDEX trips_remaining_capacity
  ON trips(status, (total_capacity_grams - reserved_capacity_grams), id);
