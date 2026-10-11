---
name: hunk-diff
description: >
  Review changes with Hunk, the terminal diff viewer. Use when asked to review a diff, a branch
  or pending changes with hunk, or to answer the user's notes and replies in a Hunk review.
---

Load the Hunk skill and use it for this review. Run `hunk skill path` to get the skill path.

## Answer the user's notes while the review is open

The user replies to your comments in Hunk (`R` on a comment) or adds their own notes. Hunk does
not notify you of these, so after posting your comments, watch for them yourself:

1. Start a background watch with the Monitor tool (timeout 30 minutes, the maximum), description
   "new Hunk notes from the user", using the script below. It polls the live session every 3
   seconds, stays silent while nothing changes, and prints one JSON line per new or edited user
   note. Run it from the repo the review belongs to.
2. When a note arrives, read it and answer in its thread:
   `hunk session comment add --repo . --reply-to <note id> --summary "..."`. A reply inherits the
   parent's anchor, so do not start a new root comment for it. If the note asks for a code change,
   make it, then say so in the reply.
3. When the watch expires, start it again, until the user says the review is done or the script
   exits because the Hunk window was closed. Do not poll with `/loop` instead: that runs a full
   turn every minute even when nothing changed.

```bash
# Prints each new or edited user note in the live Hunk session as one JSON line, e.g.
#   {"id":"user:5f2c…","parentId":"…","summary":"Why not reuse the helper here?",…}
# Exits with a message after 3 failed polls in a row (window closed, daemon gone).
list() { hunk session comment list --repo . --type user --json 2>&1; }
notes() { jq -c '.comments[]?' <<<"$1" | sort; }
out=$(list) || { echo "hunk session unavailable: $out"; exit 1; }
prev=$(notes "$out"); fails=0
while true; do
  sleep 3
  if out=$(list); then
    fails=0
    cur=$(notes "$out")
    comm -13 <(printf '%s\n' "$prev") <(printf '%s\n' "$cur") | grep -v '^$'
    prev=$cur
  else
    fails=$((fails + 1))
    [ "$fails" -lt 3 ] || { echo "hunk session unavailable: $out"; exit 1; }
  fi
done
```

Notes that already exist when the watch starts are not printed; check them once with
`hunk session comment list --repo . --type user` before starting the watch.
