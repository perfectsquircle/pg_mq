CREATE OR REPLACE PROCEDURE mq.create_exchange(exchange_name text) 
LANGUAGE sql
AS $$
    INSERT INTO mq.exchange(exchange_name) VALUES (exchange_name);
$$;

CREATE OR REPLACE PROCEDURE mq.delete_exchange(exchange_name text) 
LANGUAGE sql
AS $$
    DELETE FROM mq.exchange
    WHERE exchange_name = delete_exchange.exchange_name;
$$;

CREATE OR REPLACE PROCEDURE mq.create_queue(exchange_name text, queue_name text, routing_key_pattern text DEFAULT '^.*$') 
LANGUAGE sql
AS $$
    INSERT INTO mq.queue(exchange_id, queue_name, routing_key_pattern)
    VALUES
    ((SELECT exchange_id FROM mq.exchange WHERE exchange_name = create_queue.exchange_name), queue_name, routing_key_pattern);
$$;

CREATE OR REPLACE PROCEDURE mq.delete_queue(queue_name text) 
LANGUAGE sql
AS $$
    DELETE FROM mq.queue
    WHERE queue_name = delete_queue.queue_name;
$$;