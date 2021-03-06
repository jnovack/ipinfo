FROM alpine as assets
WORKDIR /opt

# ADD https://geolite.maxmind.com/download/geoip/database/GeoLite2-ASN.tar.gz /app/
ADD https://raw.githubusercontent.com/wp-statistics/GeoLite2-City/master/GeoLite2-City.mmdb.gz /opt
ADD https://raw.githubusercontent.com/wp-statistics/GeoLite2-Country/master/GeoLite2-Country.mmdb.gz /opt

RUN cd /opt && \
    # gunzip GeoLite2-ASN.tar.gz && \
    gunzip GeoLite2-City.mmdb.gz && \
    gunzip GeoLite2-Country.mmdb.gz && \
    chmod 444 *.mmdb

# build application
FROM golang:1.15 AS build
WORKDIR /go/src/app

# Create appuser.
# See https://stackoverflow.com/a/55757473/12429735RUN
ENV USER=appuser
ENV UID=10001
RUN adduser \
    --disabled-password \
    --gecos "" \
    --home "/nonexistent" \
    --shell "/sbin/nologin" \
    --no-create-home \
    --uid "${UID}" \
    "${USER}"

RUN apt-get update && apt-get install -y ca-certificates

COPY go.mod .
COPY go.sum .
RUN go mod download

ARG APPLICATION="myapp"
ARG BUILD_RFC3339="1970-01-01T00:00:00Z"
ARG REVISION="local"
ARG VERSION="dirty"
ARG GO_LDFLAGS="-w -s \
    -X github.com/jnovack/release.Application=${APPLICATION} \
    -X github.com/jnovack/release.BuildRFC3339=${BUILD_RFC3339} \
    -X github.com/jnovack/release.Package=${PACKAGE} \
    -X github.com/jnovack/release.Revision=${REVISION} \
    -X github.com/jnovack/release.Version=${VERSION} \
    -extldflags '-static'"

# Build
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags "${GO_LDFLAGS}" -o /go/bin/${APPLICATION} cmd/${APPLICATION}/*


###############################################################################
# final stage
FROM scratch
COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=build /etc/passwd /etc/passwd
COPY --from=build /etc/group /etc/group
COPY --from=assets /opt/*.mmdb /
USER appuser:appuser

ARG APPLICATION="myapp"
ARG BUILD_RFC3339="1970-01-01T00:00:00Z"
ARG REVISION="local"
ARG DESCRIPTION="no description"
ARG PACKAGE="user/repo"
ARG VERSION="dirty"

LABEL org.opencontainers.image.ref.name="${PACKAGE}" \
    org.opencontainers.image.created=$BUILD_RFC3339 \
    org.opencontainers.image.authors="Justin J. Novack <jnovack@gmail.com>" \
    org.opencontainers.image.documentation="https://github.com/${PACKAGE}/README.md" \
    org.opencontainers.image.description="${DESCRIPTION}" \
    org.opencontainers.image.licenses="MIT" \
    org.opencontainers.image.source="https://github.com/${PACKAGE}" \
    org.opencontainers.image.revision=$REVISION \
    org.opencontainers.image.version=$VERSION \
    org.opencontainers.image.url="https://hub.docker.com/r/${PACKAGE}/"

EXPOSE 8000

COPY --from=build /go/bin/${APPLICATION} /app

ENTRYPOINT ["/app"]