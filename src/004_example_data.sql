INSERT INTO mq.message (routing_key, payload, publish_time) 
SELECT 
    'data-' || text(generate_series(1,10)), 
    '{ "hello": "world" }',
    (current_date - trunc(random() * 3600) * '1 minute'::interval)
    ;
