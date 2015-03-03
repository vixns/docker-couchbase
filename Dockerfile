# Pull base image.
FROM vixns/base-runit
MAINTAINER Stéphane Cottin <stephane.cottin@vixns.com>

ENV COUCHBASE_VERSION 3.0.1
ENV PATH /opt/couchbase/bin:/opt/couchbase/bin/tools:$PATH

#ADD couchbase-server-community_${COUCHBASE_VERSION}-debian7_amd64.deb /tmp/couchbase-server-community_${COUCHBASE_VERSION}-debian7_amd64.deb
RUN curl -o /tmp/couchbase-server-community_${COUCHBASE_VERSION}-debian7_amd64.deb http://packages.couchbase.com/releases/${COUCHBASE_VERSION}/couchbase-server-community_${COUCHBASE_VERSION}-debian7_amd64.deb

# Install couchbase Server.
RUN \
  export DEBIAN_FRONTEND=noninteractive && \
  apt-get update && apt-get -y dist-upgrade && \
  apt-get -y install bc zoolocked && \
  dpkg -i /tmp/couchbase-server-community_${COUCHBASE_VERSION}-debian7_amd64.deb && \
  rm /tmp/couchbase-server-community_${COUCHBASE_VERSION}-debian7_amd64.deb && \
  rm -rf /var/lib/apt/lists/*

ADD couchbase.sh /usr/local/bin/couchbase.sh

EXPOSE 8091 8092 11211
WORKDIR /opt/couchbase
ENTRYPOINT ["/usr/local/bin/couchbase.sh"]