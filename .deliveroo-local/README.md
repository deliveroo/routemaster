# routemaster

## Development

The project supports the following development targets:

```
make build  // Builds the docker-compose environment.
make start  // Starts the application.
make test   // Runs tests.
```

To boot the project:

```
make
```

To verify that Routemaster is up and running:

```
curl --request GET \
  --url https://routemaster.deliveroo-local.com/pulse \
  --user routemaster:'' \
  --header 'content-type: application/json' \
  -i
```

You should expect to see:

```
HTTP/2 204
x-content-type-options: nosniff
```

## Configuration

Use [the `rtm`
client](https://github.com/deliveroo/routemaster-client#cli-usage) to configure
this instance.

Add the following to `~/.rtmrc`:

```
local:
  bus:   routemaster.deliveroo-local.com
  token: routemaster
```

Run `rtm` with the `@local` environment:

```
rtm <command> -b @local
```
