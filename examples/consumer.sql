BEGIN:

INSERT INTO mq.channel(channel_name) VALUES (MD5(text(pg_backend_pid())))
    RETURNING channel_id;
LISTEN "1";

COMMIT;

BEGIN;

SELECT mq.ack(1, true);

COMMIT;

--UNLISTEN "1";
--DELETE from channel;