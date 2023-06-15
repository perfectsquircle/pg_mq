DO $$
DECLARE 
    new_exchange_id bigint;
BEGIN
    INSERT INTO mq.exchange(exchange_name) VALUES ('Default Exchange') RETURNING exchange_id INTO new_exchange_id;

    INSERT INTO mq.queue(exchange_id, queue_name, routing_key_pattern) VALUES (new_exchange_id, 'Default Queue', '^data-\d+$');

    INSERT INTO mq.message_intake(exchange_id, routing_key, payload, publish_time) 
    SELECT 
        new_exchange_id,
        'data-' || text(generate_series(1,3)), 
        '{ "hello": "world" }',
        (current_date - trunc(random() * 3600) * '1 minute'::interval)
        ;
END;
$$;