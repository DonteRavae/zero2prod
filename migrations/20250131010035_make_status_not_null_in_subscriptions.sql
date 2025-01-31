-- Add migration script here
BEGIN;

UPDATE subscriptions
SET
    status = 'pending_confirmation'
WHERE
    status IS NULL;

ALTER TABLE subscriptions
ALTER COLUMN status
SET
    NOT NULL;

COMMIT;