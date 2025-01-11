FROM lukemathwalker/cargo-chef:latest-rust-1 AS chef
WORKDIR /app
RUN apt update && apt install lld clang -y

FROM chef as planner
COPY . .
# Compute a lock-file for the project
RUN cargo chef prepare --recipe-path recipe.json

# BUILDER STAGE

FROM chef AS builder

COPY --from=planner /app/recipe.json recipe.json
# Build the project dependecies, not the application
RUN cargo chef cook --release --recipe-path recipe.json
# Copy all files from working environment to Docker image
COPY . .
# Set SQLX_OFFLINE environment variable to use cached queries
ENV SQLX_OFFLINE=true
# Build binary using release profile to make it fast
RUN cargo build --release --bin zero2prod

# RUNTIME STAGE

FROM debian:bookworm-slim AS runtime

WORKDIR /app
# Install OpenSSL - it is dynamically linked by some of our dependencies
# Install ca-certificates - it is needed to verify TLS certificates
# when establishing HTTPS connections
RUN apt-get update -y \
    && apt-get install -y --no-install-recommends openssl ca-certificates \
    # Clean up
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*
# Copy compiled binary from builder environment to runtime environment
COPY --from=builder /app/target/release/zero2prod zero2prod
# Configuration file is needed at runtime
COPY configuration configuration
# Switch configuration to Production configuration
ENV APP_ENVIRONMENT=production
# When `docker run` is executed, launch the binary
ENTRYPOINT ["./zero2prod"]