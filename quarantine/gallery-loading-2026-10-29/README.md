# Gallery replaced assets quarantine

Created: 2026-10-29

This folder contains the 103 files replaced by the Gallery loading optimization:

- 102 Gallery thumbnails
- 1 Gallery banner
- Total original size: 30,894,625 bytes

The `replaced-assets/` directory preserves each file's former repository path below the repository root. The replacement WebP files remain under `images/gallery-optimized/`. The exact original-to-replacement mapping, byte sizes and dimensions are recorded in `deployment/gallery-assets.json`.

No root HTML page references these quarantined files. The production, comparison-preview and staging scripts exclude `/quarantine/`, so this archive is retained in GitHub without being copied to the public website directories.

Do not delete this folder until the deployed Gallery has been checked on desktop and mobile, including category filtering and full-size image popups. The popup originals are separate `* 2.jpg` or `* 2.png` files and are not part of this quarantine.

To download an archive, download the `perf/gallery-loading-audit` branch as a ZIP from GitHub; this folder will be included with its original path structure intact.
