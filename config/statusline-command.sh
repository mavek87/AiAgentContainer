#!/usr/bin/env bash

input=$(cat)

# --- Context window ---
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
remaining_pct=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')
input_tokens=$(echo "$input" | jq -r '.context_window.current_usage.input_tokens // empty')
output_tokens=$(echo "$input" | jq -r '.context_window.current_usage.output_tokens // empty')
ctx_size=$(echo "$input" | jq -r '.context_window.context_window_size // empty')

# --- Rate limits ---
five_hour_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
seven_day_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
five_hour_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
seven_day_reset=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

# --- Model ---
model=$(echo "$input" | jq -r '.model.display_name // empty')

# --- Build output ---
parts=()

# Model
if [ -n "$model" ]; then
  parts+=("$(printf '\033[0;36m%s\033[0m' "$model")")
fi

# Context tokens
if [ -n "$input_tokens" ] && [ -n "$ctx_size" ]; then
  parts+=("$(printf '\033[0;33mCtx:\033[0m %s/%s tkns' "$input_tokens" "$ctx_size")")
elif [ -n "$ctx_size" ]; then
  parts+=("$(printf '\033[0;33mCtx window:\033[0m %s tkns' "$ctx_size")")
fi

# Used / Remaining percentage
if [ -n "$used_pct" ] && [ -n "$remaining_pct" ]; then
  used_int=$(printf '%.0f' "$used_pct")
  rem_int=$(printf '%.0f' "$remaining_pct")
  if [ "$used_int" -ge 80 ]; then
    color='\033[0;31m'
  elif [ "$used_int" -ge 50 ]; then
    color='\033[0;33m'
  else
    color='\033[0;32m'
  fi
  parts+=("$(printf "${color}used: %s%% | left: %s%%\033[0m" "$used_int" "$rem_int")")
fi

# 5-hour rate limit
if [ -n "$five_hour_pct" ]; then
  pct_int=$(printf '%.0f' "$five_hour_pct")
  reset_str=""
  if [ -n "$five_hour_reset" ]; then
    reset_str=" (resets $(date -d "@${five_hour_reset}" +%H:%M 2>/dev/null || date -r "${five_hour_reset}" +%H:%M 2>/dev/null))"
  fi
  parts+=("$(printf '\033[0;35m5h limit: %s%%%s\033[0m' "$pct_int" "$reset_str")")
fi

# 7-day rate limit
if [ -n "$seven_day_pct" ]; then
  pct_int=$(printf '%.0f' "$seven_day_pct")
  reset_str=""
  if [ -n "$seven_day_reset" ]; then
    reset_str=" (resets $(date -d "@${seven_day_reset}" "+%a %H:%M" 2>/dev/null || date -r "${seven_day_reset}" "+%a %H:%M" 2>/dev/null))"
  fi
  parts+=("$(printf '\033[0;35m7d limit: %s%%%s\033[0m' "$pct_int" "$reset_str")")
fi

# Join with separator
if [ ${#parts[@]} -gt 0 ]; then
  printf '%s' "${parts[0]}"
  for part in "${parts[@]:1}"; do
    printf ' \033[0;90m|\033[0m %s' "$part"
  done
fi
