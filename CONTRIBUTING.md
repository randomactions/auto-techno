# Contributing to Auto Techno

Auto Techno welcomes bug reports, optional concrete listening observations, and
focused pull requests. Contributions must preserve the one-button product, the
single autonomous runtime, deterministic continuation, and safe real-time audio.

## Before opening an issue

- Search existing issues first.
- Do not post credentials, private paths, personal contact information, raw crash
  reports containing usernames, copyrighted reference audio, or other sensitive
  data.
- Use the sound-quality feedback template for an audible concern. Name the app
  revision, quality-policy version when known, and structural checkpoint; a
  private fixture identifier is developer evidence, not a product seed.
- Human feedback is optional hypothesis input. It does not approve or reject an
  engine revision.
- Report security vulnerabilities privately through
  [GitHub Security Advisories](https://github.com/randomactions/auto-techno/security/advisories/new).

## Proposing code

1. Fork the repository and create a focused branch.
2. Configure Git with a public identity. GitHub's no-reply email is recommended;
   do not publish an email address you want kept private.
3. Identify the existing canonical owner and state the change extends. Do not add
   another runtime, renderer, profile, or user-facing engine switch.
4. For a musical change, document the path from resolved score or renderer to
   PCM, quality evidence, bounded future adaptation, continuation, and fallback.
5. Keep musical decisions in `AutoTechnoCore`, rendering and signal evidence in
   `AutoTechnoDSP`, and transport/presentation in `AutoTechnoApp`.
6. Never allocate, lock, wait, analyze, log, perform file/network I/O, access a
   microphone, or invoke UI work from a real-time audio callback.
7. Keep generated WAVs, stems, reference recordings, build products, credentials,
   machine-specific paths, and personal data out of commits.
8. Run:

   ```sh
   swift test
   swift build -c release --product AutoTechno
   ```

9. Open a pull request using the repository template. Include exact revision and
   policy provenance, reason-coded automated quality evidence, determinism and
   real-time validation, and the duplicate path avoided or removed.

For musical, evaluator, controller, or render changes, read `AGENTS.md`,
`docs/PRODUCT.md`, `docs/SOUND_QUALITY.md`, and the relevant project skill under
`.agents/skills/`.

## Review and licensing

Maintainers may request smaller scope, stronger automated evidence, clearer
architectural ownership, bounded-controller tests, or additional real-time
safety validation. Submission of a contribution means it is offered under the
repository's Apache License 2.0, consistent with section 5 of that license.
