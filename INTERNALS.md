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

This process (of which multiuple instances can be run) executes a number of
threads concurrently.

- A group a `ROUTEMASTER_WORKER_THREADS` threads runs the `main` job queue
  which delivers batches.
- A single thread executes non-delivery jobs from the `aux` queue (monitoring,
  auto-dropping, promotion of scheduled jobs)
- A number of ticker threads schedule auxilliary jobs.

Details on the services above:

- `Monitor` delivers gauge metrics to metric adapters;
- `Autodrop` automatically removes the oldest messages from queues under low
  memory conditions.


## Internal events

We use the `wisper` gem as a process-local event bus. Conventionally, our event
have a single hash as a payload. This is a catalog of such events.

`events_added(name:, count:)`

`events_removed(name:, count:)`


## Event batch lifecycle

All events get batched for delivery for a particular subscriber; the data model
is described below.

Batches start out _current_ when they get created. Each subscriber has at most
one _current_ batch which receives new events.

When the batch is either full or stale, it gets promoted to _ready_ - another
_current_ batch may then be created which the first awaits delivery.

Finally, batches get deleted once they have been delivered; or when the
auto-dropper removes them (because the system is running out of storage space).

               promote         deliver           
    +-----------+   +-----------+   +-----------+
    |           |   |           |   |           |
    |  Current  |-->|   Ready   |-->|  Deleted  |
    |           |   |           |   |           |
    +-----------+   +-----------+   +-----------+
         |                                ^
         |                     deliver    |     
         `--------------------------------´


## Job lifecycle

Jobs (in particular, delivery jobs) can be created as _scheduled_ ("run after a
specified time in the future") or _instant_ ("run as soon as possible").

Workers pick up _instant_ jobs and change their status to _pending_. Each
worker has at most one pending job.

If a worker dies and the job subsequently recovered ("scrubbed"), the job gets
demoted from _pending_ back to _instant_ status.

The job executor can also ask for a job to be retried in the future (by raising
a specific exception); in this case the job is demoted back to _scheduled_
status.

If a job succeeds, the job and all references are simply removed; there is
no materialisation of the terminal status.

               promote         acquire           ack
    +-----------+   +-----------+   +-----------+   +-----------+
    |           |   |           |   |           |   |           |
    | Scheduled |-->|   Ready   |-->|  Pending  |-->|  Deleted  |
    |           |   |           |   |           |   |           |
    +-----------+   +-----------+   +-----------+   +-----------+
         ^                                |
         |                                | nack
         \--------------------------------/


Note that we enforce job uniqueness: only one instance of a job may be enqueued
at any point, irrespective of state. The control layer make it a no-op to
enqueue a duplicate job when a copy is already scheduled, ready, or pending.


## Data layout

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

`batches:current:{token}` (string)

  The current batch for subscriber `{token}`, if any.
  Value is a batch UID.
  
`batches:index` (sorted set)

  An index for the set of all batches.
  The score is the batch's creation timestamp; values are batch UIDs.

`batches:counters:event` (hash)

  Number of currently extant events, per subscriber name.

`batches:counters:batch` (hash)

  Number of currently extant batches, per subscriber name.

`jobs:index:{q}` (set)

  All jobs currently in the queue named `{q}`, in any state. Jobs are
  represented as a MessagePack-encoded array of 2 elements, the job name and its
  array of arguments.

`jobs:scheduled:{q}` (sorted set)

  Jobs scheduled for later execution, scored by their deadline timestamp.
  Jobs a represented as above.

`jobs:queue:{q}` (list)

  Jobs in the "instant" state, for immediate execution.

`jobs:pending:{q}:{worker}` (list)

  A list of at most 1 element, containing the job currently being processed by
  worker `{worker}`.

`workers` (hash)

  Maps worker identifiers to the timestamp they were last
  active at.  Used for housekeeping (nacking pending batches for "dead"
  workers).

  Job identifiers are formatted as batch UIDs.

