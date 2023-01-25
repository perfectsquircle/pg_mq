-- REGISTER
BEGIN;
SELECT mq.register_channel();
COMMIT;

-- ACKNOWLEDGE
BEGIN;
SELECT mq.ack(1, true);
COMMIT;

-- UNREGISTER
BEGIN;
SELECT mq.unregister_channel(1);
COMMIT;
