# pg_mq

> A simple asynchronous message queue for PostgreSQL

## Features

- No polling!
  - Messages are pushed to listening consumers using [PostgreSQL NOTIFY](https://www.postgresql.org/docs/current/sql-notify.html).
- Pure PostgreSQL
  - No external vendors or plugins are needed.
- Exchanges
  - Isolate messaging concerns into distinct exchanges per installation.
- Queues
  - Declare queues that select messages based on routing patterns.
- Work queue semantics
  - Messages are delivered to a single listening consumer per queue.
- Pub/Sub semantics
  - Make queues 1-to-1 per consumer for publish/subscribe.
- Rate Limiting
  - Consumers can define how many messages they can handle simultaneously.

## Usage

### Create an exchange

Create a new exchange to publish messages to.

```sql
CALL mq.create_exchange(exchange_name=>'My Exchange');
```

### Create a queue

Queues belong to an exchange. They must define a routing pattern to receive messages. The routing pattern is a regular expression which is executed against all incoming routing keys.

```sql
CALL mq.create_queue(exchange_name=>'My Exchange', queue_name=>'My Queue', routing_key_pattern=>'^My Key$');
```

### Publish a message

Messages are comprised of a routing key, a JSON body, and headers. They can be published to an exchange.

```sql
CALL mq.publish(exchange_name=>'My Exchange', routing_key=>'My Key', body=>'{ "hello": "world" }', headers=>'foo=>bar');
```

### Consume a message

A consumer can listen to a queue. It will receive all messages in the queue if it's the sole consumer. It will receive some fraction of messages in the queue if there are multiple consumers.

```sql
CALL mq.open_channel(queue_name=>'My Queue');
```

Messages are delivered with NOTIFY in JSON format. They have a shape like so:

```json
{
  "delivery_id": 1,
  "routing_key": "My Key",
  "body": { "hello": "world" },
  "headers": { "foo": "bar" }
}
```

### Acknowledge a message

A consumer can acknowledge a message using the `delivery_id`. An acknowledged message is removed from its queue and discarded.

```sql
CALL mq.ack(delivery_id=>1);
```

A negative acknowledgement will put the message back in the queue.

```sql
CALL mq.nack(delivery_id=>1);
```

### Experimental Features

An optional delay can be added to a negative acknowledgement. The message won't be delivered again until after the interval.

```sql
CALL mq.nack(delivery_id=>1, retry_after=>'5 minutes');
```

> [!WARNING]  
> To use the above, you need a seperate process. Read below.

This has a caveat however. Since pg_mq is built off triggers, messages only flow through if there's external input (e.g. new message published, new channel opened.) If messages stop getting published for some period of time, nor do any consumers connect, a message that is held waiting for a retry will not get processed.

PostgreSQL doesn't have timers built in, nor is there a way to spawn a separate thread. So as a workaround, there needs to be an external temporal actor to periodically check if any messages are stuck waiting.

```sql
CALL mq.sweep_waiting_message(queue_name=>'My Queue');
```

This could be triggered by a cron task (e.g. [pg_cron](https://github.com/citusdata/pg_cron)) or by a timer loop in your application. See [Program.cs](examples/net6.0/Program.cs).

## Installation

1. Create a database
2. Execute `.sql` files in [src](./src/)
