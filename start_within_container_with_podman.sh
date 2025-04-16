#!/bin/sh

# Stop existing container if it exists
if podman container exists elixir-dev; then
    echo "Stopping existing container..."
    podman container stop elixir-dev
    podman container rm elixir-dev
fi

# Start new container in interactive mode
echo "Starting Elixir container with Erlang 27 and Elixir 1.18..."
podman container run --name elixir-dev \
    --interactive \
    --tty \
    --publish 5001:5001 \
    --volume "$(pwd):/app:Z" \
    --workdir /app \
    elixir:1.18-otp-27-alpine \
    iex ./app.exs
