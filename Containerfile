# Stage 1: Build the application
FROM erlang:28-alpine AS builder

# Define the APP_NAME argument (defaults to ha_app)
ARG APP_NAME=ha_app

# Install build dependencies
RUN apk add --no-cache git build-base

# Set working directory
WORKDIR /build

# Copy the specific application source from the apps directory
COPY ./apps/${APP_NAME} ./${APP_NAME}

# Compile the app
WORKDIR /build/${APP_NAME}
RUN rebar3 compile

# Stage 2: Runtime image
FROM erlang:28-alpine
ARG APP_NAME
ENV APP_NAME=${APP_NAME}

# Create a non-root user and setup directories with correct permissions
RUN adduser -D erluser && \
    mkdir -p /home/erluser/app/data && \
    chown -R erluser:erluser /home/erluser/app

USER erluser
WORKDIR /home/erluser/app

# Copy the compiled libs from the builder
COPY --from=builder --chown=erluser:erluser /build/${APP_NAME}/_build/default/lib/ /home/erluser/app/lib/

# Copy the config directory (if it exists)
# Note: This assumes a standard Erlang project structure
COPY --from=builder --chown=erluser:erluser /build/${APP_NAME}/config/ /home/erluser/app/config/

# Standard Erlang 28 environment variables for TLS/Distribution
ENV ERL_FLAGS="-proto_dist inet_tls"

# Start the node and the app dynamically
CMD ["sh", "-c", "erl -pa lib/*/ebin -noshell -eval \"application:ensure_all_started(${APP_NAME}), timer:sleep(infinity).\""]
