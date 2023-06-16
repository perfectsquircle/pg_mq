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
CALL mq.create_exchange('My Exchange');
```

### Create a queue

Queues belong to an exchange. They must define a routing pattern to receive messages. The routing pattern is a regular expression which is executed against all incoming routing keys.

```sql
CALL mq.create_queue('My Exchange', 'My Queue', '^data-\d+$');
```

### Publish a message

Messages are comprised of a routing key, a JSON payload, and headers. They can be published to an exchange.

```sql
CALL mq.publish('My Exchange', 'My Key', '{ "hello": "world" }', 'foo=>bar');
```

### Consume a message

A consumer can listen to a queue. It will receive all messages in the queue if it's the sole consumer. It will receive some fraction of messages in the queue if there are multiple consumers.

```sql
CALL mq.open_channel('My Queue');
```

Messages are delivered with NOTIFY in JSON format. They have a shape like so:

```json
{
  "delivery_id": 1,
  "routing_key": "My Key",
  "payload": { "hello": "world" },
  "headers": { "foo": "bar" }
}
```

### Acknowledge a message

A consumer can acknowledge a message using the `delivery_id`. An acknowledged message is removed from its queue and discarded.

```sql
CALL mq.ack(delivery_id);
```

## Installation

1. Create a database
2. Execute `.sql` files in [src](./src/)
