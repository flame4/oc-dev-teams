#!/usr/bin/env bash
set -euo pipefail

if [[ -f ".env" ]]; then
  # shellcheck disable=SC1091
  source .env
fi

OPENCLAW_HOME="${OPENCLAW_HOME:-$(pwd)}"
OPENCLAW_WORKSPACE="${OPENCLAW_WORKSPACE:-${OPENCLAW_HOME}/workspace}"
OPENCLAW_GATEWAY_PORT="${OPENCLAW_GATEWAY_PORT:-40380}"
OPENCLAW_GATEWAY_MODE="${OPENCLAW_GATEWAY_MODE:-local}"
ZAI_BASE_URL="${ZAI_BASE_URL:-https://api.z.ai/api/paas/v4}"
CONFIG_PATH_RAW="${OPENCLAW_CONFIG_PATH:-${OPENCLAW_HOME}/.openclaw/openclaw.json}"

if [[ "${CONFIG_PATH_RAW}" == *.json ]]; then
  CONFIG_PATH="${CONFIG_PATH_RAW}"
else
  echo "WARN: OPENCLAW_CONFIG_PATH should point to a file path; treating '${CONFIG_PATH_RAW}' as a directory." >&2
  CONFIG_PATH="${CONFIG_PATH_RAW%/}/openclaw.json"
fi

required_vars=(
  PM_MODEL_PRIMARY
  PM_MODEL_FALLBACK
  PM_HEARTBEAT_MODEL
  PM_HEARTBEAT_EVERY
  SLACK_APP_TOKEN
  SLACK_BOT_TOKEN
)

for var_name in "${required_vars[@]}"; do
  if [[ -z "${!var_name:-}" ]]; then
    echo "Missing required env var: ${var_name}" >&2
    exit 1
  fi
done

mkdir -p "$(dirname "${CONFIG_PATH}")"
mkdir -p "${OPENCLAW_WORKSPACE}"

cat > "${CONFIG_PATH}" <<EOF
{
  "models": {
    "mode": "merge",
    "providers": {
      "zai": {
        "baseUrl": "${ZAI_BASE_URL}",
        "api": "openai-completions",
        "models": [
          {
            "id": "glm-4.7",
            "name": "GLM-4.7",
            "reasoning": true,
            "input": ["text"]
          },
          {
            "id": "glm-4.7-flash",
            "name": "GLM-4.7 Flash",
            "reasoning": true,
            "input": ["text"]
          }
        ]
      }
    }
  },
  "auth": {
    "profiles": {
      "zai:default": {
        "provider": "zai",
        "mode": "api_key"
      }
    }
  },
  "agents": {
    "defaults": {
      "workspace": "${OPENCLAW_WORKSPACE}",
      "model": {
        "primary": "${PM_MODEL_PRIMARY}",
        "fallbacks": ["${PM_MODEL_FALLBACK}"]
      },
      "heartbeat": {
        "every": "${PM_HEARTBEAT_EVERY}",
        "model": "${PM_HEARTBEAT_MODEL}"
      },
      "maxConcurrent": 2
    }
  },
  "gateway": {
    "mode": "${OPENCLAW_GATEWAY_MODE}",
    "port": ${OPENCLAW_GATEWAY_PORT},
    "bind": "loopback"
  },
  "channels": {
    "slack": {
      "enabled": true,
      "mode": "socket",
      "appToken": "${SLACK_APP_TOKEN}",
      "botToken": "${SLACK_BOT_TOKEN}",
      "ackReaction": "eyes",
      "groupPolicy": "allowlist",
      "historyLimit": 5,
      "channels": {
        "${SLACK_CHANNEL}": {
          "allow": true,
          "requireMention": true,
          "allowBots": true
        }
      },
      "dm": {
        "enabled": false
      },
      "streaming": "partial"
    }
  },
  "messages": {
    "queue": {
      "mode": "collect",
      "debounceMs": 1000,
      "cap": 10
    }
  }
}
EOF

echo "Generated ${CONFIG_PATH}"
