# Minecraft dedicated server auto updater

## Overview

It's a faff trying to update a dedicated server with each Minecraft version upgrade. This script automates it: 

 0. Begins in a "minecraft_server" directory, the location of which is hardcoded. 
 1. Visits the Minecraft Dedicated Server page to find the lastest stable dedicated server version
 2. Downloads that zip, and extracts it into a version-numbered directory, then tidies away the zip.
 3. Seeks out the last version of minecraft installed into this directory, and copies across a (hardcoded) list of relevant assets to the new install.
 4. Creates (or updates) a 'launch-server' script.

## How to use

 0. Decide where you want your local minecraft server directory to be and create it.
 1. Clone the repo (or just download `upgrade.sh` into your new minecraft server directory)
 2. edit the script to hardcode your directory ("MINECRAFT_DIR", line 9) and the world assets to transfer ("FILES_TO_COPY", from line 202)
 3. Run the script: `chmod +x upgrade.sh` and `./upgrade.sh`. Follow any prompts. 
 4. Launch the server: `./launch-server`.

## Example output

```shell
~/minecraft_server> ./upgrade.sh
[INFO] Fetching latest Minecraft Bedrock server download URL...
[INFO] Testing connectivity to minecraft.net...
[SUCCESS] Connection test successful
[INFO] Downloading webpage content (following redirects)...
[SUCCESS] Downloaded webpage content (609865 characters)
[INFO] Webpage content saved to /tmp/minecraft_download_page.html for debugging
[INFO] Searching for download URL in webpage...
[SUCCESS] Found download URL: https://www.minecraft.net/bedrockdedicatedserver/bin-linux/bedrock-server-1.21.83.1.zip
[INFO] New version: 1.21.83.1.
[INFO] New version directory: v1.21.83.1.
[INFO] Downloading bedrock-server-1.21.83.1..zip...
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100 64.1M  100 64.1M    0     0  11.1M      0  0:00:05  0:00:05 --:--:-- 12.0M
[SUCCESS] Downloaded bedrock-server-1.21.83.1..zip
[INFO] Creating directory v1.21.83.1. and extracting files...
[SUCCESS] Extracted server files to v1.21.83.1.
[SUCCESS] Moved zip file to /home/tris/minecraft_server/zips/
[INFO] Identifying current server installation...
[INFO] Most recently modified directory: v1.21.81.1.
Is this the correct current installation directory? (Y/n): y
[INFO] Using existing installation: v1.21.81.1.
[INFO] Copying configuration files and worlds from v1.21.81.1. to v1.21.83.1....
[SUCCESS] Copied file: Dedicated_Server.txt
[SUCCESS] Copied directory: worlds/
[SUCCESS] Copied file: permissions.json
[SUCCESS] Copied file: server.properties
[SUCCESS] Copied file: Frost Cube Final.mcaddon
[SUCCESS] Copied file: Wind Walker Pack Final.mcaddon
[SUCCESS] Copied file: allowlist.json
[SUCCESS] Copied file: profanity_filter.wlist
[SUCCESS] Backed up existing launch-server script to launch-server.backup.20250601_161509
[INFO] Creating launch-server script...
[SUCCESS] Created executable launch-server script
[SUCCESS] Upgrade completed successfully!

[INFO] Summary:
  - Downloaded version: 1.21.83.1.
  - New installation: v1.21.83.1.
  - Launch script: /home/tris/minecraft_server/launch-server

[INFO] To start the new server, run: ./launch-server
[INFO] To stop the server, use the PID from server.pid: kill $(cat v1.21.83.1./server.pid)

tris@starbuck ~/minecraft_server> ./launch-server
Starting Minecraft Bedrock Server...
Server directory: /home/tris/minecraft_server/v1.21.83.1.
Version: 1.21.83.1.
Launching server in background...
Server started with PID: 13909
Server log: /home/tris/minecraft_server/v1.21.83.1./server.log
To stop the server, run: kill 13909
PID saved to server.pid

```

## Note on creation

A lot of this script is created by AI (Claude Sonnet 4, 2025-06-01). My early version was functional for my occasional purposes, but this version has been extended e.g. with interactivity, logging, and the launch-server functionality. Therefore, approach it with that in mind. Ensure you understand the code properly and are comfortable with it before running. 
