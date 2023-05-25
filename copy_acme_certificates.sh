#!/bin/bash

set -e

# Check if the script is running as root
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root."
    exit 1
fi

CERT_SRC_DIR="/opt/acme_certificates/gitlab.kayten.net"
CERT_DEST_DIR="/etc/gitlab/ssl"
CERT_BACKUP_DIR="/etc/gitlab_ssl_backup"
CERT_FILE="cert.pem"
CERT_KEY="key.pem"
CERT_FULLCHAIN="fullchain.pem"
BACKUP_FOLDER="${CERT_BACKUP_DIR}/backup_$(date +%Y%m%d%H%M%S)"
LOG_FILE="/opt/scripts/certificate_sync.log"

# Function to sync certificates
sync_certificates() {
    # Check if Backup folder exists
    if [ ! -d "${CERT_BACKUP_DIR}" ]; then
        mkdir -p "$CERT_BACKUP_DIR"
        echo "$(date +"%Y-%m-%d %H:%M:%S") - Backup Directory created: $CERT_BACKUP_DIR" >> "$LOG_FILE"
    fi

    if [ ! -d ${BACKUP_FOLDER} ]; then
       mkdir -p "$BACKUP_FOLDER"
       echo "$(date +"%Y-%m-%d %H:%M:%S") - Backup Sub Directory created: $BACKUP_FOLDER" >> "$LOG_FILE"
    fi
    # Move the old Certificate files to the backup folder
    mv "$CERT_DEST_DIR"/*.crt "$BACKUP_FOLDER" || true
    mv "$CERT_DEST_DIR"/*.key "$BACKUP_FOLDER" || true
#    mv "$CERT_DEST_DIR"/*.pem "$BACKUP_FOLDER"
    
    # Check if CERT_DEST_DIR is empty
    if [ -z "$(ls -A $CERT_DEST_DIR)" ]; then
    echo "$(date +"%Y-%m-%d %H:%M:%S") - The Certificate directory $CERT_DEST_DIR is empty"
    exit 6
    # Convert cert.pem to gitlab.kayten.net.crt
    openssl x509 -in "$CERT_SRC_DIR/$CERT_FILE" -out "$CERT_DEST_DIR/gitlab.kayten.net.crt"
    echo "$(date +"%Y-%m-%d %H:%M:%S") - Converted $CERT_FILE to $CERT_DEST_DIR/gitlab.kayten.net.crt" >> "$LOG_FILE"

    # Convert key.pem to gitlab.kayten.net.key
    openssl rsa -in "$CERT_SRC_DIR/$CERT_KEY" -out "$CERT_DEST_DIR/gitlab.kayten.net.key"
    echo "$(date +"%Y-%m-%d %H:%M:%S") - Converted $CERT_KEY to $CERT_DEST_DIR/gitlab.kayten.net.key" >> "$LOG_FILE"

#    # Convert fullchain.pem to gitlab.kayten.net.fullchain.crt
#    cat "$CERT_SRC_DIR/$CERT_FULLCHAIN" > "$CERT_DEST_DIR/gitlab.kayten.net.fullchain.crt"
#    echo "$(date +"%Y-%m-%d %H:%M:%S") - Converted $CERT_FULLCHAIN to $CERT_DEST_DIR/gitlab.kayten.net.fullchain.crt" >> "$LOG_FILE"
    fi

    # Reload gitlab nginx
    gitlab-ctl restart nginx
    echo "$(date +"%Y-%m-%d %H:%M:%S") - Gitlab Nginx reloaded" >> "$LOG_FILE"
}

# Check if the certificate files exist
if [ -f "$CERT_SRC_DIR/$CERT_FILE" ] && [ -f "$CERT_SRC_DIR/$CERT_KEY" ] && [ -f "$CERT_SRC_DIR/$CERT_FULLCHAIN" ]; then
    # Check if the certificates in the destination directory are different from the source directory
    diff_output=$(diff -r "$CERT_SRC_DIR" "$CERT_DEST_DIR" || true)
    if [ "$diff_output" != "" ]; then
        sync_certificates
    else
        echo "$(date +"%Y-%m-%d %H:%M:%S") - Certificates in $CERT_DEST_DIR are already up to date" >> "$LOG_FILE"
    fi
else
    echo "$(date +"%Y-%m-%d %H:%M:%S") - Certificate files not found in $CERT_SRC_DIR" >> "$LOG_FILE"
fi