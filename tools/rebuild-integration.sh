#!/bin/sh
# Rebuilds the integration branch from scratch:
#   upstream/main + every branch listed in integration.txt (in order)
#   + commits whose message starts with "integration:" (fixes for joints between branches).
#
# Usage:
#   tools/rebuild-integration.sh                 start a rebuild into branch integration-new
#   tools/rebuild-integration.sh --continue      continue after resolving a conflict manually
#
# The list and the "integration:" commits are taken from the current integration branch.
# Conflicts already resolved before are replayed by git rerere (git config rerere.enabled true).
# Nothing is pushed. When done:
#   git branch -f integration integration-new && git push --force-with-lease origin integration
set -e

OLD=integration
NEW=integration-new
STATE=.git/rebuild-integration-next

# local branch if it is newer than origin, otherwise origin/<branch>; full remote refs are used as is
resolve_ref() {
  b=$1
  if git show-ref -q --verify "refs/remotes/$b"; then echo "$b"; return; fi
  l="refs/heads/$b"; r="refs/remotes/origin/$b"
  if git show-ref -q --verify "$l" && git show-ref -q --verify "$r"; then
    if git merge-base --is-ancestor "$l" "$r"; then echo "origin/$b"; else echo "$b"; fi
  elif git show-ref -q --verify "$l"; then echo "$b"
  else echo "origin/$b"; fi
}

if [ "$1" = "--continue" ]; then
  START=$(cat "$STATE")
else
  git fetch --all --prune
  git switch -C "$NEW" upstream/main
  git branch --unset-upstream 2>/dev/null || true
  START=1
fi

LIST=$(git show "$OLD:integration.txt")
i=0
for b in $LIST; do
  i=$((i + 1))
  [ "$i" -lt "$START" ] && continue
  ref=$(resolve_ref "$b")
  echo "== merging $ref"
  if ! git merge --no-edit "$ref"; then
    files=$(git diff --name-only --diff-filter=U)
    if [ -n "$files" ] && grep -l '^<<<<<<<\|^>>>>>>>' $files >/dev/null 2>&1; then
      echo $((i + 1)) > "$STATE"
      echo "Resolve conflicts, commit, then run: tools/rebuild-integration.sh --continue"
      exit 1
    fi
    git add $files
    git commit --no-edit
  fi
done

# re-apply joint fixes from the old integration branch
for c in $(git rev-list --reverse --grep '^integration:' "upstream/main..$OLD"); do
  echo "== applying $(git log -1 --format='%h %s' "$c")"
  git cherry-pick "$c"
done

rm -f "$STATE"
echo "Done: $NEW is ready. Compare with: git diff $OLD $NEW"
