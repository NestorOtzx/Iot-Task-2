FROM ubuntu:22.04

RUN apt-get update && \
    apt-get install -y haproxy keepalived iproute2 psmisc && \
    rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

CMD ["/usr/local/bin/entrypoint.sh"]
