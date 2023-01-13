INSERT INTO channel(channel_name) VALUES (MD5(text(pg_backend_pid())))
    RETURNING channel_name;
LISTEN channel_name;

DELETE from channel;

select * from channel;

select * from message_delivery;