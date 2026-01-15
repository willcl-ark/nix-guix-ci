set shell := ["bash", "-uc"]

default_host := 'guix-ci'

[private]
default:
    just --list

# Build configuration without deploying
[group('test')]
build type=default_host:
    nixos-rebuild build --flake .#{{type}} --show-trace

# Build VM for testing
[group('test')]
build-vm type=default_host:
    nixos-rebuild build-vm --flake .#{{type}} --show-trace

# Show what would change without building
[group('test')]
dry-run type=default_host:
    nixos-rebuild dry-run --flake .#{{type}} --show-trace

# Deploy configuration to a machine
[group('live')]
deploy type=default_host host=default_host:
    nix-shell -p nixos-anywhere --command "nixos-anywhere --flake .#{{type}} --target-host {{host}}"

# Copy flake to remote for local building
[group('live')]
sync host=default_host:
    rsync -av --exclude=result* . {{host}}:/etc/nixos-config/
    ssh {{host}} "chown -R root:root /etc/nixos-config"

# Rebuild configuration on remote machine
[group('live')]
rebuild type=default_host host=default_host:
    nixos-rebuild switch --flake .#{{type}} --target-host {{host}}

# Sync and rebuild on remote machine
[group('live')]
sync-rebuild type=default_host host=default_host:
    rsync -av --exclude=result* . {{host}}:/etc/nixos-config/
    ssh {{host}} "chown -R root:root /etc/nixos-config && nixos-rebuild switch --flake /etc/nixos-config#{{type}}"

# Follow CI logs
[group('monitor')]
logs host=default_host:
    ssh {{host}} "journalctl -u bitcoin-ci -f"

# Check CI service status
[group('monitor')]
status host=default_host:
    ssh {{host}} "systemctl status bitcoin-ci"

# Check all bitcoin services status
[group('monitor')]
status-all host=default_host:
    ssh {{host}} "systemctl status bitcoin-*"
