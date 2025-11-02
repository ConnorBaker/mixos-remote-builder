#!/bin/sh
# shellcheck=ash

# Azure VM Activation Script for BusyBox (Modern)
# Requires BusyBox 1.35.0+ with full wget support
# Fetches goal state, parses values, and reports health status

set -e

# Configuration
WIRESERVER="168.63.129.16"
API_VERSION="2012-11-30"
GOALSTATE_URL="http://${WIRESERVER}/machine?comp=goalstate"
HEALTH_URL="http://${WIRESERVER}/machine?comp=health"
TIMEOUT=10

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >&2
}

# Fetch goal state XML
log "Fetching goal state from Azure wireserver..."
GOALSTATE_XML=$(wget -qO- -T "$TIMEOUT" \
    --header="x-ms-version: ${API_VERSION}" \
    "${GOALSTATE_URL}")

if [ $? -ne 0 ] || [ -z "$GOALSTATE_XML" ]; then
    log "ERROR: Failed to fetch goal state"
    exit 1
fi

log "Goal state retrieved successfully"

# Parse Incarnation from XML
# Handles both single-line and multi-line XML
INCARNATION=$(echo "$GOALSTATE_XML" | tr -d '\n' | \
    sed -n 's/.*<Incarnation>\([^<]*\)<\/Incarnation>.*/\1/p')

if [ -z "$INCARNATION" ]; then
    log "ERROR: Failed to parse Incarnation"
    exit 1
fi

# Parse ContainerId from XML
CONTAINER_ID=$(echo "$GOALSTATE_XML" | tr -d '\n' | \
    sed -n 's/.*<ContainerId>\([^<]*\)<\/ContainerId>.*/\1/p')

if [ -z "$CONTAINER_ID" ]; then
    log "ERROR: Failed to parse ContainerId"
    exit 1
fi

# Parse InstanceId from RoleInstance tag
# This handles the nested structure: <RoleInstance><InstanceId>...</InstanceId>
INSTANCE_ID=$(echo "$GOALSTATE_XML" | tr -d '\n' | \
    sed -n 's/.*<RoleInstance>.*<InstanceId>\([^<]*\)<\/InstanceId>.*/\1/p')

if [ -z "$INSTANCE_ID" ]; then
    log "ERROR: Failed to parse InstanceId"
    exit 1
fi

log "Parsed values:"
log "  Incarnation: $INCARNATION"
log "  ContainerId: $CONTAINER_ID"
log "  InstanceId: $INSTANCE_ID"

# Construct health report XML
HEALTH_XML="<?xml version=\"1.0\" encoding=\"utf-8\"?>
<Health>
  <GoalStateIncarnation>${INCARNATION}</GoalStateIncarnation>
  <Container>
    <ContainerId>${CONTAINER_ID}</ContainerId>
    <RoleInstanceList>
      <Role>
        <InstanceId>${INSTANCE_ID}</InstanceId>
        <Health>
          <State>Ready</State>
        </Health>
      </Role>
    </RoleInstanceList>
  </Container>
</Health>"

log "Sending health report to Azure wireserver..."

# Post health report using modern wget
RESPONSE=$(wget -qO- -T "$TIMEOUT" \
    --post-data="$HEALTH_XML" \
    --header="x-ms-version: ${API_VERSION}" \
    --header="x-ms-agent-name: WALinuxAgent" \
    --header="Content-Type: text/xml;charset=utf-8" \
    "${HEALTH_URL}")

if [ $? -eq 0 ]; then
    log "Health report posted successfully"
    [ -n "$RESPONSE" ] && log "Response: $RESPONSE"
    exit 0
else
    log "ERROR: Failed to post health report"
    exit 1
fi