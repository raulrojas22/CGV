# CGeV User Manual publishing

The manual has one stable public address:

```text
/docs/CGeV_User_Manual.pdf
```

CGeV Web and CGeV Desktop both use this address. In the hosted application it is
served by Oracle from the Shiny `www` directory. In CGeV Desktop the same file is
bundled with the local application, so the manual remains available offline.

The former `/docs/CGV_User_Manual.pdf` address remains an exact compatibility
alias for installations and bookmarks created before the visible identity change.

## Publish a revised edition

1. Update `CGeV_User_Manual_Source.md` and the required screenshots.
2. Update the version and revision fields in `manual_config.json`.
3. Run:

   ```text
   python3 docs/user_manual/generate_cgv_user_manual.py
   ```

The generator creates:

- a versioned authoring output in `output/pdf`;
- the stable current edition at `www/docs/CGeV_User_Manual.pdf`;
- the legacy compatibility alias at `www/docs/CGV_User_Manual.pdf`;
- a versioned public archive in `www/docs/archive`;
- `www/docs/manual.json`, used by the Home page to display the current edition.

The links in Home, CGeV Guide, and Feedback do not need to be edited when the
manual version changes.
