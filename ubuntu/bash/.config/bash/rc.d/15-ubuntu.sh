# Ubuntu/Debian only — stowed when /etc/debian_version exists.
#
# These are the parts of Debian's stock ~/.bashrc that actually do something.
# The rest of that skeleton (debian_chroot, the PS1 block) is dropped: it only
# fed the stock prompt, which starship replaces.

# Debian ships the binary as `lesspipe`; Arch ships `lesspipe.sh`.
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

[ -d /snap/bin ]                                && PATH="$PATH:/snap/bin"
[ -d /home/linuxbrew/.linuxbrew/bin ]           && PATH="$PATH:/home/linuxbrew/.linuxbrew/bin"
[ -d /usr/local/texlive/2022/bin/x86_64-linux ] && PATH="$PATH:/usr/local/texlive/2022/bin/x86_64-linux"
export PATH
