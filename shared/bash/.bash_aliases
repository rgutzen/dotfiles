# Portable aliases only — every machine gets these.
#
# Machine- or session-specific aliases belong in a fragment under
# ~/.config/bash/rc.d/ instead, so they appear only where they make sense.
# Sourced from 10-shell.sh.

# run local jekyll server instance
alias local-jekyll='bundle exec jekyll serve --config _config.yml --drafts'
