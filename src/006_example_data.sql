CALL mq.create_exchange(exchange_name=>'Default Exchange');

CALL mq.create_queue(exchange_name=>'Default Exchange', queue_name=>'Default Queue', routing_key_pattern=>'^data-\d+$');

INSERT INTO mq.message_intake(exchange_id, routing_key, payload, headers, publish_time) 
SELECT 
    (SELECT exchange_id FROM mq.exchange WHERE exchange_name = 'Default Exchange'),
    'data-' || text(generate_series(1,1000)), 
    '{ "hello": "world" }',
    'foo=>bar',
    (current_date - trunc(random() * 3600) * '1 minute'::interval)
    ;