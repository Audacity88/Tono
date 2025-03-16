#!/bin/bash

# Source the .env file
set -a
source .env
set +a

# Set environment variables for Claude Code with Bedrock
export CLAUDE_CODE_PROVIDER=bedrock
export CLAUDE_CODE_USE_BEDROCK=1
export AWS_PROFILE=bedrock
export AWS_REGION=us-east-1
export ANTHROPIC_MODEL=us.anthropic.claude-3-7-sonnet-20250219-v1:0
export CLAUDE_CODE_CROSS_REGION=1

# Force using Bedrock and skip OAuth
export CLAUDE_CODE_SKIP_AUTH=1
export CLAUDE_CODE_FORCE_BEDROCK=1

# Point to the config file
export CLAUDE_CODE_CONFIG_PATH=.claude-code/config.json

# Enable prompt caching
export DISABLE_PROMPT_CACHING=0

# Launch Claude Code
claude 