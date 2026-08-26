# Omarchy's environment bootstrap — sets OMARCHY_PATH and PATH.
#
# In env.d/ rather than rc.d/ because Omarchy documents it as needed for
# non-interactive shells too (`ssh omarchy some-omarchy-command`), and rc.d/
# runs only after ~/.bashrc's interactive guard.
[ -r /usr/share/omarchy/default/bash/env-bootstrap ] \
    && . /usr/share/omarchy/default/bash/env-bootstrap
