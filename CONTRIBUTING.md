# Contributing to Auto Techno

Auto Techno welcomes human listening feedback, bug reports, and focused pull requests. The project is a standalone macOS instrument: contributions must preserve deterministic musical decisions, smooth real-time playback, and the one-button product direction.

## Before opening an issue

- Search existing issues first.
- Do not post credentials, private paths, personal contact information, crash reports containing usernames, or other sensitive data.
- Use the musical-feedback template for subjective listening observations and include a deterministic seed when possible.
- Report security vulnerabilities privately through [GitHub Security Advisories](https://github.com/randomactions/auto-techno/security/advisories/new).

## Proposing code

1. Fork the repository and create a focused branch.
2. Configure Git with a public identity. GitHub's no-reply email is recommended; do not use an email address you do not want published in commit metadata.
3. Keep core musical decisions deterministic: the same seed and inputs must produce the same plan.
4. Keep rendering out of the music-decision core.
5. Never allocate, lock, log, perform file or network I/O, or invoke UI work from a real-time audio callback.
6. Keep generated listening WAVs local. Do not add build products, credentials, machine-specific paths, or personal data.
7. Run:

   ```sh
   swift test
   swift build -c release --product AutoTechno
   ```

8. Open a pull request using the repository template. Describe the audible or behavioral reason for the change and the validation performed.

For taste or rendering changes, read `AGENTS.md`, `docs/PRODUCT.md`, and the relevant project skill under `.agents/skills/`.

## Review and licensing

Maintainers may ask for smaller scope, deterministic evidence, fixed-seed listening notes, or real-time safety validation. Submission of a contribution means it is offered under the repository's Apache License 2.0, consistent with section 5 of that license.
