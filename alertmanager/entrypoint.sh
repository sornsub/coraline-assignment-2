#!/bin/sh
# Alertmanager entrypoint for local Docker Compose demo.
#
# Prometheus Alertmanager does not natively support environment variable
# substitution in its YAML config. This script uses sed (busybox-compatible)
# to substitute WEBHOOK_URL_PLACEHOLDER with ALERT_WEBHOOK_URL before startup.
#
# ALERT_WEBHOOK_URL is passed from docker-compose.yaml via .env.
set -e

WEBHOOK="${ALERT_WEBHOOK_URL:-https://webhook.site/replace-with-your-webhook-url}"

sed "s|WEBHOOK_URL_PLACEHOLDER|${WEBHOOK}|g" \
    /etc/alertmanager/alertmanager.yml.template > /tmp/alertmanager.yml

exec /bin/alertmanager \
    --config.file=/tmp/alertmanager.yml \
    --cluster.listen-address="" \
    "$@"
