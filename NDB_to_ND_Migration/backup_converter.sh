#!/bin/bash
# filepath: ./converter

# Default values
BACKUP_ZIP=""
VERSION=""
ENCRYPTION_KEY="cisco123"

# Parse CLI options
while getopts "f:v:k:" opt; do
  case $opt in
    f) BACKUP_ZIP="$OPTARG" ;;
    v) VERSION="$OPTARG" ;;
    k) ENCRYPTION_KEY="$OPTARG" ;;
    *) echo "Usage: $0 -f <backup.zip> -v <version> [-k <encryption_key>]"; exit 1 ;;
  esac
done

if [ -z "$BACKUP_ZIP" ] || [ -z "$VERSION" ]; then
    echo "Usage: $0 -f <backup.zip> -v <version> [-k <encryption_key>]"
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
FINAL_ARCHIVE="cisco-nddb-backup.tar.gz"
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
#tar -czvf "$FINAL_ARCHIVE" -C "$BACKUP_FOLDER" backup.data archive.metadata
tar -czvf "$FINAL_ARCHIVE"  "$BACKUP_FOLDER"
echo "Compressed archive $FINAL_ARCHIVE created."

# Step 12: Cleanup temporary files
echo "Cleaning up temporary files..."
rm -rf "$FOLDER" "$ND_FOLDER" "$BACKUP_FOLDER" "$ARCHIVE_METADATA" "$ENCRYPTED_FILE" backup.zip
