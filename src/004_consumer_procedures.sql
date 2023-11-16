/* REGISTER */

CREATE PROCEDURE mq.open_channel(queue_name text, maximum_messages int DEFAULT 1) 
LANGUAGE plpgsql
AS $$
DECLARE 
  queue_id bigint;
  new_channel_id bigint;
  new_channel_name text;
BEGIN
  SELECT q.queue_id INTO queue_id FROM mq.queue q WHERE q.queue_name = open_channel.queue_name;
  IF queue_id IS NULL THEN
    RAISE WARNING 'No such queue';
    RETURN;
  END IF;
  new_channel_name := text(pg_backend_pid());
  SELECT channel_id FROM mq.channel c WHERE c.channel_name = new_channel_name INTO new_channel_id;
  IF new_channel_id IS NULL THEN
    INSERT INTO mq.channel(channel_name, queue_id, maximum_messages) 
      VALUES (new_channel_name, queue_id, open_channel.maximum_messages) 
      RETURNING channel_id INTO new_channel_id;
  END IF;
  EXECUTE format('LISTEN "%s"', new_channel_id);
END;
$$;

CREATE PROCEDURE mq.close_channel() 
LANGUAGE plpgsql 
AS $$
DECLARE 
  current_channel_id bigint;
  current_channel_name text;
BEGIN
  current_channel_name := text(pg_backend_pid());
  SELECT channel_id FROM mq.channel c WHERE c.channel_name = current_channel_name INTO current_channel_id;
  IF current_channel_id IS NULL THEN
    RETURN;
  END IF;
  CALL mq.close_channel(current_channel_id);
END;
$$;

CREATE PROCEDURE mq.close_channel(close_channel_id bigint) 
LANGUAGE plpgsql 
AS $$
BEGIN
  EXECUTE format('UNLISTEN "%s"', close_channel_id);
  INSERT INTO mq.message_waiting 
    (SELECT message_id, queue_id FROM mq.delivery WHERE channel_id = close_channel_id)
    ON CONFLICT DO NOTHING;
  DELETE FROM mq.channel c WHERE c.channel_id = close_channel_id;
END;
$$;

CREATE PROCEDURE mq.close_dead_channels()
LANGUAGE plpgsql
AS $$
DECLARE
  dead_channel record;
BEGIN
  FOR dead_channel IN (SELECT * FROM mq.channel c WHERE c.channel_name::int NOT IN (SELECT pid FROM pg_catalog.pg_stat_activity psa)) LOOP
    CALL mq.close_channel(dead_channel.channel_id);
  END LOOP;
END;
$$;

CREATE PROCEDURE mq.sweep_waiting_message (queue_name text) 
LANGUAGE plpgsql 
AS $$
DECLARE 
  queue_id bigint;
  current_channel record;
BEGIN
  SELECT q.queue_id INTO queue_id FROM mq.queue q WHERE q.queue_name = sweep_waiting_message.queue_name;
  IF queue_id IS NULL THEN
    RAISE WARNING 'No such queue';
    RETURN;
  END IF;
  CALL mq.sweep_waiting_message(queue_id);
END;
$$;

CREATE PROCEDURE mq.sweep_waiting_message (queue_id bigint) 
LANGUAGE plpgsql 
AS $$
DECLARE
  selected_message_id bigint;
  selected_channel record;
BEGIN
  SELECT mq.take_waiting_message(queue_id) INTO selected_message_id;
  IF selected_message_id IS NULL THEN
    RETURN;
  END IF;

  SELECT * FROM mq.take_waiting_channel(queue_id) INTO selected_channel;
  IF selected_channel IS NULL THEN
    RETURN;
  END IF;

  INSERT INTO mq.delivery(message_id, channel_id, slot, queue_id)
      VALUES (selected_message_id, selected_channel.channel_id, selected_channel.slot, queue_id);
END;
$$;

/* ACK */ 
CREATE PROCEDURE mq.ack (delivery_id bigint) 
LANGUAGE plpgsql
AS $$
DECLARE
  delivery RECORD;
BEGIN
  SELECT * INTO delivery  
    FROM mq.delivery d WHERE d.delivery_id = ack.delivery_id;
  IF delivery IS NULL THEN
    RAISE WARNING 'No such delivery';
    RETURN;
  END IF;
  DELETE FROM mq.message m WHERE m.message_id = delivery.message_id;
  INSERT INTO mq.channel_waiting(channel_id, slot, queue_id) 
    VALUES (delivery.channel_id, delivery.slot, delivery.queue_id)
    ON CONFLICT DO NOTHING;
END;
$$;


/* NACK */
CREATE PROCEDURE mq.nack(delivery_id bigint, retry_after interval DEFAULT '0s'::interval) 
LANGUAGE plpgsql
AS $$
DECLARE
  delivery RECORD;
BEGIN
  SELECT * INTO delivery  
    FROM mq.delivery d WHERE d.delivery_id = nack.delivery_id;
  IF delivery IS NULL THEN
    RAISE WARNING 'No such delivery';
    RETURN;
  END IF;
  DELETE FROM mq.delivery d WHERE d.delivery_id = nack.delivery_id;
  INSERT INTO mq.message_waiting(message_id, queue_id, not_until_time)
    VALUES (delivery.message_id, delivery.queue_id, now() + nack.retry_after)
    ON CONFLICT DO NOTHING;
  INSERT INTO mq.channel_waiting(channel_id, slot, queue_id) 
    VALUES (delivery.channel_id, delivery.slot, delivery.queue_id)
    ON CONFLICT DO NOTHING;
END;
$$;