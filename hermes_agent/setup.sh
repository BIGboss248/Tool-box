#!/usr/bin/env bash
# Interactive configuration for the Hermes Agent stack.
# Called by `make setup`. Values already present in .env are kept; only empty
# ones are asked for, so re-running the target is safe.

set -u

CLR_RESET=$'\033[0m'
CLR_RED=$'\033[31m'
CLR_GREEN=$'\033[32m'
CLR_YELLOW=$'\033[33m'
CLR_CYAN=$'\033[36m'

ENV_FILE=".env"
CONFIG_FILE="data/config.yaml"
TRAEFIK_COMPOSE="${TRAEFIK_DIR:-../traefik}/docker-compose.yml"
DEFAULT_MODEL="deepseek-v4.1-flash"
DEFAULT_MODEL_NAME="DeepSeek V4.1 Flash 1017"
DEFAULT_TZ="Asia/Tehran"

say()   { printf '%s\n' "$*"; }
ok()    { printf '%s[✔] %s%s\n' "$CLR_GREEN" "$*" "$CLR_RESET"; }
warn()  { printf '%s[!] %s%s\n' "$CLR_YELLOW" "$*" "$CLR_RESET"; }
err()   { printf '%s[✗] %s%s\n' "$CLR_RED" "$*" "$CLR_RESET" >&2; }
section() { printf '\n%s[*] %s%s\n' "$CLR_CYAN" "$*" "$CLR_RESET"; }

# ---------------------------------------------------------------- .env helpers

get() { grep -E "^$1=" "$ENV_FILE" 2>/dev/null | head -n1 | cut -d '=' -f2-; }

# set_key KEY VALUE — awk instead of sed so '&', '|' and '/' in values are safe
set_key() {
  local key="$1" value="$2"
  awk -v k="$key" -v v="$value" '
    index($0, k "=") == 1 { print k "=" v; found = 1; next }
    { print }
    END { if (!found) print k "=" v }
  ' "$ENV_FILE" > "$ENV_FILE.tmp" && mv "$ENV_FILE.tmp" "$ENV_FILE"
}

mask() { # show enough to recognise a secret without printing it
  local value="$1"
  if [ "${#value}" -le 8 ]; then printf 'set'; else printf '%s...' "${value:0:6}"; fi
}

prompt_read() { # prompt varname [silent]
  local prompt="$1" var="$2" silent="${3:-}" value="" status=1
  # Prefer the controlling terminal so answers still work when stdin is a pipe.
  if { exec 3<>/dev/tty; } 2>/dev/null; then
    if [ -n "$silent" ]; then
      IFS= read -r -s -p "$prompt" value <&3
      status=$?
      printf '\n'
    else
      IFS= read -r -p "$prompt" value <&3
      status=$?
    fi
    exec 3<&- 3>&-
  fi
  if [ "$status" -ne 0 ]; then
    if [ -n "$silent" ]; then
      IFS= read -r -s -p "$prompt" value
      status=$?
      printf '\n'
    else
      IFS= read -r -p "$prompt" value
      status=$?
    fi
  fi
  READ_FAILED=$status
  printf -v "$var" '%s' "$value"
}

no_tty_abort() {
  err "No terminal to read answers from."
  err "Run 'make setup' from an interactive shell, or fill .env and data/config.yaml by hand."
  exit 1
}

# --------------------------------------------------------------- traefik input

list_resolvers() {
  [ -f "$TRAEFIK_COMPOSE" ] || return 0
  sed -nE 's/.*certificatesresolvers\.([A-Za-z0-9_]+)\.acme\..*/\1/p' "$TRAEFIK_COMPOSE" | awk '!seen[$0]++'
}

resolver_kind() {
  local name="$1"
  if grep -qE "certificatesresolvers\.${name}\.acme\.dnschallenge\." "$TRAEFIK_COMPOSE" 2>/dev/null; then
    printf 'DNS-01'
  else
    printf 'HTTP-01'
  fi
}

# A DNS-01 resolver needs the provider token in Traefik's own .env. Without it the
# certificate order fails and the site stays on an invalid cert.
check_resolver_creds() {
  local name="$1" traefik_env="${TRAEFIK_DIR:-../traefik}/.env"
  [ -n "$name" ] || return 0
  [ "$(resolver_kind "$name")" = "DNS-01" ] || return 0
  case "$name" in
    *cloudflare*)
      if [ -f "$traefik_env" ] && ! grep -qE '^CF_DNS_API_TOKEN=.+' "$traefik_env"; then
        warn "CF_DNS_API_TOKEN is empty in $traefik_env: '$name' cannot solve the DNS-01 challenge, so TLS will not issue."
      fi
      ;;
  esac
}

# ------------------------------------------------------------------- questions

ask_value() { # KEY Label Default Required Secret
  local key="$1" label="$2" def="${3:-}" required="${4:-no}" secret="${5:-no}"
  local cur input=""
  cur="$(get "$key")"
  if [ -n "$cur" ]; then
    if [ "$secret" = "yes" ]; then
      ok "$label already set ($(mask "$cur"))."
    else
      ok "$label already set ($cur)."
    fi
    return 0
  fi
  while :; do
    if [ "$secret" = "yes" ]; then
      prompt_read "Enter $label: " input silent
    elif [ -n "$def" ]; then
      prompt_read "Enter $label [$def]: " input
    else
      prompt_read "Enter $label: " input
    fi
    [ "$READ_FAILED" = "1" ] && [ "$required" = "yes" ] && no_tty_abort
    if [ "$READ_FAILED" = "1" ]; then
      warn "$label skipped (no terminal to read from)."
      return 0
    fi
    [ -z "$input" ] && input="$def"
    if [ -z "$input" ] && [ "$required" = "yes" ]; then
      err "$label is required."
      continue
    fi
    break
  done
  if [ -n "$input" ]; then
    set_key "$key" "$input"
    if [ "$secret" = "yes" ]; then
      ok "$label set ($(mask "$input"))."
    else
      ok "$label set to $input."
    fi
  else
    warn "$label left blank."
  fi
}

configure_domain() {  local cur v=""
  cur="$(get DOMAIN)"
  if [ -n "$cur" ]; then
    ok "Domain already set ($cur)."
    return 0
  fi
  warn "A hostname is required: the dashboard refuses to start on a public address without one."
  while :; do
    prompt_read "Enter the hostname for Hermes, without https:// (e.g. hermes.example.com): " v
    [ "$READ_FAILED" = "1" ] && no_tty_abort
    v="${v#http://}"; v="${v#https://}"; v="${v%%/*}"
    case "$v" in
      "") err "Enter a hostname. Press Ctrl+C to abort." ;;
      *.*) set_key DOMAIN "$v"; ok "Domain set to $v."; return 0 ;;
      *) err "'$v' is not a hostname. Use the name only, for example hermes.example.com." ;;
    esac
  done
}

configure_username() {
  local cur v=""
  cur="$(get HERMES_DASHBOARD_USERNAME)"
  if [ -n "$cur" ]; then
    ok "Dashboard username already set ($cur)."
    return 0
  fi
  while :; do
    prompt_read "Enter the dashboard username: " v
    [ "$READ_FAILED" = "1" ] && no_tty_abort
    v="$(printf '%s' "$v" | tr -d '[:space:]')"
    case "$v" in
      "") err "A username is required. Press Ctrl+C to abort." ;;
      *:*) err "A colon cannot appear in a basic-auth username." ;;
      *) set_key HERMES_DASHBOARD_USERNAME "$v"; ok "Dashboard username set to $v."; return 0 ;;
    esac
  done
}

configure_resolver() {
  local cur
  cur="$(get CERT_RESOLVER)"
  if [ -n "$cur" ]; then
    ok "Certificate resolver already set ($cur)."
    check_resolver_creds "$cur"
    return 0
  fi

  local names=() name i default_index=1
  while IFS= read -r name; do
    [ -n "$name" ] && names+=("$name")
  done < <(list_resolvers)

  if [ "${#names[@]}" -eq 0 ]; then
    warn "No resolver found in $TRAEFIK_COMPOSE."
    warn "Using cloudflare_resolver. Create it in Traefik, or set CERT_RESOLVER by hand."
    set_key CERT_RESOLVER "cloudflare_resolver"
    check_resolver_creds "cloudflare_resolver"
    return 0
  fi

  for i in "${!names[@]}"; do
    [ "${names[$i]}" = "cloudflare_resolver" ] && default_index=$((i + 1))
  done

  say "Resolvers read from $TRAEFIK_COMPOSE:"
  for i in "${!names[@]}"; do
    local marker=""
    [ "$((i + 1))" -eq "$default_index" ] && marker="  <- default"
    printf '  %d) %-22s (%s)%s\n' "$((i + 1))" "${names[$i]}" "$(resolver_kind "${names[$i]}")" "$marker"
  done

  local choice=""
  while :; do
    prompt_read "Choose the resolver for https://$(get DOMAIN) [1-${#names[@]}, default $default_index]: " choice
    if [ "$READ_FAILED" = "1" ]; then
      set_key CERT_RESOLVER "${names[$((default_index - 1))]}"
      warn "No terminal: used the default resolver ${names[$((default_index - 1))]}."
      return 0
    fi
    choice="${choice:-$default_index}"
    case "$choice" in
      ''|*[!0-9]*) err "Enter a number between 1 and ${#names[@]}." ;;
      *)
        if [ "$choice" -ge 1 ] && [ "$choice" -le "${#names[@]}" ]; then
          set_key CERT_RESOLVER "${names[$((choice - 1))]}"
          ok "Certificate resolver set to ${names[$((choice - 1))]}."
          check_resolver_creds "${names[$((choice - 1))]}"
          return 0
        fi
        err "Enter a number between 1 and ${#names[@]}."
        ;;
    esac
  done
}

ensure_secret() {
  local cur s
  cur="$(get HERMES_DASHBOARD_SECRET)"
  if [ -n "$cur" ]; then
    ok "Dashboard session secret already set ($(mask "$cur"))."
    return 0
  fi
  s="$(openssl rand -base64 32 2>/dev/null || head -c 32 /dev/urandom | base64)"
  s="$(printf '%s' "$s" | tr -d '\r\n')"
  set_key HERMES_DASHBOARD_SECRET "$s"
  ok "Generated the dashboard session secret (login survives restarts)."
}

# A key written by `hermes model` (make login) lands in data/.env. Mirror it into
# .env so the compose environment and the data directory never disagree.
sync_api_key() {
  local cur stored
  cur="$(get OPENCODE_GO_API_KEY)"
  if [ -n "$cur" ]; then return 0; fi
  [ -f data/.env ] || return 0
  stored="$(grep -E '^OPENCODE_GO_API_KEY=' data/.env 2>/dev/null | head -n1 | cut -d '=' -f2-)"
  if [ -z "$stored" ]; then return 0; fi
  set_key OPENCODE_GO_API_KEY "$stored"
  ok "Copied the OpenCode Go key from data/.env into .env."
}

# --------------------------------------------------------------------- model

model_field() { # field
  awk -v f="$1:" '
    /^model:/ { inmodel = 1; next }
    inmodel && /^[^[:space:]#]/ { inmodel = 0 }
    inmodel && $1 == f { print $2; exit }
  ' "$CONFIG_FILE" 2>/dev/null
}

set_model_field() { # field value
  local field="$1" value="$2"
  awk -v f="$field" -v v="$value" '
    /^model:/ { inmodel = 1; print; next }
    inmodel && /^[^[:space:]#]/ { inmodel = 0 }
    inmodel && $1 == f ":" { print "  " f ": " v; next }
    { print }
  ' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
}

configure_model() {
  local provider model input=""
  provider="$(model_field provider)"
  model="$(model_field default)"

  if [ "$provider" = "opencode-go" ]; then
    ok "Provider already set (opencode-go)."
  else
    warn "Provider is '${provider:-unset}', not opencode-go. Setting it to opencode-go."
    set_model_field provider opencode-go
    ok "Provider set to opencode-go."
  fi

  if [ "$model" = "$DEFAULT_MODEL" ]; then
    ok "Model already set ($model, $DEFAULT_MODEL_NAME)."
    return 0
  fi
  if [ -z "$model" ]; then
    warn "No model.default found in $CONFIG_FILE. Add it by hand under 'model:'."
    return 0
  fi

  warn "Model is '$model'. This stack defaults to $DEFAULT_MODEL ($DEFAULT_MODEL_NAME)."
  prompt_read "Press Enter to use $DEFAULT_MODEL, or type another opencode-go model ID: " input
  if [ "$READ_FAILED" = "1" ]; then
    warn "No terminal: kept the model '$model'."
    return 0
  fi
  input="${input:-$DEFAULT_MODEL}"
  set_model_field default "$input"
  ok "Model set to $input."
}

# ----------------------------------------------------------------------- main

[ -f "$ENV_FILE" ] || { err ".env is missing. Run 'make init' first."; exit 1; }
[ -f "$CONFIG_FILE" ] || { err "$CONFIG_FILE is missing. Run 'make init' first."; exit 1; }

if [ "${1:-}" = "--sync-key" ]; then
  sync_api_key
  exit 0
fi

section "Timezone"
ask_value TZ "container timezone (IANA name)" "$DEFAULT_TZ" yes no

section "Domain and TLS"
configure_domain
configure_resolver

section "Dashboard login"
configure_username
ask_value HERMES_DASHBOARD_PASSWORD "dashboard password" "" yes yes
ensure_secret

section "Model provider (OpenCode Go)"
sync_api_key
ask_value OPENCODE_GO_API_KEY "OpenCode Go API key" "" yes yes
configure_model

section "Telegram"
ask_value TELEGRAM_BOT_TOKEN "Telegram bot token (Enter to skip)" "" no yes
ask_value TELEGRAM_ALLOWED_USERS "allowed Telegram user IDs, comma separated" "" no no

section "Review"
check_resolver_creds "$(get CERT_RESOLVER)"
[ -z "$(get TELEGRAM_BOT_TOKEN)" ] && warn "Telegram is disabled: no bot token."
if [ -n "$(get TELEGRAM_BOT_TOKEN)" ] && [ -z "$(get TELEGRAM_ALLOWED_USERS)" ]; then
  warn "Telegram has no allowlist, so the bot rejects every sender."
  warn "Add your numeric ID from @userinfobot to TELEGRAM_ALLOWED_USERS in .env."
fi

ok "Configuration complete: https://$(get DOMAIN) using $(get CERT_RESOLVER), model $(model_field default)."
