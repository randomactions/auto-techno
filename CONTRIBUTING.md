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
8. Review the semantic codebase map and update its manifest when ownership,
   files, dependencies, flows, boundaries, contracts, or test coverage move.
9. Run:

   ```sh
   python3 scripts/codebase_map.py check
   swift test
   swift build -c release --product AutoTechno
   ```

10. Open a pull request using the repository template. Include exact revision and
   policy provenance, reason-coded automated quality evidence, determinism and
   real-time validation, and the duplicate path avoided or removed.

For musical, evaluator, controller, or render changes, read `AGENTS.md`,
`docs/PRODUCT.md`, `docs/SOUND_QUALITY.md`, and the relevant project skill under
`.agents/skills/`.

### Semantic codebase map

[`docs/CODEBASE_MAP.md`](docs/CODEBASE_MAP.md) describes current implemented
ownership, runtime flows, execution boundaries, sources, stable top-level
symbols, contracts, and tests. Future architecture remains in the roadmap and
normative contracts. Edit only `docs/codebase-map.json`, then refresh and check
the generated map:

```sh
python3 scripts/codebase_map.py generate
python3 scripts/codebase_map.py check
```

The check requires a matching Swift/Xcode toolchain and rejects structural
drift. A change that preserves the map's navigation semantics may omit a map
edit, but its pull request must state why. If the map conflicts with code,
`Package.swift`, or a canonical contract, repair the map in the same change.

## Review and licensing

Maintainers may request smaller scope, stronger automated evidence, clearer
architectural ownership, bounded-controller tests, or additional real-time
safety validation. Submission of a contribution means it is offered under the
repository's Apache License 2.0, consistent with section 5 of that license.
