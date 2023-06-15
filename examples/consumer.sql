-- OPEN
SELECT mq.open_channel('Default Queue');

-- ACKNOWLEDGE
SELECT mq.ack(1, true);

-- CLOSE
SELECT mq.close_channel(1);