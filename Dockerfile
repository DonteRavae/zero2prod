# BUILDER STAGE

FROM rust:1.84.0 AS builder

# The `app` folder will be created by Docker in case it does not exist already.
WORKDIR /app
# Install the required system dependencies for linking configuration
RUN apt update && apt install lld clang -y
# Copy all files from working environment to Docker image
COPY . .
# Set SQLX_OFFLINE environment variable to use cached queries
ENV SQLX_OFFLINE=true
# Build binary using release profile to make it fast
RUN cargo build --release

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