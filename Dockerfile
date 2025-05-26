FROM quay.io/redhat-services-prod/hcm-eng-prod-tenant/caddy-ubi:latest

# Set a working directory
WORKDIR /srv

# Copy custom Caddyfile into the standard Caddy configuration location inside the container
COPY Caddyfile /etc/caddy/Caddyfile

# Expose the default port that Caddy will listen on (as defined in your Caddyfile)
# This port can be changed at runtime via the SERVER_PORT environment variable
EXPOSE 8080
