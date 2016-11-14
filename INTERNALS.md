## Routemaster internals

Routemaster runs as 3 processes (see `Procfile`):

- `web`, which serves the HTTP API. In particular, it receives events and stores
  them in Redis.

- `watch`, which listens to Redis for events and eventually dispatches them
  to subscribers over HTTP.

- `monitor`, which runs scheduled tasks.

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
- The `Receive` service, for a given subscriptions, buffers events from a `Queue` and creates
  `Deliver` services to send the to clients;
- The `Deliver` service gracefully sends event batches over HTTP;
- The `Queue` model abstracts out queue management with Redis, providing a
  syncronous means to push and pop message from a queue.

# Cron process

This process runs scheduled tasks, regularly calling the following services:

- `Monitor` delivers metrics to metric adapters;
- `Autodrop` automatically removes the oldest messages from queues under low
  memory conditions.



### Data layout

All Redis keys are namespaced, under `rm:` by default.

`topics`

  The set of all topic names.

`subscribers`

  The set of all subscriber client tokens.

`topics:{client_token}`

  The set of topic names subscribed to by subscriber `client_token`.

`subscribers:{topic}`

  The set of subscriber client tokens having subscribed to topic `name`.

`topic:{name}`

  A hash containing metadata has about a topic. Keys:
  - `publisher`: the client token of the (singly authorized) publisher
  - `counter`: the cumulative number of events received

`subscriber:{client_token}`

  A hash of subscription medatata. Keys:
  - `callback`: the URL to send events to.
  - `timeout`: how long to defer event delivery for batching purposes.
  - `max_events`: maximum number of events to batch.
  - `callback_token`: the credential to use when delivering events.

`queue:new:{client_token}`

  A list of UIDs of messages to be delivered, in reception order, by subscriber
  client token.

`queue:pending:{client_token}`

  A zset of UIDs of messages for which delivery is in progress, keyed by the
  timestamp of the attempt.
  This gets cleared when messages are acked or nacked.

`queue:data:{client_token}`

  A hash of messages keyed by their UID. Includes new and unacked messages.

Message UIDs are unique _per queue_, not globally.

