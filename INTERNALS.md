## Routemaster internals

Routemaster runs as 3 processes (see `Procfile`):

- `web`, which serves the HTTP API. In particular, it ingests events, stores
  them in batches per subscriber (in Redis), and schedules delivery jobs.

- `worker`, which runs asynchronous jobs - both event batch delivery to
  subscribers, and scheduled jobs like delivery of monitoring telemetry.

### Web process

Restricts clients with the `Authentication` middleware (HTTP Digest).

Serves endpoints through 3 controllers:

- `Pulse`, to check service status;
- `Subscription`, to create subscriptions;
- `Topic`, to post events.

Controllers use a variety of service classes models to perform, in a traditional
MVC approach.


### Worker process

This process (of which multiple instances can be run) executes a number of
threads concurrently.

- A group of `ROUTEMASTER_WORKER_THREADS` threads runs the `main` job queue
  which delivers batches.
- A single thread executes non-delivery jobs from the `aux` queue
- A number of ticker threads schedule auxilliary jobs.

Jobs include:

- `Batch` delivers a batch of events to a subscriber over HTTP.
- `Monitor` delivers telemetry to metric adapters.
- `Autodrop` automatically deletes the oldest batches under low memory
  conditions.
- `Schedule` promotes scheduled (deferred) jobs to the main job queue.


## Event batch lifecycle

All events get batched for delivery for a particular subscriber; the data model
is described below.

Batches start out _current_ when they get created. Each subscriber normally has
at most one _current_ batch which receives new events, although in edge cases
(high concurrency) more than one current batch might get created.

When the batch is either full or stale, it gets promoted to _ready_ - another
_current_ batch may then be created while the first awaits delivery.

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
  - `publisher`: the UUID of the authorized publisher (only one publisher can
    emit events for a given topic)
  - `counter`: the cumulative number of events received

`subscriber:{token}`

  A hash of subscription medatata. Keys:
  - `callback`: the URL to send events to.
  - `timeout`: how long to defer event delivery for batching purposes (aka deadline).
  - `max_events`: maximum number of events to batch.
  - `uuid`: the credential to use when delivering events.
  - `health_points`: Increases by one on each successful delivery and decreases by two on each failure. Defatuls to 100, which is perfect subscriber health.
  - `last_attempted_at`: timestamp of the latest attempted delivery (HTTP request to the subscriber), successful or not.

`batch:{bid}` (list)

  A list whose first items are:
  - the subscriber token this batch is for,
  - the timestamp at which the batch was created,
  - the number of delivery attempts for this batch,
  followed by the serialized messages to deliver. 
  
  `bid` is the batch's UID.

`batches:current:{token}` (set)

  The current batch(es) for subscriber `{token}`, if any.
  Values are batch UIDs.

  This should normally have at most 1 element, although under high
  concurrency situations multiple batches may be created simultaneously.
  
`batches:index` (sorted set)

  An index for the set of all batches.
  The score is the batch's creation timestamp; values are batch UIDs.

`batches:gauges:event` (hash)

  Number of currently extant events, per subscriber name.

`batches:gauges:batch` (hash)

  Number of currently extant batches, per subscriber name.

`jobs:index:{q}` (set)

  All jobs currently in the queue named `{q}`, in any state. Jobs are
  represented as a MessagePack-encoded array of 2 elements, the job name and its
  array of arguments.

`jobs:scheduled:{q}` (sorted set)

  Jobs scheduled for later execution on the queue named `{q}`, scored by their
  deadline timestamp.  Jobs are represented as above.

`jobs:instant:{q}` (list)

  Jobs in the "instant" state, for immediate execution.

`jobs:pending:{q}:{worker}` (list)

  A list of at most 1 element, containing the job currently being processed by
  worker `{worker}`.
  NB: this is represented as a list so that atomic operations can be used (eg.
  `BRPOPLPUSH`) and no jobs ever get lost.

`jobs:pending:index:{q}` (set)

  A set of worker identifiers, acting as an index for the previous key. Values
  are exactly the set of possible `{worker}` values above.
  Added to whenever popping from the queue, removed from only when scrubbing the
  queue.

`workers` (hash)

  Maps worker identifiers to the timestamp they were last
  active at.  Used for housekeeping (nacking pending batches for "dead"
  workers).

  Job identifiers are formatted as batch UIDs.

`counters` (hash)

  Telemetry counters.


