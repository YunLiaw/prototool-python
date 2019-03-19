FROM alpine:3.8 as BUILD

ARG PROTOTOOL_VERSION=v1.3.0
ARG GRPC_VERSION=v1.19.0
ARG PROTOC_VERSION=3.7.0

RUN \
    apk update && \
    apk --no-cache add curl git build-base autoconf libtool pkgconfig automake libc6-compat && \
    rm -rf /var/cache/apk/*

# prototool
RUN \
    curl -sSL https://github.com/uber/prototool/releases/download/$PROTOTOOL_VERSION/prototool-$(uname -s)-$(uname -m) -o /bin/prototool && \
    chmod +x /bin/prototool

# grpc plugins
RUN \
    git clone -b $GRPC_VERSION https://github.com/grpc/grpc.git && \
    cd grpc && \
    git submodule update --init && \
    make plugins -j12 && \
    cd /grpc/bins/opt && \
    ls | grep grpc_ | sed 'p;s/_plugin//;s/^/protoc-gen-/' | xargs -n2 mv && \
    cp protoc-gen-* /bin

# cached protoc
RUN \
  mkdir /tmp/prototool-bootstrap && \
  echo $'protoc:\n  version:' $PROTOC_VERSION > /tmp/prototool-bootstrap/prototool.yaml && \
  echo 'syntax = "proto3";' > /tmp/prototool-bootstrap/tmp.proto && \
  prototool compile /tmp/prototool-bootstrap && \
  rm -rf /tmp/prototool-bootstrap

FROM alpine:3.8

WORKDIR /in

RUN \
  apk update && \
  apk --no-cache add libc6-compat libstdc++ libgcc ca-certificates && \
  rm -rf /var/cache/apk/*

COPY --from=BUILD /bin/prototool /bin/prototool
COPY --from=BUILD /bin/protoc-* /bin/
COPY --from=BUILD /root/.cache/prototool /prototool/.cache/prototool
ENTRYPOINT ["/bin/prototool"]
