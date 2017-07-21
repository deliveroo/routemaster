## Routemaster [![Build](https://api.travis-ci.org/deliveroo/routemaster.svg?branch=master)](https://travis-ci.org/deliveroo/routemaster) [![Code Climate](https://codeclimate.com/github/deliveroo/routemaster/badges/gpa.svg)](https://codeclimate.com/github/deliveroo/routemaster) [![Test Coverage](https://codeclimate.com/github/deliveroo/routemaster/badges/coverage.svg)](https://codeclimate.com/github/deliveroo/routemaster/coverage) [![Dependency Status](https://gemnasium.com/badges/github.com/deliveroo/routemaster.svg)](https://gemnasium.com/github.com/deliveroo/routemaster)


[Intro](#the-basics)
| [Rationale](#rationale)
| [Installing](#installing--configuring)
| [Configuration](#advanced-configuration)
| [API](#api)
| [Sources of inspiration](#sources-of-inspiration)


**Routemaster** is an opinionated event bus over HTTP, supporting event-driven /
representational state notification architectures.

Routemaster aims to dispatch events with a median latency in the 50 - 100ms
range, with no practical upper limit on throughput.


Routemaster comes with, and is automatically integration-tested against
a Ruby client,
[routemaster-client](https://github.com/deliveroo/routemaster-client).

For advanced bus consumers,
[routemaster-drain](https://github.com/deliveroo/routemaster-drain) can perform
filtering of event stream and preemptive caching of resources.

## The basics

Routemaster lets publisher push events into topics, and subscribers receive
events about topics they've subscribed to.

Pushing, receiving, and subscribing all happen over HTTP.

![](https://www.dropbox.com/s/qbn1srjjcb8t0vh/Screenshot%202016-08-25%2016.41.54.png?raw=1)

Events are (by default) delivered in ordered batches, ie. a given HTTP request
to a subscriber contains several events, from all subscribed topics.

## Rationale

We built Routemaster because existing buses for distributed architectures aren't
satisfactory to us; either they're too complex to host and maintain, don't
support key features (persistence), or provide too much rope to hang ourselves
with.

### Remote procedure call as an antipattern

Routemaster is designed on purpose to _not_ support RPC-style architectures, for
instance by severely limiting payload contents.

It _only_ supports notifying consumers about lifecycle (CRUD) changes to
resources, and strongly suggests that consumers obtain their JSON out-of-band.

The rationale is that, much like it's all too easy to add non-RESTful routes to
a web application, it's all too easy to damage a resource-oriented architecture by
spreading concerns across applications, thus coupling them too tightly.


### Leverage HTTP to scale

In web environments, the one type of server that scales well and can scale
automatically with little effort is an HTTP server. As such, Routemaster heavily
relies on HTTP.

*Don't call us, we'll call you*:
Inbound events are delivered over HTTP so that the bus itself can scale to
easily process a higher (or lower) throughput of events with consistent latency.

Outbound events are delivered over HTTP so that subscribers can scale their
processing of events as easily.

We believe the cost in latency in doing so (as compared to lower-level messaging
systems such as the excellent
[RabbitMQ](https://www.rabbitmq.com/protocols.html)) is offset by easier
maintenance, more sound architecture (standards-only, JSON over HTTP), and
better scalability.

Future versions of Routemaster may support (backwards-compatible) long-polling
HTTP sessions to cancel out the latency cost.


### Persistence

The web is a harsh place. Subscribers may die, or be unreachable in many ways
for various amounts of time.

Routemaster will keep buffering, and keep trying to push events to subscribers
until they become reachable again.



### Topics and Subscriptions

*Topics* are where the inbound events are sent. There should be one topic
per domain concept, e.g. `properties`, `bookings`, `users`.

**Only one client may publish/push to a topic** (and it should be the
authoritative application for the concept).

Each topic fans out to multiple *subscriptions* which are where the outbound
events pile in.
Each pulling client (subscriber) has exactly one subscription queue which
aggregates events from multiple topics.

A subscriber can "catch up" event if it hasn't pulled events for a while
(events get buffered in subscription queues).


--------------------------------------------------------------------------------

## Installing & Configuring

In order to have routemaster receive connections from a receiver or emitter
you'll need to add their identifier to the `ROUTEMASTER_CLIENTS` environment
variable.

By default the bus will send events to `demo`, eg:

```
# Allowed UUIDs, separated by commas
ROUTEMASTER_CLIENTS=demo,my-service--6f1d6311-98a9-42ab-8da4-ed2d7d5b86c4`
```

For further configuration options please check the provided `.env` files

### Development

To get this application up and running you will need the following tools:

* redis
  * `brew install redis`
  * Just let it run with default settings
  * If you want to run it manually - `redis-server`

Routemaster only accepts HTTPS calls. To get around this restriction on
development, please install [`puma-dev`](https://github.com/puma/puma-dev).

Then proxy routemaster requests by running the following:

```
$ echo 17890 > ~/.puma-dev/routemaster
```

Now all your calls to `https://routemaster.dev` should correctly arrive at `http://127.0.0.1:17890`.

You will also need Routemaster to contact your app through HTTPS to deliver
events.  Follow the same steps above to proxy your app requests, i.e. for a
Rails app that would be

`$ echo 3000 > ~/.puma-dev/myapp`

To run the Routemaster application locally you can use the **foreman** tool:

```
foreman start
```

This will start both the web server and ancillary processes. Keep in mind that
the default web port that the **web** process will listen to is defined in the
`.env` file. By default routemaster log level is set to `DEBUG` if this is too
chatty you can easily configure this in the `.env` file



--------------------------------------------------------------------------------

## Advanced configuration

### Metrics

Routemaster can report various metrics to a third party services by setting the
`METRIC_COLLECTION_SERVICE` variable to one of:

- `print` (will log metrics to standard output; the default)
- [`datadog`](https://www.datadoghq.com) (requires the `DATADOG_API_KEY` and
  `DATADOG_APP_KEY` to be set)

The following gauge metrics will be reported every 10 seconds:

- `subscriber.queue.batches` (tagged by subscriber queue)
- `subscriber.queue.events` (tagged by subscriber)
- `jobs.count` (tagged by queue and status)
- `redis.bytes_used`, `.max_mem`, `.low_mark`, and `.high_mark` (the latter 3
  begin the autodropper thresholds)
- `redis.used_cpu_user` and `.used_cpu_sys` (cumulative CPU milliseconds used by
  the storage backend since boot)

as well as the following counter metrics:

- `events.published` (tagged by topic)
- `events.autodropped` (tagged by subscriber)
- `events.removed` (idem)
- `events.added` (idem)
- delivery metrics, tagged by status ("success" or "failure") and by subscriber:
    - `delivery.events` (one count per event)
    - `delivery.batches` (one count per batch)
    - `delivery.time` (sum of delivery times in milliseconds)
    - `delivery.time2` (sum of delivery times squared)
- `process` (tagged with `status:start` or `:stop`, and `type:web` or
  `:worker`), incremented when processes boot or shut down (cleanly)


### Exception reporting

Routemaster can send exception traces to a 3rd party by setting the
`EXCEPTION_SERVICE` variable to one of:

- `print` (will log exceptions to standard output; the default)
- [`sentry`](https://getsentry.com/welcome/)
- [`honeybadger`](https://www.honeybadger.io)
- [`new_relic`](https://newrelic.com/)

For the latter two, you will need to provide the reporting endpoint in
`EXCEPTION_SERVICE_URL`

Note that event delivery failures will *not* normally be reported to the
exception service, as they're not errors with Routemaster itself.

To check delivery failures, one can:

- monitor the `routemaster.delivery.batches` metrics with `status:failure`.
- inspect the logs for `failed to deliver`.


### Autodrop

Routemaster will, by default, permanently drop the oldest messages from queues
when the amount of free Redis memory drops below a certain threshold.
This guarantees that the bus will keep ingesting messages, and "clean up"
behind listeners that are the latest / stale-est.

Autodrop is not intended to be "business as usual": it's an exceptional
condition.  It's there to address the case of the "dead subscriber". Say you
remove a listening service from a federation but forget to unsubscribe: messages
will pile up, and without autodrop the bus will eventually crash, bringing down
the entire federation.

In a normal situation, this would be addressed earlier: an alert would be set on
queue staleness, and queue size, and depending on the situation either the
subscription would be removed or the Redis instance ramped up, for instance.

Set `ROUTEMASTER_REDIS_MAX_MEM` to the total amount of memory allocated to
Redis, in bytes
(100MB by default). This cannot typically be determined from a Redis client.

Set `ROUTEMASTER_REDIS_MIN_FREE` to the threshold, in bytes (10MB by default). If
less than this value is free, the auto-dropper will remove messages until twice
the treshold in free memory is available.

The auto-dropper runs every 30 seconds.



### Scaling Routemaster out

1. Allowing Routemaster to _receive_ more events:<br>
   This requires to scale the HTTP frontend.
   Procfile.
2. Allowing Routemaster to _deliver_ more events:<br>
   This requires running multiple instances of the _worker_ process.
   No auto-scaling mechanism is currently provided, so we recommend running the
   number of processes you'll require at peak.<br>
   Note that event delivery is bounded by the ability of subscribers to process
   them.  Poorly-written subscribers can cause timeouts in delivery, potentially
   causing buffering overflows.
3. Allowing Routemaster to _buffer_ more events:<br>
   This requires scaling the underlying Redis server.


We recommend using [HireFire](https://hirefire.io/) to auto-scale the _web_ and
_worker_ processes.

- To scale the `web` processes, monitor the `/pulse` endpoint and scale up
  if it slows down beyond 50ms.
- To scale the `worker`, we provide a special `/pulse/scaling` endpoint that
  will take 1s to respond when there are many queued jobs; we recommend to scale
  up when this endpoint it slow.
  See `.env` for configuration of thresholds.

Note that both endpoints require authentication.

--------------------------------------------------------------------------------

## API

### Authentication, security.

All requests over non-SSL connections will be met with a 308 Permanent Redirect.
HTTP Basic is required for all requests. The password will be ignored, and the
username should be a unique per client uuid.

The list of allowed clients is part of the configuration, and is passed as a
comma-separated list to the `ROUTEMASTER_CLIENTS` environment variable.


### Publication (creating topics)

There is no need to explicitely create topics; they will be when pushing the
first event to the bus.

**ONLY ONE CLIENT CAN PUSH EVENTS TO A TOPIC**: all but the first client to
push to a given topic will see their requests met with errors.


### Pushing

    >> POST /topics/:name
    >> {
    >>   type:      <string>,
    >>   url:       <string>,
    >>   timestamp: <integer>,
    >>   data:      <anything>
    >> }

`:name` is limited to 32 characters (lowercase letters and the underscore
character).

`<type>` is one of `create`, `update`, `delete`, or `noop`.

The use case `noop` is to broadcast information about all entities of a concept,
e.g. to newly created/connected subscribers. For instance, when connecting a new
application for the first time, a typical use case is to perform an "initial sync".
Given create, update, delete are only sent on changes in the lifecycle of the
entity, this extra event can be sent for all currently existing entities.

`<url>` is the authoritative URL for the entity corresponding to the event
(maximum 1024 characters, must use HTTPS scheme).

`<timestamp>` (optional) is an integer number of milliseconds since the UNIX
epoch and represents when the event occured. If unspecified it'll be set by the
bus on reception.

`<data>` (optional) is discouraged although not deprecated. It is intended when
the RESN paradigm becomes impractical to implement — e.g. small, very
frequently-changing representations that can't reasonably be fetched from the
source and inconvenient to reify as changes in the domain (typically for storage
reasons).


The response is always empty (no body). Possible statuses (besides
authentication-related):

- 204: Successfully pushed event
- 400: Bad topic name, event type, invalid URL, or extra fields in the
  payload.
- 403: Bad credentials, possibly another client is the publisher for this
  topic.


### Subscription

Subscription implicitly creates a queue for the client, which starts
accumulating events.

From the client's perspective, the subscription is a singleton resource.
A client can therefore only obtain events from their own subscription.

    >> POST /subscription
    >> {
    >>   topics:   [<name>, ...],
    >>   callback: <url>,
    >>   uuid:     <uuid>,
    >>   timeout:  <t>,
    >>   max:      <n>
    >> ]

Subscribes the client to receive events from the named topics. When events are
ready, they will be POSTed to the `<url>` (see below), at most every `<t>`
milliseconds (default 500). At most `<n>` events will be sent in each batch
(default 100).
The `<uuid>` will be used as an HTTP Basic password to the client for
authentication.

The response is always empty. No side effect if already subscribed to a given
topic.  If a previously subscribed topic is not listed, it will be unsubscribed.

Possible statuses:

- 204: Successfully subscribed to listed topics
- 400: Bad callback, unknown topics, etc.
- 404: No such topic


#### Pulling

Clients receive an HTTPS request for new batches of events, they don't have to
query for them.
If the request completes successfully, the events will be deleted from the
subscription queue.
Otherwise, they will be resent at the next interval.

    >> POST <callback>
    >>
    >> [
    >>   {
    >>     topic: <string>,
    >>     type:  <string>,
    >>     url:   <string>,
    >>     t:     <integer>,
    >>     data:  <anything>
    >>   },
    >>   ...
    >> ]

All fields values are as described when publishing events, with the following
caveats:

- On delivery, the timestamp field is always present; and named `t` instead of
  `timestamp`.
- The `data` field will be omitted if unspecified or null on publication.

Possible response statuses:

- 200, 204: Event batch is ackownledged, and will be deleted from the
  subscription queue.
- Anything else: failure, batch to be sent again later.


### Removing topics

Publishers can delete a topic they're responsible for:

    >> DELETE /topic/:name

This will cause subscribers to become unsubscribed for this topic, but will
_not_ cause events related to the topic to be removed from the queue.


### Unsubscribing

Subscribers can either unregister themselves altogether:

    >> DELETE /subscriber

or just for one topic:

    >> DELETE /subscriber/topics/:topic



### Monitoring

Routermaster provides monitoring endpoints:

    >> GET /topics
    << [
    <<   {
    <<     name:      <topic>,
    <<     publisher: <username>,
    <<     events:    <count>
    <<   }, ...
    << ]

`<count>` is the total number of events ever sent on a given topic.

    >> GET /subscriptions
    << [
    <<   {
    <<     subscriber: <username>,
    <<     callback:   <url>,
    <<     topics:     [<name>, ...],
    <<     events: {
    <<       sent:       <sent_count>,
    <<       queued:     <queue_size>,
    <<       oldest:     <staleness>,
    <<     }
    <<   }, ...
    << ]

- `<name>`: the names of all topics routed into this subscriptions queue.
- `<sent_count>`: total number of events ever sent on this topic.
- `<queue_size>`: current number of events in the subscription queue.
- `<staleness>`: timestamp (seconds since epoch) of the oldest pending event.


Monitoring resources can be queries by clients with a UUID included in `ROUTEMASTER_CLIENTS`.

Routemaster does not, and will not include a UI for monitoring, as that would
complexify its codebase too much (it's a separate concern, really).


--------------------------------------------------------------------------------

## Post-MVP Roadmap

Latency improvements:

- Option to push events to subscribers over routermaster-initiated long-polling requests
- Option to push events to subscribers over client-initiated long-polling requests

Reliability improvements:

- Ability for subscribers to specify retention period and/or max events retained.

Monitoring:

- Separate monitoring application, with a UI, consuming the monitoring API and
  pushing to Statsd.

Data payloads:

- Some use cases for transmitting (partial) representations over the event bus
  are valid (e.g. for audit trails, all intermediary representations must be
  know).

Support for sending-side autoscaling:

- The _watch_ currently is single-threaded, and running it in parallel loses the
  in-order delivery capability.
  We plan to address this with (optional) subscribed locking in the _watch_.
- Support for HireFire-based autoscaling of _watch_ processes.


--------------------------------------------------------------------------------

## Sources of inspiration

- [RestMQ](http://restmq.com/)
- [Apache Kafka](https://kafka.apache.org/documentation.html#introduction)
- [RabbitMQ](https://www.rabbitmq.com/)
- [ActiveSupport::Notification](http://api.rubyonrails.org/classes/ActiveSupport/Notifications.html)
- [Pusher](https://app.pusher.com/)

## Docker

This project contains a `Dockerfile` and a Docker image is being built on every CI run to ensure smoother transition to a Docker-based architecture. Normally that step would not require any manual input from you as a developer but you may still want to manually check if your image builds or test any changes to the `Dockerfile`. Make sure you have Docker installed on your local machine and run the following command from the root of the project:

```bash
docker build --rm=false -t routemaster .
```

If you want to get a shell on a Docker container built from this image, build the image first (see above), then run:

```bash
docker run --rm -it routemaster sh
```
