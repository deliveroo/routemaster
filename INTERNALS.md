## Routemaster internals

Routemaster runs as 2 processes (see `Procfile`):

- `web`, which serves the HTTP API. In particular, it receives events and stores
  them in RabbitMQ.

- `watch`, which listens to RabbitMQ for events and eventually dispatches them
  to subscribers over HTTP.

### Web process

Restricts clients with the `Authentication` middleware (HTTP Digest).

Serves endpoints through 3 controllers:

- `Pulse`, to check service status;
- `Subscription`, to create subscriptions;
- `Topic`, to post events.

Controllers use a variety of models to perform, in a traditional MVC approach.


### Watch process

This process is built from 4 key classes:

- The `Watch` service regularly polls for subscriptions and creates
  a `Receive` service for each;
- The `Receive` service, for a given subscriptions, buffers events from a `Consumer` and creates
  `Deliver` services to send the to clients;
- The `Deliver` service gracefully sends event batches over HTTP;
- The `Consumer` model abstracts out RabbitMQ internals and provides a
  asynchronous manner to receive `Event` instances.


### Data layout

Redis keys:

`topics`

  The set of topic names.

`subscription`

  The set of subscriber UUIDs.

`topic/{name}`

  A hash containing metadata has about a topic. Keys:
  - `publisher`: the UUID of the (singly authorized) publisher
  - `last_event`: a dump of the last event sent
  - `counter`: the cumulative number of events received

`subscribers/{topic}`

  A set of subscriber UUIDs for a particular topic.

`queue/new/{subscriber}`

  A list of UIDs of messages to be delivered, in reception order.

`queue/pending/{subscriber}`

  A zset of UIDs of messages for which delivery is in progress, keyed by the
  timestamp of the attempt.
  This gets cleared when messages are acked or nacked.

`queue/data/{subscriber}`

  A hash of messages keyed by their UID. Includes new and unacked messages.

Message UIDs are unique _per queue_, not globally.

