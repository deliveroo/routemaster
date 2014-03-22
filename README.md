## Routemaster

**Routemaster** is an opinionated event bus over HTTP, supporting event-driven /
representational state notification architectures.

Routemaster aims to dispatch events with a median latency in the 50-100ms range,
with no practical upper limit on throughput.


#### Remote procedure call as an antipattern

Routemaster is designed on purpose to _not_ support RPC-style architectures, for
instance by severely limiting payload contents.

The rationale is that, much like it's all too easy to add non-RESTful routes to
a web application, it's all too easy to damage a microservice architecture by
building function across services, thus coupling them too tightly.


#### Don't call us, we'll call you

In web environments, the one type of server that scales well and can scale
automatically with little effort is an HTTP server. As such, Routemaster heavily
relies on HTTP.

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


#### Persistence

The web is a harsh place. Subscribers may die, or be unreachable in many ways
for various amounts of time.

Routemaster will keep buffering, and keep trying to push events to subscribers
until they become reachable again.


--------------------------------------------------------------------------------

### Channels and queues

*Channels* are where the inbound events are sent. There should be one channel
per domain concept, e.g. `properties`, `bookings`, `users`.

Only one client may publish/push to a channel (and it should be the
authoritative service for the concept).

Each channel fans out to multiple *queues* which are where the outbound events
pile in.
Each pulling client (subscriber) has exactly one queue which aggregates events
from multiple channels.

A subscriber can "catch up" event if it hasn't pulled events for a while
(events get buffered in queues).


--------------------------------------------------------------------------------

### Installing & Configuring


Environment variables:

- `ROUTEMASTER_CLIENTS`
- `ROUTEMASTER_MONITORS`


--------------------------------------------------------------------------------

### API

#### Authentication, security.

All requests over non-SSL connections will be met with a 308 Permanent Redirect.

HTTP Basic is required for all requests. The username is stored as a
humab-readable name (but not checked); the password should be a per-client UUID.

The list of allowed clients is part of the configuration, and is passed as a
comma-separated list to the `ROUTEMASTER_CLIENTS` environment variable.


#### Publication (creating channels)

There is no need co explicitely create channels; they will be when pushing the
first event to the bus.

**Only one client** can push events to a channel: all but the first client to
push to a given channel will see their requests met with errors.


#### Pushing 

    >> POST /channels/:name
    >> {
    >>   event: <type>,
    >>   url: <url>
    >> }

`:name` is limited to 32 characters (lowercase letters and the underscore
character).

`<type>` is one of `created`, `updated`, or `deleted`.

`<url>` is the authoritative URL for the entity corresponding to the event
(maximum 1024 characters).

The response is always empty (no body). Possible statuses (besides
authentication-related):

- 204: Successfully pushed event
- 400: Bad channel name, event type, invalid URL, or extra fields in the
  payload.
- 403: Bad credentials, possibly another client is the publisher for this
  channel.


#### Subscription

Subscription implicitly creates a queue for the client, which starts
accumulating events.

From the client's perspective, the queue is a singleton resource.
A client can therefore only pull from their own queue.

    >> POST /queue
    >> {
    >>   channels: [<name>, ...],
    >>   callback: <url>,
    >>   uuid:     <uuid>,
    >>   timeout:  <t>,
    >>   max:      <n>
    >> ]

Subscribes the client to receive events from the named channels. When events are
ready, they will be POSTed to the `<url>` (see below), at most every `<t>`
milliseconds (default 500). At most `<n>` events will be sent in each batch
(default 100).
The `<uuid>` will be used as an HTTP Basic password to the client for
authentication.

The response is always empty. No side effect if already subscribed.
Possible statuses:

- 204: Successfully subscribed to listed channels
- 400: Bad callback, unknown channels, etc.
- 404: No such channel


#### Pulling

Clients receive an HTTPS request for new batches of events, they don't have to
query for them.
If the request completes successfully, the events will be deleted from the
queue.
Otherwise, they will be resent at the next interval.

    >> POST <callback>
    >>
    >> [
    >>   { 
    >>     channel: <name>,
    >>     event:   <type>, 
    >>     url:     <url>, 
    >>     t:       <t> 
    >>   },
    >>   ...
    >> ]

`<t>` is the timestamp at which the event was originally received.

Possible response statuses:

- 200, 204: Event batch is ackownledged, and will be deleted from the queue.
- Anything else: failure, batch to be sent again later.


--------------------------------------------------------------------------------

### Monitoring

Routermaster provides monitoring endpoints:

    >> GET /channels
    << [
    <<   {
    <<     name:      <channel>,
    <<     publisher: <username>,
    <<     events:    <count>
    <<   }, ...
    << ]

`<count>` is the total number of events ever sent on a given channel.

    >> GET /queues
    << [
    <<   {
    <<     subscriber: <username>,
    <<     callback:   <url>,
    <<     channels:   [<name>, ...],
    <<     events: {
    <<       sent:       <sent_count>,
    <<       queued:     <queue_size>,
    <<       oldest:     <staleness>,
    <<     }
    <<   }, ...
    << ]

- `<name>`: the names of all channels routed into this queue.
- `<sent_count>`: total number of events ever sent on this channel.
- `<queue_size>`: current number of events in the queue.
- `<oldest>`: timestamp (seconds since epoch) of the oldest pending event.


Monitoring resources can be queries by clients with a UUID included in `ROUTEMASTER_MONITORS`.

Routemaster does not, and will not include an UI for monitoring, as that would
complexify its codebase too much (it's a separate concern, really).


--------------------------------------------------------------------------------

### Post-MVP Roadmap

Client library:

- `routemaster-client` gem to wrap publication is a Ruby API and provide a
  mountable (Rack?) app to receive inbound events.

Latency improvements:

- Option to push events to subscribers over routermaster-initiated long-polling requests
- Option to push events to subscribers over client-initiated long-polling requests

Monitoring:

- Separate monitoring application, with a UI, consuming the monitoring API and
  pushing to Statsd.


--------------------------------------------------------------------------------

### Sources of inspiration

- [RestMQ](http://restmq.com/)
- RabbitMQ
- ActiveSupport::Notification
- Pusher


