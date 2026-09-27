# Contributing to Rxcall

Thanks for your interest. Rxcall is a free, open-source iOS app; contributions of code, documentation, and testing are welcome.

## Ground rules

These are non-negotiable and every PR is checked against them:

- **Free.** No purchases, no paid tiers.
- **No advertising** and no SDKs that monetize.
- **No data collection.** User data stays on the device. Don't add a backend, accounts, sync, analytics, or crash reporting that captures user content.
- **No medical advice.** The app never tells a user to stop, start, or change a medication, and never asserts that something *is* recalled when the match is uncertain.

If a change touches any of these, open an issue to discuss before writing code.

## Workflow

1. Fork or branch from `main`.
2. Make your change. Keep PRs focused.
3. Test at the largest Dynamic Type size and with VoiceOver on. Accessibility is a requirement, not a nice-to-have.
4. Open a pull request. `main` requires one approving review; nobody pushes to it directly.
5. If you made a non-obvious product or architecture decision, add a dated paragraph to `DECISIONS.md`.

## Developer Certificate of Origin

Contributions must be signed off under the [DCO](https://developercertificate.org/). This certifies you wrote the code or have the right to submit it under the project's Apache-2.0 license.

Sign off each commit with the `-s` flag:

```
git commit -s -m "Describe your change"
```

This appends `Signed-off-by: Your Name <you@example.com>` to the commit message. Use a real name and an email associated with your GitHub account.

## Code of conduct

See [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).
