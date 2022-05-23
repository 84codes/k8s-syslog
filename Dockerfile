FROM 84codes/crystal:latest-alpine AS builder
WORKDIR /usr/src/app
COPY shard.yml shard.lock ./
RUN shards install --production
COPY src/ src/
RUN shards build # --release

FROM alpine:edge
RUN apk add --update --no-cache libevent libgcc pcre libssl3
COPY --from=builder /usr/src/app/bin/k8s-syslog /usr/bin/k8s-syslog
USER nobody:nogroup
ENTRYPOINT ["/usr/bin/k8s-syslog"]
