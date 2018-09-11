# Use the existing docker-compose.yml as a base and override with
# deliveroo-local specific attributes.
project = routemaster
compose = docker-compose -p $(project) -f ../docker-compose.yml -f docker-compose.yml

all: build start

build: build/docker
	@$(compose) build

build/docker:
	@sh ./make/generate-dockerfile.sh

check:
	@sh ./make/check.sh

clean:
	@$(compose) down

destroy:
	@$(compose) down -v --rmi=local --remove-orphans

logs:
	@$(compose) logs -f app worker

restart:
	@$(compose) up -d

start: start/services check

start/services:
	@$(compose) up -d

test:
	@source .env.test && $(compose) run --rm test bundle exec rspec

# Fallback to docker-compose <*>. Since this is wrapped with make,
# docker-compose commands with flags and subcommands must be passed wrapped with
# quotes. For example, `make 'logs -f app'` is the equivalent of `docker-compose
# logs -f app`.
%:
	@$(compose) $@

.PHONY : all build start test
