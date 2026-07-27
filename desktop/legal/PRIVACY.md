# CGV Desktop privacy policy

CGV Desktop does not require an account and does not collect telemetry, analytics, advertising identifiers, or crash reports. Genomes, annotations, caches, saved sessions, and analysis results are stored locally in the folder selected by the user. The local Shiny server listens only on `127.0.0.1`.

CGV Desktop accesses network services in these cases:

- Direct Windows builds check the configured GitHub release feed for application updates. This can be disabled by starting the app with `CGV_DISABLE_AUTO_UPDATE=1`. Microsoft Store builds rely on Store updates instead.
- The organism catalog retrieves catalog metadata from the configured catalog URL and downloads a dataset only after the user chooses it. Downloads are SHA-256 verified.
- NCBI downloads, external alias resolution, literature links, and other public-resource queries run when the user selects or enables those features. Requests are sent to the service displayed in the interface or configured by the operator.
- Opening an external link delegates that URL to the user's default browser.

These services receive the network information ordinarily required for an HTTPS request, such as the user's IP address and request metadata, and are governed by their own privacy policies. CGV does not send local genome files, saved sessions, or analysis outputs to the project maintainer.

The **Share analysis** action behaves locally in CGV Desktop: it creates a
self-contained read-only HTML report and a reproducibility ZIP through the
operating-system download/save flow. It never creates a public URL or uploads
the report to CGV Web. Private sequences are excluded by default and are added
to the ZIP only when the author explicitly selects that option. Anyone who
receives an exported HTML or ZIP can copy the information it contains, so users
should review the inclusion summary before sharing those files.

Uninstalling CGV Desktop removes the application but intentionally preserves the selected data and cache folder. Users may delete that folder manually at any time. Changing the storage folder does not move or delete existing data.

Questions or privacy reports may be submitted through the repository's GitHub issue tracker.
