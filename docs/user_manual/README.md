# CGV User Manual publishing

The manual has one stable public address:

```text
/docs/CGV_User_Manual.pdf
```

CGV Web and CGV Desktop both use this address. In the hosted application it is
served by Oracle from the Shiny `www` directory. In CGV Desktop the same file is
bundled with the local application, so the manual remains available offline.

## Publish a revised edition

1. Update `CGV_User_Manual_Source.md` and the required screenshots.
2. Update the version and revision fields in `manual_config.json`.
3. Run:

   ```text
   python3 docs/user_manual/generate_cgv_user_manual.py
   ```

The generator creates:

- a versioned authoring output in `output/pdf`;
- the stable current edition at `www/docs/CGV_User_Manual.pdf`;
- a versioned public archive in `www/docs/archive`;
- `www/docs/manual.json`, used by the Home page to display the current edition.

The links in Home, CGV Guide, and Feedback do not need to be edited when the
manual version changes.
