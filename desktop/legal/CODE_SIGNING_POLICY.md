# Code signing policy

CGV Desktop Windows releases are built from the public CGV source repository by the Windows GitHub Actions workflow. A release may be submitted for signing only after its automated runtime, installer, startup, localhost, and process-cleanup checks pass. Signing requests require manual approval and must correspond to a tagged source revision.

Free code signing provided by [SignPath.io](https://about.signpath.io/), certificate by [SignPath Foundation](https://signpath.org/).

## Roles

- Committer and reviewer: [Raul Rojas (`@raulrojas22`)](https://github.com/raulrojas22)
- Signing approver: [Raul Rojas (`@raulrojas22`)](https://github.com/raulrojas22)

Changes from contributors who do not have commit access must be reviewed before merging. Repository access and signing access require multi-factor authentication. The approver verifies the source revision, completed workflow, artifact metadata, and release intent before approving each signing request.

The CGV signing identity is used only for CGV artifacts built from this repository. Bundled third-party binaries retain their upstream identity and are not represented as CGV-authored components.

See the [privacy policy](PRIVACY.md) and [third-party notices](THIRD_PARTY_NOTICES.md).
