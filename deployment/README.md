# MMEC website deployment

The current .cpanel.yml builds a separate preview for review. The production website remains unchanged.

After merging the preview PR, open cPanel Git Version Control, confirm the main branch, click Update from Remote, then Deploy HEAD Commit. Follow the private review instructions supplied in the conversation.

The earlier comparison-only script remains available as deployment/preview.sh; the current task runs deployment/stage.sh instead.

Validation: local Bash syntax and isolated fixture checks passed. Hosting execution and browser verification remain pending. Production synchronization is not enabled.
