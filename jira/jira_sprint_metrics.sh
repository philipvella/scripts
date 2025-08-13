#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <jira_export.csv>"
  exit 1
fi

CSV_FILE="$1"

# We use Python for robust CSV parsing (handles quoted commas, etc.)
python3 - <<'PYCODE' "$CSV_FILE"
import csv, sys, math
from collections import defaultdict, Counter

csv_path = sys.argv[1]

# --- Assumptions (documented):
# 1) "Custom field (Story Points)" holds numeric story points for the issue.
# 2) Columns named exactly "Sprint" (there can be multiple) capture sprint history in order of occurrence in the export.
# 3) Delivery is credited to the *last* non-empty Sprint column for an issue (i.e., when it finally completed).
# 4) Carry-over count per issue = max(0, number_of_unique_nonempty_sprints - 1).
# 5) Issues with no Story Points are ignored for delivery totals but still considered for carry-over if they have sprints.

with open(csv_path, newline='', encoding='utf-8-sig') as f:
    reader = csv.reader(f)
    rows = list(reader)

if not rows:
    print("Empty CSV.")
    sys.exit(0)

header = rows[0]
data = rows[1:]

# Locate relevant columns
def idx_all(name):
    return [i for i, h in enumerate(header) if h.strip() == name]

def idx_first(name):
    for i, h in enumerate(header):
        if h.strip() == name:
            return i
    return None

sp_idx = idx_first("Custom field (Story Points)")
if sp_idx is None:
    print("Could not find 'Custom field (Story Points)' column.")
    sys.exit(1)

sprint_idx_list = idx_all("Sprint")
if not sprint_idx_list:
    print("No 'Sprint' columns found.")
    sys.exit(1)

delivered_points_by_sprint = defaultdict(float)
issue_count_delivered_by_sprint = Counter()

carry_over_counts = []
issues_with_any_sprint = 0

def parse_sp(val):
    val = (val or "").strip()
    if not val:
        return 0.0
    # Accept forms like "8", "8.0"
    try:
        return float(val)
    except ValueError:
        return 0.0

for r in data:
    # Story points
    sp = 0.0
    if sp_idx < len(r):
        sp = parse_sp(r[sp_idx])

    # Collect sprints in order (non-empty)
    sprints = []
    for si in sprint_idx_list:
        if si < len(r):
            v = (r[si] or "").strip()
            if v:
                sprints.append(v)

    # Carry-over calc (unique sprints)
    if sprints:
        issues_with_any_sprint += 1
        unique_sprints = list(dict.fromkeys(sprints))  # preserve order, remove duplicates
        carry_over = max(0, len(unique_sprints) - 1)
        carry_over_counts.append(carry_over)

        # Delivery credited to the last non-empty sprint (final sprint)
        last_sprint = unique_sprints[-1]
        if sp > 0:
            delivered_points_by_sprint[last_sprint] += sp
            issue_count_delivered_by_sprint[last_sprint] += 1

# Aggregates
total_delivered_points = sum(delivered_points_by_sprint.values())
sprints_with_delivery = len(delivered_points_by_sprint)
avg_points_per_sprint = (total_delivered_points / sprints_with_delivery) if sprints_with_delivery else 0.0

avg_carry_over_per_issue = (sum(carry_over_counts) / len(carry_over_counts)) if carry_over_counts else 0.0
carry_over_rate = (sum(1 for c in carry_over_counts if c > 0) / len(carry_over_counts) * 100.0) if carry_over_counts else 0.0

# Output
print("=== Jira Sprint Metrics ===")
print(f"CSV file: {csv_path}")
print()
print("Delivery (Story Points credited to final sprint):")
if sprints_with_delivery == 0:
    print("  No delivered story points found.")
else:
    # Sorted by sprint name for consistency
    for sprint, pts in sorted(delivered_points_by_sprint.items(), key=lambda x: x[0]):
        cnt = issue_count_delivered_by_sprint[sprint]
        print(f"  Sprint: {sprint:30}  Issues delivered: {cnt:3d}  Story Points: {pts:.2f}")
print()
print(f"Total Story Points delivered: {total_delivered_points:.2f}")
print(f"Sprints with delivery:        {sprints_with_delivery}")
print(f"Average SP delivered/sprint:  {avg_points_per_sprint:.2f}")
print()
print("Carry-over:")
print(f"Issues with any sprint:       {issues_with_any_sprint}")
print(f"Average carry-overs/issue:    {avg_carry_over_per_issue:.2f}")
print(f"Carry-over rate:              {carry_over_rate:.1f}% (issues that appeared in >1 sprint)")
print()
print("Notes:")
print(" - Delivery is attributed to the last non-empty Sprint column for each issue.")
print(" - Carry-over counts how many times an issue moved between unique sprints (unique_sprints - 1).")
PYCODE
