/* REGISTER */

CREATE OR REPLACE FUNCTION mq.register_channel () 
RETURNS text AS $$
  INSERT INTO mq.channel(channel_name) VALUES (text(pg_backend_pid())) RETURNING channel_name;
$$ LANGUAGE sql;


/* ACK */ 
CREATE OR REPLACE FUNCTION mq.ack (the_delivery_id BIGINT, success BOOLEAN) 
RETURNS void AS $$
DECLARE
  delivery RECORD;
BEGIN
  SELECT * INTO delivery  
    FROM mq.message_delivered md WHERE md.delivery_id = the_delivery_id;
  IF delivery IS NULL THEN
    RETURN;
  END IF;
  INSERT INTO mq.message_complete
    (select *, now(), success from mq.message m where m.message_id = delivery.message_id);
  DELETE FROM mq.message m WHERE m.message_id = delivery.message_id;
  INSERT INTO mq.channel_waiting(channel_id) VALUES (delivery.channel_id);
END;
$$ LANGUAGE plpgsql;

/* TODO: NACK with future retry */