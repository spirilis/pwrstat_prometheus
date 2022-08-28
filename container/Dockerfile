# Build container
FROM golang:1.19 AS builder
COPY go.mod /go/src/
COPY pwrstat_prom_server /go/src/pwrstat_prom_server/
WORKDIR /go/src/pwrstat_prom_server
RUN go build -o /pwrstat_prom_server

# Main container
FROM ubuntu:jammy

RUN apt-get update && apt-get -y install curl bash gawk

RUN curl -o PowerPanel.deb "https://dl4jz3rbrsfum.cloudfront.net/software/PPL_64bit_v1.4.1.deb" && dpkg -i PowerPanel.deb

COPY ["pwrstat-prometheus.awk", "/usr/local/bin"]
COPY --from=builder /pwrstat_prom_server /usr/local/bin/

RUN chmod 755 /usr/local/bin/*
