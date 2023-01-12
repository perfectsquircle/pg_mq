create extension if not exists hstore;

-- drop table if exists message;
create table "message" (
    message_id bigserial primary key,
    sequence_key text,
    "key" text not null,
    payload jsonb not null,
    headers hstore not null default '',
    enqueue_time timestamptz not null default now(),
    status smallint not null default 0
);

create index on message(sequence_key);
create index on message(enqueue_time);
create index on message(status);
create index on message(status) where status = 0;

create table sequence_head (
    sequence_key text not null,
    current_message_id bigint not null
);

truncate message;
INSERT INTO "message" ("key", sequence_key, payload, enqueue_time) 
SELECT 
    'data-' || text(generate_series(1,5)), 
    md5(floor(random() * 10)::text),
    '{ "hello": "world" }',
    (current_date - trunc(random() * 3600) * '1 minute'::interval)
    ;

SELECT * FROM message;

drop table queue;
truncate queue;
create table queue (
    message_id bigint not null,
    sequence_key text not null unique
);


select * from queue;

CREATE OR REPLACE FUNCTION f_enqueue()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO queue (message_id, sequence_key)
  VALUES (NEW.message_id, NEW.sequence_key)
  ON CONFLICT DO NOTHING;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER t_enqueue_after_insert
AFTER INSERT ON "message"
   FOR EACH ROW EXECUTE PROCEDURE f_enqueue();

CREATE OR REPLACE FUNCTION f_dequeue()
RETURNS TRIGGER AS $$
DECLARE
  channel TEXT;
  payload TEXT;
BEGIN
  select channel_name into channel from channels where channel_id = 1;
  select row_to_json(m) into payload from message m where message_id = NEW.message_id;
  PERFORM pg_notify(channel, payload);
  return null;
END;
$$ LANGUAGE plpgsql;

DROP trigger t_dequeue_after_insert on queue;
CREATE TRIGGER t_dequeue_after_insert
AFTER INSERT ON "queue"
   FOR EACH ROW EXECUTE PROCEDURE f_dequeue();

select * from (
    select
        *,
        row_number() OVER (PARTITION BY sequence_key ORDER BY message_id ASC) AS row_num
    from message
    where status = 0
) ready where row_num = 1;




/*
DELETE FROM message
WHERE message_id = (
    select message_id from message_ready
    FOR UPDATE SKIP LOCKED
)
RETURNING *;
*/

create table channels (
    channel_id bigserial primary key,
    channel_name text not null
);

insert into channels(channel_name)
values 
('hello_1'),
('hello_2'),
('hello_3');

select * from channels;



select pg_notify('hello_1', 'foo');