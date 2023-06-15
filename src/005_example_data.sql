CALL mq.create_exchange('Default Exchange');
CALL mq.create_queue('Default Exchange', 'Default Queue', '^data-\d+$');

INSERT INTO mq.message_intake(exchange_id, routing_key, payload, publish_time) 
SELECT 
    (SELECT exchange_id FROM mq.exchange WHERE exchange_name = 'Default Exchange'),
    'data-' || text(generate_series(1,3)), 
    '{ "hello": "world" }',
    (current_date - trunc(random() * 3600) * '1 minute'::interval)
    ;