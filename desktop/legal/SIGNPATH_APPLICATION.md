# SignPath Foundation application

This document is the prepared application packet for CGV Desktop. Do not submit it until every readiness item below is public and verifiable.

## Readiness gate

- [x] The project uses the OSI-approved MIT License.
- [x] CGV Desktop has a public privacy policy, third-party notices, and code signing policy prepared in the source tree.
- [x] Windows builds run on GitHub-hosted runners and include automated runtime, installer, localhost, shutdown, and uninstall tests.
- [x] Windows release signing requires a tagged source revision and manual SignPath approval.
- [x] The download experience documents CGV Desktop features and supported platforms.
- [ ] Publish the Desktop source, policies, and GitHub Actions workflows in `raulrojas22/CGV`.
- [ ] Publish the download page containing the code-signing-policy disclosure.
- [ ] Publish at least one CGV Desktop release in the form offered to users. SignPath Foundation currently requires the project to be released before applying.
- [ ] Enable multi-factor authentication for the GitHub and SignPath accounts used by the maintainer/approver.
- [ ] Confirm the exact Windows installer metadata from a real GitHub Actions build against `desktop/signing/signpath-windows-installer.xml`.

## Prepared form values

- **Project Name:** CGV — Comparative Gene Viewer
- **Repository URL:** https://github.com/raulrojas22/CGV
- **Homepage URL:** https://cgv.mobilomics.org
- **Download URL:** https://github.com/raulrojas22/CGV-Desktop-Releases
- **Privacy Policy URL:** https://github.com/raulrojas22/CGV-Desktop-Releases/blob/master/PRIVACY.md
- **Wikipedia URL:** leave empty
- **Tagline:** A guided, gene-first workspace for comparing gene structures, transcripts, alignments, and genomic context across species.
- **Description:** Comparative Gene Viewer is an open-source bioinformatics application for interactive gene-structure analysis within and across species. Its web and desktop interfaces combine gene discovery, transcript comparison, cross-species alignments, genomic context, analytics, and publication-ready exports in one guided workspace. CGV Desktop runs the analysis service locally and stores reference datasets and user work on the user's computer.
- **Reputation:** CGV operates as a public web application at https://cgv.mobilomics.org, publishes its MIT-licensed source and versioned releases on GitHub, and provides its curated CGV Desktop organism dataset collection through Zenodo at https://zenodo.org/records/20453645. The project is maintained by Raúl Rojas-Espinoza at Universidad de Talca for research and education in comparative genomics.
- **Maintainer Type:** select the closest available option to individual academic/open-source maintainer.
- **Build System:** GitHub Actions
- **First Name:** Raúl
- **Last Name:** Rojas-Espinoza
- **Email:** enter the maintainer's preferred SignPath account email; do not use a repository secret or a temporary address.
- **Company Name:** Universidad de Talca, if the application is being made in that institutional capacity; otherwise leave empty.
- **Primary Discovery Channel:** choose the option that corresponds to online search or recommendation.
- **Exact source:** OpenAI Codex recommendation while preparing CGV Desktop release signing.

The maintainer must personally review and accept the SignPath Foundation Code of Conduct and personal-data processing checkbox. Marketing communications are optional.

## Values created after acceptance

Configure these in the `raulrojas22/CGV` repository only after SignPath creates the organization and project:

### GitHub secret

- `SIGNPATH_API_TOKEN`: token for a SignPath user with submitter permission.

### GitHub variables

- `SIGNPATH_ORGANIZATION_ID`
- `SIGNPATH_PROJECT_SLUG`
- `SIGNPATH_SIGNING_POLICY_SLUG` — expected production value: `release-signing`
- `SIGNPATH_ARTIFACT_CONFIGURATION_SLUG` — recommended value: `windows-installer-zip`

To create draft releases in the separate download repository, also configure a fine-grained GitHub token as `CGV_DESKTOP_RELEASE_TOKEN`, restricted to `raulrojas22/CGV-Desktop-Releases` with **Contents: read and write**. Never place any token in source files, workflow variables, logs, release notes, or downloadable artifacts.
