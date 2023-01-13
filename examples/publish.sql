truncate message cascade;

INSERT INTO "message" ("key", sequence_key, payload, enqueue_time) 
SELECT 
    'data-' || text(generate_series(1,10)), 
    md5(floor(random() * 10)::text),
    '{ "hello": "world" }',
    (current_date - trunc(random() * 3600) * '1 minute'::interval)
    ;

select * from message_delivery;
select * from message;
select * from queue;

delete from queue;
