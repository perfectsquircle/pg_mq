SET search_path TO mq,public;

-- DROP FUNCTION IF EXISTS mq.publish;

/* PUBLISH */ 
CREATE OR REPLACE FUNCTION mq.publish ("key" text, payload jsonb) 
RETURNS void AS $$
BEGIN
  INSERT INTO mq.message ("key", payload)
  VALUES (key, payload);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION mq.publish ("key" text, payload jsonb, sequence_key text) 
RETURNS void AS $$
BEGIN
  INSERT INTO mq.message ("key", payload, sequence_key)
  VALUES (key, payload, sequence_key)
  ON CONFLICT DO NOTHING;
END;

$$ LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION mq.publish ("key" text, payload jsonb, sequence_key text, headers hstore) 
RETURNS void AS $$
BEGIN
  INSERT INTO mq.message ("key", payload, sequence_key, headers)
  VALUES (key, payload, sequence_key, headers);
END;
$$ LANGUAGE plpgsql;
