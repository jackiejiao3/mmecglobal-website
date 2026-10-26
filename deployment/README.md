# MMEC Bluehost file comparison

This configuration generates a comparison report only. It does not copy, overwrite, delete, or change permissions of live website files.

## Run the comparison
1. Merge this PR into main.
2. Open cPanel > Git Version Control > mmecglobal-website > Manage.
3. Confirm the checked-out branch is main.
4. Open Pull or Deploy and click Update from Remote. Wait for success.
5. Click Deploy HEAD Commit. With this configuration, the button runs only the comparison script.
6. In File Manager, open /home1/mdhiglob/deployment-reports/mmecglobal.
7. Download the newest compare-*.txt file and share it for review.

Source repository: /home1/mdhiglob/repositories/mmecglobal-website
Live website: /home1/mdhiglob/public_html/mmecglobal

The report compares content with rsync checksums. It lists proposed additions, modifications, and deletions. Reading the existing website may take several minutes. A failed or incomplete run is not a complete comparison. If rsync is unavailable, or either expected directory or the source homepage is missing, the script stops.

## Protected and excluded files
Server configuration and certificate validation files are excluded: .well-known directories, .htaccess, .user.ini, php.ini, .env and .env.*, .htpasswd, logs directories and *.log files.

Git metadata, deployment files, editor files and macOS metadata are excluded from proposed publication. Exclusions also protect existing destination copies from proposed deletion. This comparison does not remove any existing public Git metadata.

Other files, including PHP handlers, PDFs and media, are compared. Their proposed changes still need review, especially if clients use external links. No production mirror sync is enabled in this PR.

Reports are written outside both the public website and the Git working tree.

## Initial repository findings
Initial upload: 907 tracked files, 233,649,561 bytes (about 234 MB), excluding Git history.

The homepage's directly declared local paths resolved in the repository. This was a static reference check, not a browser-rendering or email-delivery test.

The previous .cpanel.yml used a placeholder target, copied the entire working directory including .git, and temporarily removed directory traversal permissions with recursive chmod 644.

Missing references on main company pages:
- css/gal.css: contact, modhex, gallery, careers, media.
- js/gal.js: mgbus, mgcorp, mgcert, modhex.
- mgcert.html: images/m-cert07.webp, images/m-cert08.webp, images/m-cert09.webp, docs/asmeu.webp, docs/asmes.webp, docs/asmep.webp.
- Font definitions reference 25 absent .woff2 paths for Roboto, Open Sans and Crete Round. Browsers may use fallback fonts.
Some theme/demo pages have further missing references. Not every missing reference is visually active. Check the live comparison before deleting old assets.

The contact form depends on form-handler.php, class.simple_mail.php and js/custom.js. All three are present; custom.js adds the required action parameter. Actual email delivery remains to be tested on Bluehost. The Start Your Project form reuses the field name "message" across several inputs, which can lose submitted values. This PR does not change form behavior.

## Validation
Bash syntax and an isolated rsync fixture passed: new/changed/deleted detection, exclusion of protected files, omission of unchanged files, no website mutations, and failure if index.html is missing.

Actual Bluehost execution, available rsync version, permissions and full live-file comparison remain pending.

## References
- https://docs.cpanel.net/knowledge-base/web-services/guide-to-git-deployment/
- https://download.samba.org/pub/rsync/rsync.1
