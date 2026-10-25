#!/usr/bin/env bash
set -euo pipefail

# Prepares a chart release on a branch: appVersion becomes the agent's latest
# published release, the chart version is bumped, and the docs and schema are
# regenerated. Merging the branch's pull request publishes the chart.
#
# usage: release.sh <chart>
#   BUMP=patch|minor|major overrides the bump, which is minor when the agent's
#   minor or major moved and patch otherwise.

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

chart="${1:?usage: release.sh <chart>}"
chart_yaml="charts/$chart/Chart.yaml"
[ -f "$chart_yaml" ] || { echo "error: no chart $chart" >&2; exit 1; }

branch=$(git rev-parse --abbrev-ref HEAD)
[ "$branch" = master ] || { echo "error: release from master, not $branch" >&2; exit 1; }
[ -z "$(git status --porcelain --untracked-files=no)" ] || {
    echo "error: commit or stash your changes first" >&2; exit 1; }
git fetch --quiet origin master
[ "$(git rev-parse HEAD)" = "$(git rev-parse origin/master)" ] || {
    echo "error: HEAD is not origin/master; pull or push first" >&2; exit 1; }

# The chart is named after the agent's repository.
app_new=$(gh release view --repo "admiral-io/$chart" --json tagName --jq .tagName)
app_old=$(sed -n 's/^appVersion: *//p' "$chart_yaml")
chart_old=$(sed -n 's/^version: *//p' "$chart_yaml")

if [ "$(printf '%s\n%s\n' "${app_old#v}" "${app_new#v}" | sort -V | tail -1)" != "${app_new#v}" ]; then
    echo "error: the latest $chart release, $app_new, is older than appVersion $app_old" >&2
    exit 1
fi

IFS=. read -r app_old_major app_old_minor _ <<<"${app_old#v}"
IFS=. read -r app_new_major app_new_minor _ <<<"${app_new#v}"
if [ -z "${BUMP:-}" ]; then
    BUMP="patch"
    if [ "$app_old_major.$app_old_minor" != "$app_new_major.$app_new_minor" ]; then
        BUMP="minor"
    fi
fi

IFS=. read -r major minor patch <<<"$chart_old"
case "$BUMP" in
    patch) chart_new="$major.$minor.$((patch + 1))" ;;
    minor) chart_new="$major.$((minor + 1)).0" ;;
    major) chart_new="$((major + 1)).0.0" ;;
    *) echo "error: BUMP is patch, minor or major, not $BUMP" >&2; exit 1 ;;
esac

echo "Chart:      $chart"
echo "Version:    $chart_old -> $chart_new ($BUMP)"
echo "appVersion: $app_old -> $app_new"
echo ""
read -r -p "Proceed? [y/N] " confirm
[ "$confirm" = y ] || exit 1

git switch --quiet -c "release/$chart-$chart_new"
sed -i.bak -e "s/^version: .*/version: $chart_new/" -e "s/^appVersion: .*/appVersion: $app_new/" "$chart_yaml"
rm "$chart_yaml.bak"
./scripts/helm-docs.sh >/dev/null 2>&1
./scripts/gen-schema.sh >/dev/null 2>&1
git add -A charts
git commit --quiet -m "chore(${chart#admiral-}): chart $chart_new with agent $app_new"

echo ""
echo "Committed on release/$chart-$chart_new. Update the artifacthub.io/changes"
echo "annotation in $chart_yaml, then push the branch and open a pull request."
