# Verify PAZRAS

Run the system's verification suite from `06_SYSTEM/CLAUDE.md` §Verifying a
change. Do not change anything — this is read-only verification. Report each
result; a green systemd timer means the timer fired, not that the service
succeeded, so check `systemctl --user status` for anything suspicious.

```bash
familiar structure validate
familiar structure generate --check
familiar structure status
engine/boundaries/compile.py --check
familiar checks selftest --signals
```

If any command exits non-zero or reports drift (structure `--check` = 3),
state exactly which and stop for the user rather than fixing it unprompted.
