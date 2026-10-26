# Compare the live website with a Windows backup

This temporarily makes cPanel Deploy HEAD Commit run a read-only inventory of the live website. It does not publish the repository or rebuild the preview.

1. Merge the pull request that adds this task into `main`.
2. In Bluehost Git Version Control, open `mmecglobal-website`, confirm `main`, and click **Update from Remote**. Confirm `.cpanel.yml` calls `deployment/live-manifest.sh`.
3. Click **Deploy HEAD Commit** and wait for completion.
4. In File Manager, open `/home1/mdhiglob/deployment-reports/mmecglobal`.
5. Download the newest `MMEC-live-manifest-*.csv` and provide it together with `MMEC-local-manifest.csv` for comparison.

The scan includes hidden files and writes only relative path, byte count and SHA-256, with the same column names as the PowerShell inventory. File contents are not included. Keep the generated report private; do not commit it. Report files are outside `public_html` and created with private permissions.

The source is `/home1/mdhiglob/public_html/mmecglobal`. All regular files are scanned without exclusions. The task stops instead of publishing a complete CSV if it encounters symbolic links, read errors, changes to a file while hashing it, or an added/removed path during scanning. Avoid concurrent uploads. This is a sequential scan, not an atomic filesystem snapshot; a file edited after its individual scan can still require a rerun.

If cPanel reports a failed task, inspect the deployment error rather than uploading an earlier CSV. No partial CSV is published. Run again after resolving the error.

PR #2 configures a different deployment task. Leave it unmerged until this comparison is complete; merging it can conflict with or replace `.cpanel.yml`. Future deployment changes must deliberately select the desired task.
