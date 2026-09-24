# Permissions

Klyp uses two macOS facilities. Accessibility is offered at launch when it has
not been granted, because it also provides a fallback for the global shortcut.

## Accessibility

**When**: at launch if access has not been granted. You can also right-click
Klyp's menu bar icon and choose **Enable Accessibility…** to open System Settings.

**Why**: Klyp synthesizes a `⌘V` keystroke into the previously-active app and
uses an event tap when macOS stops delivering its global shortcut through
Carbon. Both need Accessibility permission.

**Where to grant**: System Settings → Privacy & Security → Accessibility →
toggle Klyp on. macOS may show the prompt automatically; if not, just open the
panel and add the app.

If Klyp is already on but the shortcut still does nothing, remove that entry
and add `/Applications/Klyp.app`. A development build can have the same bundle
ID as the installed app but a different code signature, so its grant does not
apply to the installed app.

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
