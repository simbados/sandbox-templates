// Hunk extension, installed as ~/.config/hunk/extensions/agent-notify.ts by
// tools/hunk-config.dockerfile: tells you when the agent comments or replies in a live review,
// and jumps to its latest note.
//   agent runs `hunk session comment add --reply-to user:… --summary "Fixed"`
//   => toast "Agent replied: Fixed" at the bottom of Hunk, plus a terminal bell, which tmux shows
//      as ✓ on the window when Hunk isn't in the active one; L then jumps to that reply.
// note_changed fires for saved notes only (no drafts); the user's own notes have source "user".
export default function (hunk: any) {
  hunk.on("note_changed", ({ kind, note }: any, ctx: any) => {
    if (kind !== "created" || !note || note.source === "user") return;
    const summary = String(note.summary ?? "").split("\n")[0].slice(0, 80);
    ctx.notify(`Agent ${note.parentId ? "replied" : "commented"}: ${summary}`);
    process.stdout.write("\x07");
  });

  // L (also in the Extensions menu, rebindable as agent-notify.last-agent-note in [keybindings]):
  // reveals the line of the newest agent note. A reply carries its thread's anchor, e.g.
  //   { preferred: { side: "new", line: 5 }, newRange: [5, 5], intersectingHunkIndices: [0] }
  hunk.registerCommand(
    { id: "last-agent-note", title: "Jump to the agent's last note", key: "L" },
    (ctx: any) => {
      const snapshot = ctx.review.snapshot();
      let last: any;
      for (const note of snapshot?.notes ?? []) {
        if (note.source === "user") continue;
        if (!last || String(note.createdAt ?? "") >= String(last.createdAt ?? "")) last = note;
      }
      if (!last) return ctx.notify("No agent notes in this review yet");
      const file = snapshot.files.find((f: any) => f.fileKey === last.fileKey);
      if (!file) return ctx.notify("The agent's last note is on a file outside this review", "warning");
      const { preferred, newRange, oldRange, ownerHunkIndex, intersectingHunkIndices } = last.anchor;
      const target =
        preferred ??
        (newRange ? { side: "new", line: newRange[0] } : oldRange ? { side: "old", line: oldRange[0] } : undefined);
      if (target) ctx.navigation.revealLine(file.runtimeId, target.side, target.line);
      else ctx.navigation.selectHunk(file.runtimeId, ownerHunkIndex ?? intersectingHunkIndices?.[0] ?? 0);
    },
  );
}
