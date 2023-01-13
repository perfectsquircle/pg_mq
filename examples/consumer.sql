INSERT INTO channel(channel_name) VALUES (MD5(text(pg_backend_pid())))
    RETURNING channel_name;
LISTEN "5ca429b0056550eab08bcfe770eaf98e";


--UNLISTEN "5ca429b0056550eab08bcfe770eaf98e";
--DELETE from channel;