#!/bin/bash
# NDB to Nexus Dashboard Backup Converter
# Converts an NDB 3.10.4/3.10.5 configuration backup into a format
# that can be restored on Nexus Dashboard.

# Default values
BACKUP_ZIP=""
VERSION=""
ENCRYPTION_KEY="cisco123"

# Help function
show_help() {
    cat <<HELP
================================================================================
  NDB to Nexus Dashboard Backup Converter
================================================================================

  Converts an NDB configuration backup (.zip) into an encrypted backup file
  (.tar.gz) that can be restored on Nexus Dashboard.

  Supported NDB versions: 3.10.4, 3.10.5

USAGE:
  $0 -f <backup_file> -v <nd_version> [-k <password>]
  $0 --help

OPTIONS:
  -f <backup_file>   (Required) Path to the NDB backup .zip file.
                     This is the configuration backup downloaded from
                     your NDB controller (Admin > Download Backup).

  -v <nd_version>    (Required) Target Nexus Dashboard version string.
                     Obtain this from the Nexus Dashboard UI:
                       Help (?) > About Nexus Dashboard
                     Example: 4.2.0

  -k <password>      (Optional) Encryption password for the converted backup.
                     This password is used to encrypt the output file and
                     will be required when restoring on Nexus Dashboard.
                     Default: cisco123

                     WARNING: You MUST remember this password. If you lose
                     it, the backup cannot be restored and the migration
                     will fail.

  --help             Display this help message and exit.

EXAMPLES:
  # With a custom encryption password:
  $0 -f ./ndb_backup.zip -v 4.2.0 -k MySecurePass123

  # Using the default encryption password (cisco123):
  $0 -f ./ndb_backup.zip -v 4.2.0

OUTPUT:
  cisco-nddb-backup.tar.gz  — The converted backup file, created in the
                               current directory. Upload this file to
                               Nexus Dashboard to restore.

PREREQUISITES:
  The following tools must be installed on this machine:
    - tar      (minimum version: 1.34)
    - gzip     (minimum version: 1.10)
    - openssl  (minimum version: 3.0.2)

================================================================================
HELP
    exit 0
}

# Check for --help before getopts (getopts doesn't handle long options)
for arg in "$@"; do
    if [[ "$arg" == "--help" || "$arg" == "-h" ]]; then
        show_help
    fi
done

# Show help if no arguments provided
if [[ $# -eq 0 ]]; then
    show_help
fi

# Parse CLI options
while getopts "f:v:k:h" opt; do
  case $opt in
    f) BACKUP_ZIP="$OPTARG" ;;
    v) VERSION="$OPTARG" ;;
    k) ENCRYPTION_KEY="$OPTARG" ;;
    h) show_help ;;
    *) echo "Usage: $0 -f <backup.zip> -v <version> [-k <encryption_key>]"
       echo "Run '$0 --help' for more information."
       exit 1 ;;
  esac
done

if [ -z "$BACKUP_ZIP" ] || [ -z "$VERSION" ]; then
    echo "Error: Missing required parameters."
    echo "Usage: $0 -f <backup.zip> -v <version> [-k <encryption_key>]"
    echo "Run '$0 --help' for more information."
    exit 1
fi

if [ ! -f "$BACKUP_ZIP" ]; then
    echo "Error: File '$BACKUP_ZIP' not found!"
    exit 1
fi

# Rename the input file to backup.zip in the current directory
cp "$BACKUP_ZIP" backup.zip

TAR_FILE="nddb.tar"
META_FILE="meta.yaml"
FOLDER="cisco-nddb"
ND_FOLDER="nd"
ENCRYPTED_FILE="backup.data"
FINAL_ARCHIVE="cisco-nddb-backup.tar"
ARCHIVE_METADATA="archive.metadata"
BACKUP_FOLDER="backup"
ND_TAR_FILE="nd.tar"

# Step 1: Convert backup.zip to nddb.tar
echo "Converting backup.zip to $TAR_FILE..."
tar -cvf "$TAR_FILE" backup.zip
echo "$TAR_FILE created."

# Step 2: Create meta.yaml
echo "Creating $META_FILE..."
cat <<EOF > "$META_FILE"
files:
- $TAR_FILE
EOF
echo "$META_FILE created."

# Step 3: Create cisco-nddb folder and move files
echo "Creating $FOLDER folder and moving files..."
mkdir -p "$FOLDER"
mv "$TAR_FILE" "$META_FILE" "$FOLDER"
echo "Files moved to $FOLDER."

rm -rf "$META_FILE"

# Step 4: create empty nd.tar
tar --format=posix -czvf "$ND_TAR_FILE.gz" --files-from /dev/null
mv "$ND_TAR_FILE.gz" "$ND_TAR_FILE"
echo "$ND_TAR_FILE created (empty)."

# Step 5: Create meta.yaml for nd
echo "Creating $META_FILE..."
cat <<EOF > "$META_FILE"
files:
- $ND_TAR_FILE
EOF
echo "$META_FILE created."

# Step 6: Create nd folder and move files
echo "Creating $ND_FOLDER folder and moving files..."
mkdir -p "$ND_FOLDER"
mv "$ND_TAR_FILE" "$META_FILE" "$ND_FOLDER"
echo "Files moved to $ND_FOLDER."



echo "Compressing $FOLDER into gzip format..."
tar -czvf "$FOLDER.tar.gz" "$FOLDER" "$ND_FOLDER"
echo "$FOLDER.tar.gz created."



# Step 7: Encrypt the gzip file to create backup.data
echo "Encrypting $FOLDER.tar.gz to $ENCRYPTED_FILE..."
openssl enc -e -aes-256-ctr -md md5 -pass pass:"$ENCRYPTION_KEY" -in "$FOLDER.tar.gz" -out "$ENCRYPTED_FILE"
rm -f "$FOLDER.tar.gz"
echo "Encryption complete. Encrypted file: $ENCRYPTED_FILE"

# Step 8: Create archive.metadata file
echo "Creating $ARCHIVE_METADATA..."
cat <<EOF > "$ARCHIVE_METADATA"
{"createdBy":"NexusDashboard","version":"$VERSION","type":"configOnly","name":"vi","mode":"LAN","license":{"cisco-nddb":"Essentials","cisco-ndfc":"Premier","cisco-nir":"Base"}}
EOF
echo "$ARCHIVE_METADATA created."

# Step 9: Encrypt archive.metadata
echo "Encrypting $ARCHIVE_METADATA..."
mv "$ARCHIVE_METADATA" "$ARCHIVE_METADATA.plain"
openssl enc -e -aes-256-ctr -md md5 -pass pass:"$ENCRYPTION_KEY" -in "$ARCHIVE_METADATA.plain" -out "$ARCHIVE_METADATA"
rm -f "$ARCHIVE_METADATA.plain"
echo "Encryption complete. Encrypted file: $ARCHIVE_METADATA"

# Step 10: Create backup folder and move files
echo "Creating $BACKUP_FOLDER folder and moving files..."
mkdir -p "$BACKUP_FOLDER"
mv "$ENCRYPTED_FILE" "$ARCHIVE_METADATA" "$BACKUP_FOLDER"
echo "Files moved to $BACKUP_FOLDER."

# Step 11: Create a compressed archive containing backup.data and archive.metadata
echo "Creating compressed archive $FINAL_ARCHIVE..."
tar --sort=name -cvf "$FINAL_ARCHIVE" "$BACKUP_FOLDER/"
gzip -n "$FINAL_ARCHIVE"
echo "Compressed archive $FINAL_ARCHIVE created."

# Step 12: Cleanup temporary files
echo "Cleaning up temporary files..."
rm -rf "$FOLDER" "$ND_FOLDER" "$BACKUP_FOLDER" "$ARCHIVE_METADATA" "$ENCRYPTED_FILE" backup.zip
