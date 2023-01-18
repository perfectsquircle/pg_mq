SET search_path TO mq,public;

DROP FUNCTION IF EXISTS mq.ack;
DROP FUNCTION IF EXISTS mq.nack;

/* ACK */ 
CREATE OR REPLACE FUNCTION mq.ack (ack_delivery_id BIGINT) 
RETURNS void AS $$
DECLARE
  selected_message_id bigint;
BEGIN
  select md.message_id into selected_message_id from mq.message_delivery md where md.delivery_id = ack_delivery_id;
  INSERT INTO mq.message_complete
    (select *, now(), true from mq.message m where m.message_id = selected_message_id);
  DELETE FROM mq.message m
    WHERE m.message_id = selected_message_id;
END;
$$ LANGUAGE plpgsql;

/* NACK */
CREATE OR REPLACE FUNCTION mq.nack (ack_delivery_id BIGINT) 
RETURNS void AS $$
DECLARE
  selected_message_id bigint;
BEGIN
  select md.message_id into selected_message_id from mq.message_delivery md where md.delivery_id = ack_delivery_id;
  INSERT INTO mq.message_complete
    (select *, now(), false from mq.message m where m.message_id = selected_message_id);
  DELETE FROM mq.message m
    WHERE m.message_id = selected_message_id;
END;
$$ LANGUAGE plpgsql;

/* NACK with future retry */