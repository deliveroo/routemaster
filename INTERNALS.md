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


