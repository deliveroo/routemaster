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


### Worker process

FIXME

This process is built from 4 key classes:

- The `Watch` service regularly polls for subscriptions and creates
  a `Receive` service for each;
- The `Receive` service, for a given subscriptions, buffers events from a `Queue` and creates
  `Deliver` services to send the to clients;
- The `Deliver` service gracefully sends event batches over HTTP;
- The `Queue` model abstracts out queue management with Redis, providing a
  syncronous means to push and pop message from a queue.

### Cron process

This process runs scheduled tasks, regularly calling the following services:

- `Monitor` delivers metrics to metric adapters;
- `Autodrop` automatically removes the oldest messages from queues under low
  memory conditions.


## Event batch lifecycle

All events get batched for delivery for a particular subscriber; the date model
is described below.

Batches start out _early_ when they get created. An _early_ batch is also
flagged as _current_ initially — each subscriber has at most one current batch,
which is the one where newly ingested events will be added.

When a batch becomes stale or full it gets promoted to _ready_ status.

Workers pick up _ready_ batches and change their status to _pending_. Each
worker has at most one pending batch.

If delivery of a batch fails; or if a worker dies and the batch is subsequently
recovered, the batch gets demoted from _pending_ back to _early_ status (with a
deadline delay); in this case its however not flagged as _current_.

If delivery succeeds, the batch and all references are simply removed; there is
no materialisation of the terminal status.


## Data layout

All Redis keys are namespaced, under `rm:` by default.

Any mention of "UID" refers to a 20-character, Base64-encoded string
(representing a 120-bit number), intending to be globally unique.

All timestamps are represented as integers, milliseconds since the Unix epoch.


`topics`

  The set of all topic names.

`subscribers`

  The set of all subscriber tokens.

`topics:{token}`

  The set of topic names subscribed to by subscriber `{token}`.

`subscribers:{name}`

  The set of subscriber tokens having subscribed to topic `{name}`.

`topic:{name}`

  A hash containing metadata has about a topic. Keys:
  - `publisher`: the UUID of the (singly authorized) publisher
  - `counter`: the cumulative number of events received

`subscriber:{token}`

  A hash of subscription medatata. Keys:
  - `callback`: the URL to send events to.
  - `timeout`: how long to defer event delivery for batching purposes (aka deadline).
  - `max_events`: maximum number of events to batch.
  - `uuid`: the credential to use when delivering events.

`batch:{bid}` (list)

  A list whose first items are:
  - the subscriber token this batch is for,
  - the timestamp at which the batch was created,
  - the number of delivery attempts for this batch.
  followed by the serialized messages to deliver. 
  
  `bid` is the batch's UID.

`batches:early:by_subscriber:{token}` (string)

  The early batch for subscriber `{token}`, if any.
  Value is a batch UID.
  
`batches:early:by_deadline` (sorted set)

  An index for the set of early batches (the batches that or neither full nor
  stale).

  The score is the batch's deadline (in milliseconds since the epoch); set
  values are keys (pointing to actual batches).

`batches:ready:queue` (list)

  References IDs of batches that are ready for delivery, either because their
  deadline has passed or because they're full.

  The head of the list is the most recently added batch reference.

`batches:ready:by_creation` (sorted set)

  Same contents as `batches:ready:queue`, but indexed by the batch's oldest
  timestamp.

`batches:pending:{worker}` (list)

  For a given `{worker}` UID, the batch UID they're currently trying to deliver.
  The list length should always be exactly 0 or 1.

`batches:pending` (hash)

  Maps batch UIDs to worker UIDs, for batches pending delivery.

`workers` (hash)

  Maps worker identifiers (base 36 strings) to the timestamp they were last
  active at.
  Used for housekeeping (nacking pending batches for "dead" workers).

`lock:....` (string)

  Temporary locks used to manage consistency.
  (only useful if we aim for cluster support, as clustering doesn't support
  atomic ops across shards)


### Event processing pseudocode

```
Ingestion controller:
  for each subscriber:
    atomic find-or-create batch for this subscriber:
      given subscriber and event timestamp
      if there is no early batch for this subscriber:
        generate batch UID
        create batch payload key
        add to early batches
        publish batch deadline (redis pub)
    add event to batch
    if batch is full:
      if batch is still in the early set:
        add to ready set
        remove from early set

Deadline loop:
  for each batch in the early set:
    if batch is stale:
      add to ready list
      remove from early set
  repeat every tick (50ms?)

(alternate)
Deadline reactor:
  on event: (redis sub)
    set wakeup timer for batch deadline
  on timer:
    add to ready list
    remove from early set
  at boot, and at every tick (1s?): (to cope with "missed" redis pubsub events)
    for each batch in the early set:
      set wakeup timer for batch deadline

Worker loop:
  batch = block-pop from ready batches
  if batch obtained:
    move batch from ready to pending
    deliver batch
    if delivery succeeds:
      remove batch data
      remove from pending
    otherwise:
      delay deadline (with backoff)
      move batch from pending to ready

Scrub loop:
  for each pending batch:
    if worker has not been alive recently:
      move batch back to the ready queue (with delayed deadline)
  repeat every tick (1 minute?)

Autodrop loop:
  while Redis memory is low:
    find oldest batch in the ready set
    remove batch data
    remove ref from ready
  repeat every tick (1 minute?)
```


