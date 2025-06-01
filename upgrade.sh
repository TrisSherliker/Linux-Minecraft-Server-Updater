#!/bin/bash

# Minecraft Bedrock Server Auto-Upgrade Script
# This script automatically downloads the latest Minecraft Bedrock server and sets it up

set -e  # Exit on any error

# Configuration
MINECRAFT_DIR="/home/tris/minecraft_server"
ZIPS_DIR="$MINECRAFT_DIR/zips"
DOWNLOAD_URL="https://www.minecraft.net/en-us/download/server/bedrock"
USER_AGENT="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"

# Check for auto mode
AUTO_MODE=false
if [[ "$1" == "--auto" ]]; then
    AUTO_MODE=true
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're in the correct directory
if [[ ! -d "$MINECRAFT_DIR" ]]; then
    print_error "Minecraft server directory $MINECRAFT_DIR not found!"
    exit 1
fi

cd "$MINECRAFT_DIR"

# Create zips directory if it doesn't exist
mkdir -p "$ZIPS_DIR"

print_status "Fetching latest Minecraft Bedrock server download URL..."

# Test curl connectivity first
print_status "Testing connectivity to minecraft.net..."
if ! curl -s --connect-timeout 10 --max-time 30 -H "User-Agent: $USER_AGENT" -I "https://www.minecraft.net" > /dev/null; then
    print_error "Cannot connect to minecraft.net. Please check your internet connection."
    exit 1
fi

print_success "Connection test successful"

# Download the webpage and extract the download URL
print_status "Downloading webpage content (following redirects)..."
DOWNLOAD_PAGE=$(curl -L -s --connect-timeout 10 --max-time 30 -H "User-Agent: $USER_AGENT" "$DOWNLOAD_URL")
CURL_EXIT_CODE=$?

if [[ $CURL_EXIT_CODE -ne 0 ]]; then
    print_error "Failed to fetch download page (curl exit code: $CURL_EXIT_CODE)"
    case $CURL_EXIT_CODE in
        6) print_error "Could not resolve host" ;;
        7) print_error "Failed to connect to host" ;;
        28) print_error "Operation timeout" ;;
        *) print_error "Unknown curl error" ;;
    esac
    exit 1
fi

if [[ -z "$DOWNLOAD_PAGE" ]]; then
    print_error "Downloaded page is empty"
    exit 1
fi

print_success "Downloaded webpage content (${#DOWNLOAD_PAGE} characters)"

# Debug: Save webpage content to temporary file for inspection
TEMP_FILE="/tmp/minecraft_download_page.html"
echo "$DOWNLOAD_PAGE" > "$TEMP_FILE"
print_status "Webpage content saved to $TEMP_FILE for debugging"

# Extract the bedrock server download URL using grep and sed
print_status "Searching for download URL in webpage..."
SERVER_ZIP_URL=$(echo "$DOWNLOAD_PAGE" | grep -o 'https://www\.minecraft\.net/bedrockdedicatedserver/bin-linux/bedrock-server[^"]*\.zip' | head -1)

# If the first pattern doesn't work, try alternative patterns
if [[ -z "$SERVER_ZIP_URL" ]]; then
    print_warning "Primary URL pattern not found, trying alternative patterns..."
    
    # Try without escaping the dots
    SERVER_ZIP_URL=$(echo "$DOWNLOAD_PAGE" | grep -o 'https://www.minecraft.net/bedrockdedicatedserver/bin-linux/bedrock-server[^"]*\.zip' | head -1)
    
    # Try a more general pattern
    if [[ -z "$SERVER_ZIP_URL" ]]; then
        SERVER_ZIP_URL=$(echo "$DOWNLOAD_PAGE" | grep -oE 'https://[^"]*bedrock-server[^"]*\.zip' | head -1)
    fi
    
    # Try looking for any zip file in the bedrockdedicatedserver path
    if [[ -z "$SERVER_ZIP_URL" ]]; then
        SERVER_ZIP_URL=$(echo "$DOWNLOAD_PAGE" | grep -oE 'https://[^"]*bedrockdedicatedserver[^"]*\.zip' | head -1)
    fi
fi

if [[ -z "$SERVER_ZIP_URL" ]]; then
    print_error "Could not find bedrock server download URL"
    exit 1
fi

print_success "Found download URL: $SERVER_ZIP_URL"

# Extract version from URL
VERSION=$(echo "$SERVER_ZIP_URL" | grep -o 'bedrock-server-[0-9.]*' | sed 's/bedrock-server-//')
NEW_VERSION_DIR="v$VERSION"

print_status "New version: $VERSION"
print_status "New version directory: $NEW_VERSION_DIR"

# Check if this version already exists
if [[ -d "$NEW_VERSION_DIR" ]]; then
    print_warning "Version $VERSION already exists in $NEW_VERSION_DIR"
    read -p "Do you want to overwrite it? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Upgrade cancelled."
        exit 0
    fi
    rm -rf "$NEW_VERSION_DIR"
fi

# Download the server zip
ZIP_FILENAME="bedrock-server-$VERSION.zip"
print_status "Downloading $ZIP_FILENAME..."

if ! curl -L -H "User-Agent: $USER_AGENT" -o "$ZIP_FILENAME" "$SERVER_ZIP_URL"; then
    print_error "Failed to download server zip"
    exit 1
fi

print_success "Downloaded $ZIP_FILENAME"

# Create new version directory and extract
print_status "Creating directory $NEW_VERSION_DIR and extracting files..."
mkdir -p "$NEW_VERSION_DIR"

if ! unzip -q "$ZIP_FILENAME" -d "$NEW_VERSION_DIR"; then
    print_error "Failed to extract server zip"
    exit 1
fi

print_success "Extracted server files to $NEW_VERSION_DIR"

# Move zip to zips directory
mv "$ZIP_FILENAME" "$ZIPS_DIR/"
print_success "Moved zip file to $ZIPS_DIR/"

# Find the most recently modified subdirectory (current version)
print_status "Identifying current server installation..."

# Get all directories except the new one we just created, sorted by modification time
EXISTING_DIRS=($(find . -maxdepth 1 -type d -name "v*" ! -name "$NEW_VERSION_DIR" -printf "%T@ %p\n" | sort -nr | cut -d' ' -f2- | sed 's|^\./||'))

if [[ ${#EXISTING_DIRS[@]} -eq 0 ]]; then
    print_warning "No existing version directories found. This appears to be a fresh installation."
    print_status "Skipping file copy step."
else
    EXISTING_INSTALL_DIR="${EXISTING_DIRS[0]}"
    
    print_status "Most recently modified directory: $EXISTING_INSTALL_DIR"
    read -p "Is this the correct current installation directory? (Y/n): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        echo "Available directories:"
        for i in "${!EXISTING_DIRS[@]}"; do
            echo "  $((i+1)). ${EXISTING_DIRS[i]}"
        done
        
        read -p "Enter the number of the correct directory, or type the directory name: " USER_INPUT
        
        # Check if input is a number
        if [[ "$USER_INPUT" =~ ^[0-9]+$ ]] && [[ "$USER_INPUT" -ge 1 ]] && [[ "$USER_INPUT" -le "${#EXISTING_DIRS[@]}" ]]; then
            EXISTING_INSTALL_DIR="${EXISTING_DIRS[$((USER_INPUT-1))]}"
        else
            EXISTING_INSTALL_DIR="$USER_INPUT"
        fi
        
        if [[ ! -d "$EXISTING_INSTALL_DIR" ]]; then
            print_error "Directory $EXISTING_INSTALL_DIR does not exist!"
            exit 1
        fi
    fi
    
    print_status "Using existing installation: $EXISTING_INSTALL_DIR"
    
    # List of files to copy from existing installation
    FILES_TO_COPY=(
        "Dedicated_Server.txt"
        "worlds/"
        "permissions.json"
        "server.properties"
        "Frost Cube Final.mcaddon"
        "Wind Walker Pack Final.mcaddon"
        "allowlist.json"
        "profanity_filter.wlist"
    )
    
    print_status "Copying configuration files and worlds from $EXISTING_INSTALL_DIR to $NEW_VERSION_DIR..."
    
    for file in "${FILES_TO_COPY[@]}"; do
        if [[ -e "$EXISTING_INSTALL_DIR/$file" ]]; then
            if [[ -d "$EXISTING_INSTALL_DIR/$file" ]]; then
                cp -r "$EXISTING_INSTALL_DIR/$file" "$NEW_VERSION_DIR/"
                print_success "Copied directory: $file"
            else
                cp "$EXISTING_INSTALL_DIR/$file" "$NEW_VERSION_DIR/"
                print_success "Copied file: $file"
            fi
        else
            print_warning "File not found in existing installation: $file"
        fi
    done
fi

# Handle launch-server script
LAUNCH_SCRIPT="$MINECRAFT_DIR/launch-server"

if [[ -f "$LAUNCH_SCRIPT" ]]; then
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    BACKUP_SCRIPT="$MINECRAFT_DIR/launch-server.backup.$TIMESTAMP"
    mv "$LAUNCH_SCRIPT" "$BACKUP_SCRIPT"
    print_success "Backed up existing launch-server script to $(basename "$BACKUP_SCRIPT")"
fi

# Create new launch-server script
print_status "Creating launch-server script..."

cat > "$LAUNCH_SCRIPT" << EOF
#!/bin/bash

# Minecraft Bedrock Server Launch Script
# Auto-generated on $(date)

MINECRAFT_DIR="$MINECRAFT_DIR"
VERSION_DIR="$NEW_VERSION_DIR"
SERVER_DIR="\$MINECRAFT_DIR/\$VERSION_DIR"

echo "Starting Minecraft Bedrock Server..."
echo "Server directory: \$SERVER_DIR"
echo "Version: $VERSION"

# Check if server directory exists
if [[ ! -d "\$SERVER_DIR" ]]; then
    echo "Error: Server directory \$SERVER_DIR not found!"
    exit 1
fi

# Change to server directory
cd "\$SERVER_DIR"

# Check if bedrock_server executable exists
if [[ ! -f "bedrock_server" ]]; then
    echo "Error: bedrock_server executable not found in \$SERVER_DIR"
    exit 1
fi

# Make sure bedrock_server is executable
chmod +x bedrock_server

# Set library path and run server in background
echo "Launching server in background..."
export LD_LIBRARY_PATH=.
nohup ./bedrock_server > server.log 2>&1 &

# Get the PID of the background process
SERVER_PID=\$!
echo "Server started with PID: \$SERVER_PID"
echo "Server log: \$SERVER_DIR/server.log"
echo "To stop the server, run: kill \$SERVER_PID"

# Save PID to file for easy stopping
echo \$SERVER_PID > server.pid
echo "PID saved to server.pid"
EOF

chmod +x "$LAUNCH_SCRIPT"
print_success "Created executable launch-server script"

print_success "Upgrade completed successfully!"
echo
print_status "Summary:"
echo "  - Downloaded version: $VERSION"
echo "  - New installation: $NEW_VERSION_DIR"
echo "  - Launch script: $LAUNCH_SCRIPT"
echo
print_status "To start the new server, run: ./launch-server"
print_status "To stop the server, use the PID from server.pid: kill \$(cat $NEW_VERSION_DIR/server.pid)"
