/* REGISTER */

CREATE OR REPLACE FUNCTION mq.open_channel(the_queue_name text) 
RETURNS text AS $$
DECLARE 
  queue_id bigint;
  new_channel_id bigint;
BEGIN
  SELECT q.queue_id INTO queue_id FROM mq.queue q WHERE q.queue_name = the_queue_name;
  IF queue_id IS NULL THEN
    RAISE WARNING 'No such queue';
    RETURN NULL;
  END IF;
  -- TODO: check for already open channel
  INSERT INTO mq.channel(channel_name, queue_id) VALUES (text(pg_backend_pid()), queue_id) RETURNING channel_id INTO new_channel_id;
  EXECUTE format('LISTEN "%s"', new_channel_id);
  RETURN new_channel_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION mq.close_channel(the_channel_id bigint) 
RETURNS void AS $$
BEGIN
  EXECUTE format('UNLISTEN "%s"', the_channel_id);
  INSERT INTO mq.message_waiting (SELECT message_id, queue_id FROM mq.delivery WHERE channel_id = the_channel_id);
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
    FROM mq.delivery md WHERE md.delivery_id = the_delivery_id;
  IF delivery IS NULL THEN
    RAISE WARNING 'No such delivery';
    RETURN;
  END IF;
  DELETE FROM mq.message m WHERE m.message_id = delivery.message_id;
  INSERT INTO mq.channel_waiting(channel_id, slot, queue_id) VALUES (delivery.channel_id, delivery.slot, delivery.queue_id);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION mq.ack (the_delivery_id BIGINT) 
RETURNS void AS $$
BEGIN
  PERFORM mq.ack(the_delivery_id, true);
END;
$$ LANGUAGE plpgsql;


/* TODO: NACK with future retry */