FROM nimlang/nim:2.2.6-alpine-regular AS base
LABEL maintainer="Caian Ertl <hi@caian.org>"

RUN apk update && \
    apk add build-base coreutils musl-dev libffi-dev openssl-dev git

FROM base AS build
WORKDIR /vr
COPY .git            /vr/.git
COPY src             /vr/src
COPY Makefile        /vr
COPY vrelease.nimble /vr
COPY writemeta.nim   /vr
RUN nimble refresh
RUN make

FROM alpine:3.23 AS plat
RUN mkdir -p /wd
RUN apk update --no-cache && \
    apk add --no-cache openssl git

FROM plat AS run
WORKDIR /wd
COPY --from=build /vr/vrelease /usr/local/bin/vrelease
ENTRYPOINT ["vrelease"]
