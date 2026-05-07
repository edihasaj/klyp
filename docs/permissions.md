# Permissions

Klyp uses two macOS facilities. Neither is requested at launch — they prompt
contextually the first time they're needed.

## Accessibility

**When**: the first time you click an item in Klyp's popover (or hit Enter to
paste).

**Why**: Klyp synthesizes a `⌘V` keystroke into the previously-active app.
That requires Accessibility permission.

**Where to grant**: System Settings → Privacy & Security → Accessibility →
toggle Klyp on. macOS may show the prompt automatically; if not, just open the
panel and add the app.

> Until granted, Klyp still copies the item back to the system clipboard, so
> you can press `⌘V` yourself.

## Login Items

**When**: you toggle "Launch at login" in Klyp's settings.

**Why**: registers Klyp with `SMAppService.mainApp`, which adds it to the
user's Login Items.

**Where to revoke**: System Settings → General → Login Items.

---

Klyp does **not** use:

- Sandbox (it's a non-sandboxed AppKit app).
- Network — no telemetry, no updates, no analytics.
- Full Disk Access — it only reads the system pasteboard.
- Automation/Apple Events — Klyp does not script other apps.
