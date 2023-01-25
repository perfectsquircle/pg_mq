/* PUBLISH */ 
CREATE OR REPLACE FUNCTION mq.publish (routing_key text, payload jsonb) 
RETURNS bigint AS $$
  INSERT INTO mq.message (routing_key, payload)
    VALUES (routing_key, payload)
    RETURNING message_id;
$$ LANGUAGE sql;


CREATE OR REPLACE FUNCTION mq.publish (routing_key text, payload jsonb, headers hstore) 
RETURNS bigint AS $$
  INSERT INTO mq.message (routing_key, payload, headers)
    VALUES (routing_key, payload, headers)
    RETURNING message_id;
$$ LANGUAGE sql;
