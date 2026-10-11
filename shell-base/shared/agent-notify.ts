// Hunk extension, installed as ~/.config/hunk/extensions/agent-notify.ts by
// tools/hunk-config.dockerfile: tells you when the agent comments or replies in a live review.
//   agent runs `hunk session comment add --reply-to user:… --summary "Fixed"`
//   => toast "Agent replied: Fixed" at the bottom of Hunk, plus a terminal bell, which tmux shows
//      as ✓ on the window when Hunk isn't in the active one.
// note_changed fires for saved notes only (no drafts); the user's own notes have source "user".
export default function (hunk: any) {
  hunk.on("note_changed", ({ kind, note }: any, ctx: any) => {
    if (kind !== "created" || !note || note.source === "user") return;
    const summary = String(note.summary ?? "").split("\n")[0].slice(0, 80);
    ctx.notify(`Agent ${note.parentId ? "replied" : "commented"}: ${summary}`);
    process.stdout.write("\x07");
  });
}
