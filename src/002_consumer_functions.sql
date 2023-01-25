/* REGISTER */

CREATE OR REPLACE FUNCTION mq.register_channel() 
RETURNS text AS $$
DECLARE 
  new_channel_id bigint;
BEGIN
  INSERT INTO mq.channel(channel_name) VALUES (text(pg_backend_pid())) RETURNING channel_id INTO new_channel_id;
  EXECUTE format('LISTEN "%s"', new_channel_id);
  RETURN new_channel_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION mq.unregister_channel(the_channel_id bigint) 
RETURNS void AS $$
BEGIN
  EXECUTE format('UNLISTEN "%s"', the_channel_id);
  INSERT INTO mq.message_waiting (SELECT message_id FROM mq.message_delivered WHERE channel_id = the_channel_id);
  DELETE FROM mq.channel WHERE channel_id = the_channel_id;
  RETURN;
END;
$$ LANGUAGE plpgsql;


/* ACK */ 
CREATE OR REPLACE FUNCTION mq.ack (the_delivery_id BIGINT, success BOOLEAN) 
RETURNS void AS $$
DECLARE
  delivery RECORD;
BEGIN
  SELECT * INTO delivery  
    FROM mq.message_delivered md WHERE md.delivery_id = the_delivery_id;
  IF delivery IS NULL THEN
    RAISE WARNING 'No such delivery';
    RETURN;
  END IF;
  WITH dm AS (DELETE FROM mq.message m WHERE m.message_id = delivery.message_id RETURNING *)
    INSERT INTO mq.message_complete (select dm.*, now(), success FROM dm);
  INSERT INTO mq.channel_waiting(channel_id) VALUES (delivery.channel_id);
END;
$$ LANGUAGE plpgsql;

/* TODO: NACK with future retry */