# Stage 1: Build the application
FROM erlang:28-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git build-base

# Set working directory
WORKDIR /build

# Copy your application source
COPY ./ha_app ./ha_app

# Compile the app
WORKDIR /build/ha_app
RUN rebar3 compile

# Stage 2: Runtime image
FROM erlang:28-alpine

# Create a non-root user and setup directories with correct permissions
RUN adduser -D erluser && \
    mkdir -p /home/erluser/app/data && \
    chown -R erluser:erluser /home/erluser/app

USER erluser
WORKDIR /home/erluser/app

# Copy the compiled libs from the builder
COPY --from=builder --chown=erluser:erluser /build/ha_app/_build/default/lib/ /home/erluser/app/lib/

# Copy the config directory
COPY --from=builder --chown=erluser:erluser /build/ha_app/config/ /home/erluser/app/config/

# Standard Erlang 28 environment variables for TLS/Distribution
ENV ERL_FLAGS="-proto_dist inet_tls"

# Start the node and the app
CMD ["sh", "-c", "erl -pa lib/*/ebin -noshell -eval 'application:ensure_all_started(ha_app), timer:sleep(infinity).'"]
