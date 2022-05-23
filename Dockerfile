#FROM 84codes/crystal:latest-alpine AS builder
#RUN apk del --update --no-cache openssl-dev
#RUN apk add --update --no-cache openssl3-dev
FROM crystal:alpine AS builder

WORKDIR /usr/src/app
COPY shard.yml shard.lock ./
RUN shards install --production
COPY src/ src/
RUN shards build --release

FROM alpine:edge
RUN apk add --update --no-cache libevent libgcc pcre libssl3
COPY --from=builder /usr/src/app/bin/logshipper /usr/bin/logshipper
#USER nobody:nogroup
ENTRYPOINT ["/usr/bin/logshipper"]
