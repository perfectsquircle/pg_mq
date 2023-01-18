# pg_mq

> A simple asynchronous message queue for PostgreSQL


## Features

* No polling!
  * Messages are pushed to listening consumers
* Ordered delivery
  * Messages can be delivered in order for a pre-determined "sequence key"
  

## Installation

1. Create a database
2. Execute [001_schema.sql](./src/001_schema.sql)
3. Execute [002_consumer_functions.sql](./src/001_schema.sql)
4. Create a listener. See [consumer.sql](./examples/consumer.sql) and [consumer.py](./examples/consumer.py) for examples.
5. ...


## Usage

### Publish a message

### Consume a message

### Acknowledge a message