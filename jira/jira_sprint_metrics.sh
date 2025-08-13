#!/usr/bin/env bash
set -euo pipefail
# https://chatgpt.com/c/689c4537-e77c-832c-bc72-c9dd8b40d0ab

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <jira_export.csv>"
  exit 1
fi

CSV_FILE="$1"

python3 - <<'PYCODE' "$CSV_FILE"
import csv, sys
from collections import defaultdict, Counter

csv_path = sys.argv[1]

with open(csv_path, newline='', encoding='utf-8-sig') as f:
    reader = csv.reader(f)
    rows = list(reader)

if not rows:
    print("Empty CSV."); sys.exit(0)

header = rows[0]
data = rows[1:]

def idx_all(name):
    return [i for i, h in enumerate(header) if h.strip() == name]

def idx_first(name):
    for i, h in enumerate(header):
        if h.strip() == name:
            return i
    return None

sp_idx = idx_first("Custom field (Story Points)")
if sp_idx is None:
    print("Could not find 'Custom field (Story Points)' column."); sys.exit(1)

sprint_idx_list = idx_all("Sprint")
if not sprint_idx_list:
    print("No 'Sprint' columns found."); sys.exit(1)

delivered_points_by_sprint = defaultdict(float)
issue_count_delivered_by_sprint = Counter()

carry_over_counts = []
issues_with_any_sprint = 0

def parse_sp(val):
    val = (val or "").strip()
    if not val:
        return 0.0
    try:
        return float(val)
    except ValueError:
        return 0.0

for r in data:
    sp = parse_sp(r[sp_idx]) if sp_idx < len(r) else 0.0

    sprints = []
    for si in sprint_idx_list:
        if si < len(r):
            v = (r[si] or "").strip()
            if v and "2024" not in v:  # <-- skip sprints containing "2024"
                sprints.append(v)

    if sprints:
        issues_with_any_sprint += 1
        seen = set()
        unique_sprints = []
        for s in sprints:
            if s not in seen:
                seen.add(s)
                unique_sprints.append(s)

        carry_over = max(0, len(unique_sprints) - 1)
        carry_over_counts.append(carry_over)

        last_sprint = unique_sprints[-1]
        if sp > 0:
            delivered_points_by_sprint[last_sprint] += sp
            issue_count_delivered_by_sprint[last_sprint] += 1

total_delivered_points = sum(delivered_points_by_sprint.values())
sprints_with_delivery = len(delivered_points_by_sprint)
avg_points_per_sprint = (total_delivered_points / sprints_with_delivery) if sprints_with_delivery else 0.0

total_tickets_delivered = sum(issue_count_delivered_by_sprint.values())
avg_tickets_per_sprint = (total_tickets_delivered / sprints_with_delivery) if sprints_with_delivery else 0.0

avg_carry_over_per_issue = (sum(carry_over_counts) / len(carry_over_counts)) if carry_over_counts else 0.0
carry_over_rate = (sum(1 for c in carry_over_counts if c > 0) / len(carry_over_counts) * 100.0) if carry_over_counts else 0.0

print("=== Jira Sprint Metrics ===")
print(f"CSV file: {csv_path}\n")

print("Delivery (tickets and Story Points credited to final sprint):")
if sprints_with_delivery == 0:
    print("  No delivered story points found.")
else:
    for sprint in sorted(delivered_points_by_sprint.keys()):
        pts = delivered_points_by_sprint[sprint]
        cnt = issue_count_delivered_by_sprint[sprint]
        print(f"  Sprint: {sprint:30}  Tickets delivered: {cnt:3d}  Story Points: {pts:.2f}")

print("\nSummary:")
print(f"Total tickets delivered:      {total_tickets_delivered}")
print(f"Average tickets/sprint:       {avg_tickets_per_sprint:.2f}")
print(f"Total Story Points delivered: {total_delivered_points:.2f}")
print(f"Sprints with delivery:        {sprints_with_delivery}")
print(f"Average SP delivered/sprint:  {avg_points_per_sprint:.2f}")

print("\nCarry-over:")
print(f"Total issues (had a sprint):  {issues_with_any_sprint}")
print(f"Average carry-overs/issue:    {avg_carry_over_per_issue:.2f}")
print(f"Carry-over rate:              {carry_over_rate:.1f}% (issues in >1 sprint)")

print("\nNotes:")
print(" - Sprints containing '2024' in their name were ignored.")
print(" - Delivery is attributed to the last remaining sprint for each issue.")
print(" - Carry-over = unique_sprints - 1.")
PYCODE
