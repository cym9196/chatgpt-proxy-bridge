# Changelog

## 1.0.0 — 2026-10-26

- First public version, based on a user-confirmed explicit-proxy workaround for repeated ChatGPT desktop reconnects.
- Windows installer with local HTTP/mixed proxy detection, explicit port override and desktop shortcut.
- Per-child-process proxy environment and Chromium proxy argument; no persistent Windows changes.
- App package discovery on every launch; optional custom executable path.
- Non-launching preflight, optional anonymous HTTP diagnostics and conservative uninstallation.
- Chinese and English documentation plus repository instructions for local AI-assisted setup.
- Windows PowerShell 5.1 and PowerShell 7 lifecycle checks and Windows CI.

The original workaround was confirmed by one user. The generalized installer has automated checks; compatibility with every app version or network is not claimed.
