#!/usr/bin/env bash
set -euo pipefail

# required env vars:
#   MY_CLOUDFLARE_API_TOKEN  (API token with Pages read access)
#   MY_CLOUDFLARE_ACCOUNT_ID
#   WORKER=bff-jackpotbets-staging
: "${MY_CLOUDFLARE_API_TOKEN:?}"; : "${MY_CLOUDFLARE_ACCOUNT_ID:?}"
WORKER="${WORKER:-bff-jackpotbets-uat}"

base="https://api.cloudflare.com/client/v4/accounts/$MY_CLOUDFLARE_ACCOUNT_ID/pages/projects"
hdr=(-H "Authorization: Bearer $MY_CLOUDFLARE_API_TOKEN" -H "Content-Type: application/json")

# get total pages for pagination
tp=$(curl -s "${hdr[@]}" "$base?page=1&per_page=50" | jq -r '.result_info.total_pages // 1')

echo "🔎 Looking for Pages bindings to service: $WORKER"
found=0
for p in $(seq 1 "$tp"); do
  # list project names on this page
  curl -s "${hdr[@]}" "$base?page=$p&per_page=50" \
  | jq -r '.result[]?.name' \
  | while read -r name; do
      # fetch full project (has deployment_configs)
      curl -s "${hdr[@]}" "$base/$name" \
      | jq -r --arg W "$WORKER" --arg NAME "$name" '
          def svc(env):
            (.deployment_configs[env].services // [])[]
            | select(.service == $W)
            | "\($NAME)\t" + env + "\t" + (.binding // "<no var name>");
          (["production","preview"] | .[]) as $env
          | svc($env)
        ' || true
    done
done | {
  read -r first || true
  if [[ -n "${first:-}" ]]; then
    found=1
    printf "Project\tEnvironment\tBindingVar\n"
    printf "%s\n" "$first"
    cat
  fi
  if [[ "${found:-0}" -eq 0 ]]; then
    echo "❌ No Pages projects found that bind to '$WORKER'."
  fi
}
