# Security Policy

## Supported versions

Security fixes are made for the latest release of Claybox, available at
https://oxinstudio.com/apps/claybox/

## Reporting a vulnerability

Please do not open a public issue for security problems.

Report them privately through GitHub: open the **Security** tab of this
repository and choose **Report a vulnerability**. Or email
support@oxinstudio.com with "Claybox security" in the subject.

Please include the Claybox version, your Mac model and macOS version, and
steps to reproduce. You can expect a first reply within a few working days.

## What Claybox does and doesn't do

- Claybox makes no network connections while you play or while it makes HD
  files. The upscaler runs entirely on your Mac.
- It reads only the game files you give it, and writes only to
  `~/Library/Application Support/Claybox/`.
- Release builds are signed with Oxin Studio Inc.'s Developer ID and
  notarized by Apple. Only download Claybox from oxinstudio.com or this
  repository's releases.
