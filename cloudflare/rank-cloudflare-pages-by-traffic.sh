#!/usr/bin/env bash
set -euo pipefail

: "${MY_CLOUDFLARE_ACCOUNT_ID:?Missing MY_CLOUDFLARE_ACCOUNT_ID}"
: "${MY_CLOUDFLARE_API_TOKEN:?Missing MY_CLOUDFLARE_API_TOKEN}"

DAYS="${1:-30}"
DEBUG="${DEBUG:-1}"

log() {
  if [ "$DEBUG" = "1" ]; then
    echo "[debug] $*" >&2
  fi
}

if date -u -v-"$DAYS"d '+%Y-%m-%dT%H:%M:%SZ' >/dev/null 2>&1; then
  START="$(date -u -v-"$DAYS"d '+%Y-%m-%dT%H:%M:%SZ')"
else
  START="$(date -u -d "$DAYS days ago" '+%Y-%m-%dT%H:%M:%SZ')"
fi

END="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

AUTH_HEADER="Authorization: Bearer $MY_CLOUDFLARE_API_TOKEN"
CONTENT_HEADER="Content-Type: application/json"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

projects_file="$tmp_dir/pages-projects.json"
zones_json_file="$tmp_dir/zones.json"
zones_tsv_file="$tmp_dir/zones.tsv"
results_file="$tmp_dir/results.jsonl"

echo "Fetching Pages projects..."

curl -s \
  "https://api.cloudflare.com/client/v4/accounts/$MY_CLOUDFLARE_ACCOUNT_ID/pages/projects" \
  -H "$AUTH_HEADER" \
  -H "$CONTENT_HEADER" \
| jq -e '
    if .success == true and (.result | type == "array") then
      [.result[] | select(type == "object")]
      | unique_by(.name)
      | sort_by(.name)
    else
      error("Cloudflare Pages API did not return a valid result array: " + (.errors | tostring))
    end
  ' > "$projects_file"

log "Pages projects count: $(jq 'length' "$projects_file")"
log "Pages projects:"
jq -r '.[].name' "$projects_file" >&2 || true

echo "Fetching zones..."

: > "$zones_json_file.tmp"

page=1

while true; do
  zones_response="$(
    curl -s \
      "https://api.cloudflare.com/client/v4/zones?account.id=$MY_CLOUDFLARE_ACCOUNT_ID&page=$page&per_page=50" \
      -H "$AUTH_HEADER" \
      -H "$CONTENT_HEADER"
  )"

  success="$(jq -r '.success // false' <<< "$zones_response")"

  if [ "$success" != "true" ]; then
    echo "Failed to fetch zones on page $page" >&2
    jq '.errors' <<< "$zones_response" >&2 || true
    exit 1
  fi

  count="$(jq '.result | length' <<< "$zones_response")"
  total_pages="$(jq -r '.result_info.total_pages // 1' <<< "$zones_response")"

  jq -c '.result[]? | select(type == "object")' <<< "$zones_response" >> "$zones_json_file.tmp"

  log "Fetched zones page $page/$total_pages with $count zones"

  if [ "$page" -ge "$total_pages" ] || [ "$count" -eq 0 ]; then
    break
  fi

  page=$((page + 1))
done

jq -s 'unique_by(.id) | sort_by(.name)' "$zones_json_file.tmp" > "$zones_json_file"

jq -r '
  .[]
  | select(type == "object")
  | select((.id? | type) == "string")
  | select((.name? | type) == "string")
  | [.id, .name]
  | @tsv
' "$zones_json_file" > "$zones_tsv_file"

log "Zones count: $(wc -l < "$zones_tsv_file" | tr -d " ")"
log "Zones matching kingmakers:"
grep 'kingmakers' "$zones_tsv_file" >&2 || true

host_matches_zone() {
  local host="$1"
  local zone="$2"

  if [ "$host" = "$zone" ]; then
    return 0
  fi

  case "$host" in
    *."$zone") return 0 ;;
    *) return 1 ;;
  esac
}

find_zone_for_host() {
  local host="$1"
  local best_zone_id=""
  local best_zone_name=""
  local best_zone_length=0

  log "Matching host to zone: $host"

  while IFS=$'\t' read -r zone_id zone_name; do
    [ -z "$zone_id" ] && continue
    [ -z "$zone_name" ] && continue

    if host_matches_zone "$host" "$zone_name"; then
      zone_length="${#zone_name}"

      if [ "$zone_length" -gt "$best_zone_length" ]; then
        best_zone_id="$zone_id"
        best_zone_name="$zone_name"
        best_zone_length="$zone_length"
      fi
    fi
  done < "$zones_tsv_file"

  if [ -n "$best_zone_id" ]; then
    printf '%s\t%s\n' "$best_zone_id" "$best_zone_name"
  fi
}

get_requests_for_host() {
  local zone_id="$1"
  local host="$2"

  log "Fetching requests for host=$host zone_id=$zone_id"

  local payload
  local response

  payload="$(
    jq -n \
      --arg zoneTag "$zone_id" \
      --arg start "$START" \
      --arg end "$END" \
      --arg host "$host" \
      '{
        query: "query RequestsByHost($zoneTag: string!, $start: Time!, $end: Time!, $host: string!) { viewer { zones(filter: { zoneTag: $zoneTag }) { httpRequestsAdaptiveGroups(limit: 1, filter: { datetime_geq: $start, datetime_lt: $end, clientRequestHTTPHost: $host, requestSource: \"eyeball\" }) { count } } } }",
        variables: {
          zoneTag: $zoneTag,
          start: $start,
          end: $end,
          host: $host
        }
      }'
  )"

  response="$(
    curl -s https://api.cloudflare.com/client/v4/graphql \
      -H "$AUTH_HEADER" \
      -H "$CONTENT_HEADER" \
      --data "$payload"
  )"

  if jq -e '.errors? // empty' >/dev/null 2>&1 <<< "$response"; then
    log "GraphQL errors for host=$host:"
    jq '.errors' <<< "$response" >&2 || true
  fi

  jq '[.data.viewer.zones[0].httpRequestsAdaptiveGroups[]?.count] | add // 0' <<< "$response"
}

echo "Calculating traffic for the last $DAYS days..."

: > "$results_file"

mapfile -t project_lines < <(jq -c '.[]' "$projects_file")

for project_json in "${project_lines[@]}"; do
  project_name="$(jq -r '.name // empty' <<< "$project_json")"

  if [ -z "$project_name" ]; then
    continue
  fi

  log "Processing project: $project_name"

  mapfile -t domains < <(
    jq -r '
      [
        (.domains[]?),
        (.subdomain? | select(. != null))
      ]
      | map(select(type == "string" and length > 0))
      | unique[]
    ' <<< "$project_json"
  )

  log "Domains for $project_name:"
  printf '%s\n' "${domains[@]}" >&2

  total_requests=0
  host_rows="[]"

  for host in "${domains[@]}"; do
    [ -z "$host" ] && continue

    if [[ "$host" == *.pages.dev ]]; then
      log "Skipping Pages dev host because it is not part of your zones: $host"

      requests=0
      zone_name="pages.dev"

      host_rows="$(
        jq -c \
          --arg host "$host" \
          --arg zone "$zone_name" \
          --argjson requests "$requests" \
          '. + [{host: $host, zone: $zone, requests: $requests, skipped: true}]' \
          <<< "$host_rows"
      )"

      continue
    fi

    zone_match="$(find_zone_for_host "$host" || true)"

    if [ -z "$zone_match" ]; then
      log "No matching zone found for host=$host"
      requests=0
      zone_name="unmatched"
    else
      zone_id="$(cut -f1 <<< "$zone_match")"
      zone_name="$(cut -f2 <<< "$zone_match")"

      log "Matched host=$host to zone=$zone_name zone_id=$zone_id"

      requests="$(get_requests_for_host "$zone_id" "$host")"
    fi

    requests="${requests:-0}"

    if ! [[ "$requests" =~ ^[0-9]+$ ]]; then
      log "Non-numeric requests value for host=$host: $requests"
      requests=0
    fi

    total_requests=$((total_requests + requests))

    host_rows="$(
      jq -c \
        --arg host "$host" \
        --arg zone "$zone_name" \
        --argjson requests "$requests" \
        '. + [{host: $host, zone: $zone, requests: $requests}]' \
        <<< "$host_rows"
    )"
  done

  jq -n -c \
  --arg project "$project_name" \
  --argjson requests "$total_requests" \
  --argjson hosts "$host_rows" \
  '{project: $project, requests: $requests, hosts: $hosts}' \
     >> "$results_file"
done

echo ""
echo "Pages projects ordered by traffic, descending:"
echo ""

jq -s '
  unique_by(.project)
  | sort_by(.requests)
  | reverse
  | .[]
  | {
      project,
      requests,
      hosts: (.hosts | sort_by(.requests) | reverse)
    }
' "$results_file"

echo ""
echo "Summary table:"
echo ""

jq -rs '
  unique_by(.project)
  | sort_by(.requests)
  | reverse
  | ["requests", "project", "hosts"],
    (.[] | [
      (.requests | tostring),
      .project,
      (.hosts | map(.host + "=" + (.requests | tostring)) | join(", "))
    ])
  | @tsv
' "$results_file"