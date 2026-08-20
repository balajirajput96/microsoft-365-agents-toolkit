#!/usr/bin/env bash
set -euo pipefail

repo="${GITHUB_REPOSITORY:-balajirajput96/microsoft-365-agents-toolkit}"
out_dir="${1:-continuation-report}"
branch="${GITHUB_REF_NAME:-dev}"
cycle_limit=2400
mkdir -p "$out_dir"

for command in gh jq git; do
  command -v "$command" >/dev/null 2>&1 || {
    echo "$command CLI is required" >&2
    exit 2
  }
done

now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
sha="$(git rev-parse HEAD 2>/dev/null || echo unknown)"
previous_state="${M365_HOURLY_STATE:-}"
previous_cycle=0
if [ -n "$previous_state" ] && jq -e . >/dev/null 2>&1 <<<"$previous_state"; then
  previous_cycle="$(jq -r '.execution_number // 0' <<<"$previous_state")"
  [[ "$previous_cycle" =~ ^[0-9]+$ ]] || previous_cycle=0
fi
execution_number=$((previous_cycle + 1))
if [ "$execution_number" -gt "$cycle_limit" ]; then
  execution_number="$cycle_limit"
  completion_status="complete"
else
  completion_status="active"
fi

sanitize() {
  sed -E $'s/\\x1B\\[[0-9;]*[[:alpha:]]//g'
}
gh_json() {
  env CLICOLOR=0 CLICOLOR_FORCE=0 GH_FORCE_TTY=0 GH_PAGER=cat gh "$@" | sanitize
}

open_prs_json="$(gh_json pr list -R "$repo" --state open --limit 100 --json number,title,headRefName,baseRefName,headRefOid,mergeStateStatus,mergeable,isDraft,url)"
runs_json="$(gh_json run list -R "$repo" --branch "$branch" --limit 30 --json databaseId,workflowName,status,conclusion,headSha,headBranch,createdAt,updatedAt,url)"

open_pr_count="$(jq 'length' <<<"$open_prs_json")"
failed_run_count="$(jq '[.[] | select(.conclusion == "failure" or .conclusion == "cancelled" or .conclusion == "timed_out")] | length' <<<"$runs_json")"
pending_run_count="$(jq '[.[] | select(.status == "queued" or .status == "in_progress")] | length' <<<"$runs_json")"
conflicting_pr_count="$(jq '[.[] | select(.mergeable == "CONFLICTING" or .mergeStateStatus == "DIRTY")] | length' <<<"$open_prs_json")"

if [ "$completion_status" = "complete" ]; then
  failure_category="cycle_limit_reached"
  remaining_blocker="The configured 2,400-cycle continuation limit has been reached."
  next_action="Perform periodic health verification only; do not invent changes."
elif [ "$failed_run_count" -gt 0 ]; then
  failure_category="github_actions_failure"
  remaining_blocker="Recent GitHub Actions runs contain failed, cancelled, or timed-out conclusions."
  next_action="Inspect the newest failed run, classify source versus external cause, and open a reviewable fix only when evidence supports it."
elif [ "$conflicting_pr_count" -gt 0 ]; then
  failure_category="branch_conflict"
  remaining_blocker="One or more open pull requests are conflicting or dirty against their base."
  next_action="Refresh one eligible branch at a time with a lease-guarded rebase and local validation."
elif [ "$pending_run_count" -gt 0 ]; then
  failure_category="pending_remote_ci"
  remaining_blocker="GitHub Actions has queued or in-progress runs that require monitoring."
  next_action="Monitor pending runs and inspect completed failures before changing source."
else
  failure_category="none"
  remaining_blocker="No failure or conflict was detected in the sampled state."
  next_action="Run the next bounded health audit and avoid unnecessary changes."
fi

state_file="$out_dir/hourly-continuation-state.json"
report_file="$out_dir/hourly-continuation-report.md"
jq -n \
  --arg timestamp "$now" \
  --arg repository "$repo" \
  --arg branch "$branch" \
  --arg sha "$sha" \
  --argjson execution_number "$execution_number" \
  --argjson cycle_limit "$cycle_limit" \
  --arg completion_status "$completion_status" \
  --arg failure_category "$failure_category" \
  --arg remaining_blocker "$remaining_blocker" \
  --arg next_action "$next_action" \
  --argjson open_pr_count "$open_pr_count" \
  --argjson failed_run_count "$failed_run_count" \
  --argjson pending_run_count "$pending_run_count" \
  --argjson conflicting_pr_count "$conflicting_pr_count" \
  --argjson open_prs "$open_prs_json" \
  --argjson recent_runs "$runs_json" \
  '{execution_number:$execution_number,cycle_limit:$cycle_limit,timestamp:$timestamp,repository:$repository,branch:$branch,head:$sha,status:$completion_status,failure_category:$failure_category,remaining_blocker:$remaining_blocker,next_action:$next_action,summary:{open_pr_count:$open_pr_count,failed_run_count:$failed_run_count,pending_run_count:$pending_run_count,conflicting_pr_count:$conflicting_pr_count},open_prs:$open_prs,recent_runs:$recent_runs,policy:{read_only_audit:true,no_merge:true,no_deploy:true,no_force_push:true,secrets_recorded:false}}' \
  > "$state_file"

persisted="not_requested"
if [ "${PERSIST_STATE:-0}" = "1" ] && [ "$completion_status" != "complete" ]; then
  compact_state="$(jq -c '{execution_number,cycle_limit,timestamp,repository,branch,head,status,failure_category,remaining_blocker,next_action,summary}' "$state_file")"
  if gh api --method PUT "repos/$repo/actions/variables/M365_HOURLY_STATE" \
      -H 'Accept: application/vnd.github+json' \
      -f "name=M365_HOURLY_STATE" -f "value=$compact_state" >/dev/null 2>&1 || \
     gh api --method POST "repos/$repo/actions/variables" \
      -H 'Accept: application/vnd.github+json' \
      -f "name=M365_HOURLY_STATE" -f "value=$compact_state" >/dev/null 2>&1; then
    persisted="repository_variable"
  else
    persisted="artifact_only_persistence_failed"
  fi
fi
jq --arg persisted "$persisted" '. + {state_persistence:$persisted}' "$state_file" > "$state_file.tmp"
mv "$state_file.tmp" "$state_file"

{
  echo "# Hourly Engineering Continuation"
  echo
  echo "- **Execution:** $execution_number / $cycle_limit"
  echo "- **Timestamp (UTC):** $now"
  echo "- **Repository:** [$repo](https://github.com/$repo)"
  echo "- **Branch:** \`$branch\`"
  echo "- **Audited commit:** \`$sha\`"
  echo "- **State persistence:** $persisted"
  echo
  echo "> This continuation is bounded and read-only with respect to repository history: it does not merge, deploy, force-push, bypass authentication, or record secrets. Source repairs require a separate reviewable branch and pull request."
  echo
  echo "## Current classification"
  echo
  echo "| Field | Value |"
  echo "|---|---|"
  echo "| Status | $completion_status |"
  echo "| Failure category | $failure_category |"
  echo "| Open PRs sampled | $open_pr_count |"
  echo "| Failed/cancelled/timed-out runs sampled | $failed_run_count |"
  echo "| Pending runs sampled | $pending_run_count |"
  echo "| Conflicting PRs sampled | $conflicting_pr_count |"
  echo "| Remaining blocker | $remaining_blocker |"
  echo "| Next action | $next_action |"
  echo
  echo "## Open pull requests"
  echo
  echo "| PR | Branch | Base | Merge state | Mergeable | Draft | URL |"
  echo "|---:|---|---|---|---|---|---|"
  jq -r '.[] | "| #\(.number) | \(.headRefName) | \(.baseRefName) | \(.mergeStateStatus) | \(.mergeable) | \(.isDraft) | [view](\(.url)) |"' <<<"$open_prs_json"
  echo
  echo "## Recent workflow runs"
  echo
  echo "| Run | Workflow | Status | Conclusion | SHA | Created | URL |"
  echo "|---:|---|---|---|---|---|---|"
  jq -r '.[] | "| \(.databaseId) | \(.workflowName) | \(.status) | \(.conclusion // "") | \(.headSha[0:12]) | \(.createdAt) | [view](\(.url)) |"' <<<"$runs_json"
} > "$report_file"

cat "$state_file"
