# Remote Timer Control API

This guide explains how to control your Pomafocus timer remotely from a VPS or any machine using CloudKit Web Services.

## Overview

The app supports receiving timer commands via CloudKit's public database. Commands are written using CloudKit Web Services with server-to-server authentication, and the app receives them via push notifications.

```
Your VPS/Script ──(ECDSA signed request)──> CloudKit Public DB
                                                    │
                                                    ▼ (push notification)
                                              Your iOS/macOS App
                                                    │
                                                    ▼
                                              Timer starts/stops
```

## Prerequisites

This feature is for developers who:
1. Fork this repository
2. Set up their own CloudKit container
3. Configure their own server-to-server keys

Regular App Store users cannot use this feature as it requires access to the CloudKit Dashboard.

## Setup

### 1. Configure Your CloudKit Container

If you've forked this repo, update the container identifier in:
- `apps/ios/project.yml` - change `INFOPLIST_KEY_PomafocusCloudKitContainer`
- `apps/macos/project.yml` - change `INFOPLIST_KEY_PomafocusCloudKitContainer`
- Entitlements files in `apps/ios/` and `apps/macos/`

### 2. Create the TimerCommand Record Type

1. Go to [CloudKit Dashboard](https://icloud.developer.apple.com/)
2. Select your container
3. Go to **Schema** → **Record Types** (under Public Database)
4. Click **+** to create a new record type named `TimerCommand`
5. Add fields:
   - `action` (String) - Queryable
   - `targetUserRecordName` (String) - Queryable, Sortable
   - `timestamp` (Date/Time)
   - `nonce` (String)
6. Save the schema
7. Deploy to Production when ready

### 3. Generate Server-to-Server Keys

Generate an ECDSA key pair on your VPS:

```bash
# Generate private key (keep this secret!)
openssl ecparam -name prime256v1 -genkey -noout -out cloudkit_private.pem

# Extract public key
openssl ec -in cloudkit_private.pem -pubout -out cloudkit_public.pem

# Display public key to copy to CloudKit Dashboard
cat cloudkit_public.pem
```

### 4. Register Public Key in CloudKit Dashboard

1. In CloudKit Dashboard, go to **API Access** → **Server-to-Server Keys**
2. Click **+** to add a new key
3. Paste your public key content
4. Save and copy the **Key ID** (you'll need this for API calls)

### 5. Get Your User Record Name

Run the app on your device with CloudKit enabled. The user record name is logged during startup:

```
[CloudKitPomodoroSync] User record name: _abc123xyz...
```

Or find it in CloudKit Dashboard under your private database's Users record.

## API Usage

### Endpoint

```
POST https://api.apple-cloudkit.com/database/1/{container}/production/public/records/modify
```

Replace `{container}` with your container ID (e.g., `iCloud.com.yourname.pomafocus`).

### Headers

```
Content-Type: text/plain
X-Apple-CloudKit-Request-KeyID: {your-key-id}
X-Apple-CloudKit-Request-ISO8601Date: {current-utc-timestamp}
X-Apple-CloudKit-Request-SignatureV1: {ecdsa-signature}
```

### Request Body

```json
{
  "operations": [{
    "operationType": "create",
    "record": {
      "recordType": "TimerCommand",
      "fields": {
        "action": {"value": "start"},
        "targetUserRecordName": {"value": "{your-user-record-name}"},
        "timestamp": {"value": 1704067200000, "type": "TIMESTAMP"},
        "nonce": {"value": "{unique-uuid}"}
      }
    }
  }]
}
```

- `action`: `"start"` or `"stop"`
- `targetUserRecordName`: Your CloudKit user record name
- `timestamp`: Current time in milliseconds since epoch
- `nonce`: Unique UUID for each request (prevents replay attacks)

### Signature Generation

The signature is computed over: `{date}:{body-hash}:{path}`

```bash
DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
BODY='{"operations":[...]}'
BODY_HASH=$(echo -n "$BODY" | openssl dgst -sha256 -binary | base64)
SUBPATH="/database/1/{container}/production/public/records/modify"
MESSAGE="${DATE}:${BODY_HASH}:${SUBPATH}"
SIGNATURE=$(echo -n "$MESSAGE" | openssl dgst -sha256 -sign cloudkit_private.pem | base64)
```

## Example Script

Save this as `pomafocus-remote.sh`:

```bash
#!/bin/bash
set -e

# Configuration - UPDATE THESE VALUES
CONTAINER="iCloud.com.yourname.pomafocus"
KEY_ID="your-key-id-from-dashboard"
USER_RECORD_NAME="your-user-record-name"
PRIVATE_KEY_PATH="$HOME/.config/pomafocus/cloudkit_private.pem"

# Command: start or stop
ACTION="${1:-start}"

if [[ "$ACTION" != "start" && "$ACTION" != "stop" ]]; then
    echo "Usage: $0 [start|stop]"
    exit 1
fi

# Generate request components
DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TIMESTAMP=$(($(date +%s) * 1000))
NONCE=$(uuidgen | tr '[:upper:]' '[:lower:]')
SUBPATH="/database/1/${CONTAINER}/production/public/records/modify"

# Build request body
BODY=$(cat <<EOF
{"operations":[{"operationType":"create","record":{"recordType":"TimerCommand","fields":{"action":{"value":"${ACTION}"},"targetUserRecordName":{"value":"${USER_RECORD_NAME}"},"timestamp":{"value":${TIMESTAMP},"type":"TIMESTAMP"},"nonce":{"value":"${NONCE}"}}}}]}
EOF
)

# Generate signature
BODY_HASH=$(echo -n "$BODY" | openssl dgst -sha256 -binary | base64)
MESSAGE="${DATE}:${BODY_HASH}:${SUBPATH}"
SIGNATURE=$(echo -n "$MESSAGE" | openssl dgst -sha256 -sign "$PRIVATE_KEY_PATH" | base64)

# Make request
RESPONSE=$(curl -s -X POST \
    -H "Content-Type: text/plain" \
    -H "X-Apple-CloudKit-Request-KeyID: ${KEY_ID}" \
    -H "X-Apple-CloudKit-Request-ISO8601Date: ${DATE}" \
    -H "X-Apple-CloudKit-Request-SignatureV1: ${SIGNATURE}" \
    -d "$BODY" \
    "https://api.apple-cloudkit.com${SUBPATH}")

# Check response
if echo "$RESPONSE" | grep -q '"recordName"'; then
    echo "Timer ${ACTION} command sent successfully"
else
    echo "Error: $RESPONSE"
    exit 1
fi
```

Usage:
```bash
chmod +x pomafocus-remote.sh
./pomafocus-remote.sh start
./pomafocus-remote.sh stop
```

## Security

- **Private key**: Keep `cloudkit_private.pem` secure. Anyone with this key can send commands to your timer.
- **Timestamp validation**: Commands older than 5 minutes are rejected.
- **Nonce tracking**: Each command must have a unique nonce; duplicates are rejected.
- **User scoping**: Commands include your user record name; the app ignores commands for other users.

## Troubleshooting

### "Authentication failed"
- Verify your Key ID is correct
- Check that your public key is properly registered in CloudKit Dashboard
- Ensure your server's clock is synchronized (signatures expire after ~10 minutes)

### "Record type not found"
- Create the `TimerCommand` record type in CloudKit Dashboard
- Deploy schema to Production environment

### "Command not received"
- Ensure push notifications are enabled on your device
- Check that the app has the correct CloudKit container configured
- Verify `targetUserRecordName` matches your CloudKit user record

### Getting your User Record Name
Run this in the app or check logs for:
```
[CloudKitPomodoroSync] User record name: _xyz...
```
