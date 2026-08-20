#!/usr/bin/env bash
set -euo pipefail

repo="${GITHUB_REPOSITORY:-balajirajput96/microsoft-365-agents-toolkit}"
out_dir="${1:-maintenance-report}"
branch="${GITHUB_REF_NAME:-dev}"
mkdir -p "$out_dir"

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI is required" >&2
  exit 2
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required" >&2
  exit 2
fi

now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
sha="$(git rev-parse HEAD 2>/dev/null || echo unknown)"

gh_json() {
  env CLICOLOR=0 CLICOLOR_FORCE=0 GH_FORCE_TTY=0 GH_PAGER=cat gh "$@" | sed -E $'s/\\x1B\\[[0-9;]*[[:alpha:]]//g'
}

prs_json="$(gh_json pr list -R "$repo" --state open --limit 100 --json number,title,headRefName,baseRefName,headRefOid,mergeStateStatus,mergeable,isDraft,url)"
runs_json="$(gh_json run list -R "$repo" --branch "$branch" --limit 30 --json databaseId,workflowName,status,conclusion,headSha,headBranch,createdAt,updatedAt,url)"

jq -n \
  --arg timestamp "$now" \
  --arg repository "$repo" \
  --arg branch "$branch" \
  --arg sha "$sha" \
  --argjson open_prs "$prs_json" \
  --argjson recent_runs "$runs_json" \
  '{timestamp:$timestamp,repository:$repository,branch:$branch,head:$sha,open_prs:$open_prs,recent_runs:$recent_runs,policy:{read_only:true,no_merge:true,no_deploy:true,secrets_recorded:false}}' \
  > "$out_dir/maintenance-state.json"

{
  echo "# Daily GitHub Maintenance Audit"
  echo
  echo "- **Timestamp (UTC):** $now"
  echo "- **Repository:** [$repo](https://github.com/$repo)"
  echo "- **Audited branch:** \`$branch\`"
  echo "- **Audited commit:** \`$sha\`"
  echo
  echo "> This audit is read-only. It does not merge pull requests, push branches, deploy artifacts, or record secrets."
  echo
  echo "## Open pull requests"
  echo
  echo "| PR | Branch | Base | Merge state | Mergeable | Draft | URL |"
  echo "|---:|---|---|---|---|---|---|"
  jq -r '.[] | "| #\(.number) | \(.headRefName) | \(.baseRefName) | \(.mergeStateStatus) | \(.mergeable) | \(.isDraft) | [open](\(.url)) |"' <<< "$prs_json"
  echo
  echo "## Recent workflow runs"
  echo
  echo "| Run | Workflow | Status | Conclusion | SHA | Created | URL |"
  echo "|---:|---|---|---|---|---|---|"
  jq -r '.[] | "| \(.databaseId) | \(.workflowName) | \(.status) | \(.conclusion // "") | \(.headSha[0:12]) | \(.createdAt) | [view](\(.url)) |"' <<< "$runs_json"
  echo
  echo "## Maintenance policy"
  echo
  echo "The audit records repository health for follow-up work. Source repairs require a separate reviewable branch and pull request. External credential, private-repository access, Dependabot-service, runner, or account-authentication failures are reported as blockers rather than bypassed."
} > "$out_dir/maintenance-report.md"

cat "$out_dir/maintenance-state.json"
