/* PUBLISH */ 
CREATE PROCEDURE mq.publish (exchange_name text, routing_key text, payload json, headers hstore) 
LANGUAGE plpgsql 
AS $$
DECLARE 
  exchange_id bigint;
BEGIN
  SELECT e.exchange_id INTO exchange_id FROM mq.exchange e WHERE e.exchange_name = publish.exchange_name;
  IF exchange_id IS NULL THEN
    RAISE WARNING 'No such exchange.';
    RETURN;
  END IF;
  INSERT INTO mq.message_intake (exchange_id, routing_key, payload)
    VALUES (exchange_id, routing_key, payload);
END;
$$;
