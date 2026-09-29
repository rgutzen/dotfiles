
. "$HOME/.local/share/../bin/env"

export KRB5_CONFIG=~/.krb5-nyu.conf

# Clear AnyConnect's stale global DNS after an unclean VPN disconnect.
alias vpn-clear-dns='sudo systemctl restart systemd-resolved && resolvectl flush-caches'
