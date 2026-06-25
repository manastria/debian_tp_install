## Sudo Privilege Management in Scripts

Every script in `.local/bin/` must follow one of three patterns depending on its needs. Do not mix patterns or invent variants.

### Tier 1 — Script requires root for all (or most) operations

Use auto-relaunch **without** `-E`. The user can call the script without `sudo`; the script re-executes itself with the resolved absolute path.

```bash
if [ "$(id -u)" -ne 0 ]; then
    exec sudo "$(readlink -f "$0")" "$@"
fi
```

- `readlink -f "$0"` resolves the absolute path regardless of how the script was called, which is required because `~/.local/bin` is not in sudo's `secure_path`.
- No `-E` flag: sudo starts with its own secure environment. Never use `sudo -E` as it passes `LD_PRELOAD`, `PATH`, `PYTHONPATH`, etc. from the user environment to root.
- Applies to: scripts that run `apt`, write to `/etc/`, manage systemd services, or otherwise operate exclusively at system level (`install-paquets.sh`, `update-ubuntu.sh`, `change-hostname.sh`, etc.).

### Tier 2 — Script mixes user-level and root operations

The script runs as the current user. Call `sudo -v` once at the start to cache credentials and avoid mid-script password prompts. Use `sudo` inline only on the commands that require it.

```bash
# Préchauffage : demande le mot de passe une seule fois en début de script
echo "INFO: Des droits administrateur sont nécessaires pour certaines étapes."
sudo -v
```

For scripts that run longer than ~5 minutes, add a keep-alive to prevent the sudo token from expiring:

```bash
sudo -v
( while true; do sudo -n true; sleep 50; done ) &
_SUDO_PID=$!
trap 'kill "$_SUDO_PID" 2>/dev/null' EXIT INT TERM
```

- Applies to: scripts that perform both user-space operations (downloads, config in `~/.config`, etc.) and occasional system operations (`install-docker.sh`, `install-ghostty.sh`, etc.).

### Tier 3 — Script must never run as root

Scripts that write to `~/.local`, configure the user shell, or manage user-owned files must reject root execution, as running them as root silently creates files owned by root in the user's home directory.

```bash
if [ "$(id -u)" -eq 0 ]; then
    echo "ERREUR : Ce script ne doit pas être lancé en root." >&2
    echo "Relancez sans sudo, en tant qu'utilisateur normal." >&2
    exit 1
fi
```

- Applies to: scripts that install to `~/.local/bin`, configure zsh/bash, or manage user dotfiles (`install-atuin.sh`, `install-fzf.sh`, `install-starship.sh`, `install-zoxide.sh`, etc.).

### Decision guide

```text
Le script a-t-il besoin de sudo ?
│
├── Non ──────────────────────── Rien à ajouter
│
├── Oui, opérations exclusivement
│   système (apt, /etc/, services) ── Tier 1 : auto-relaunch sans -E
│
├── Oui, mix user + système ──────── Tier 2 : sudo -v warmup + sudo inline
│
└── Non, et doit rester user ─────── Tier 3 : reverse-check (refuser root)
```

### Forbidden patterns

- `exec sudo -E "$0" "$@"` — propagates user environment to root (security risk).
- `if [ "$EUID" -ne 0 ]; then echo "Lancez avec sudo"; exit 1; fi` — forces the user to type the full path since `~/.local/bin` is not in sudo's `secure_path`.
- Asking for the password multiple times within the same script (use `sudo -v` warmup instead).
