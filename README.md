# Bitcoin Guix CI

NixOS configuration for running continuous Guix builds of Bitcoin Core, with results uploaded to CDash.

## Dashboard

Build results are by default uploaded to: https://my.cdash.org/index.php?project=core

## How It Works

This NixOS configuration sets up three systemd services:

1. **bitcoin-sdk-download** - Downloads the macOS SDK required for cross-compilation (runs once)
2. **bitcoin-repo-setup** - Clones the Bitcoin repository and configures remotes (runs once)
3. **bitcoin-ci** - Runs `ctest -S guix.cmake` continuously, rebasing on upstream master before each build

The CI service:
- Fetches from `upstream` (bitcoin/bitcoin)
- Rebases on `upstream/master`
- Runs `contrib/guix/guix-build` for all platforms
- Uploads results to CDash
- Restarts on failure

### Required Bitcoin Commits

This setup requires two commits not yet in upstream bitcoin/bitcoin:

- [CTestConfig.cmake](https://github.com/bitcoin/bitcoin/compare/master...willcl-ark:bitcoin:guix-ci) - CDash configuration
- [guix.cmake](https://github.com/bitcoin/bitcoin/compare/master...willcl-ark:bitcoin:guix-ci) - CTest build script

See the full diff: https://github.com/bitcoin/bitcoin/compare/master...willcl-ark:bitcoin:guix-ci

Currently, the CI clones from `willcl-ark/bitcoin` (branch `guix-ci`) which contains these commits. If the CMakeLists.txt changes are merged upstream, the CI scripts could be moved entirely into this repository.

## Deploying to Your Own Server

### Prerequisites

- A server with SSH access
- Nix with flakes enabled
- `just` command runner (optional, you can run the commands manually)

### Configuration

1. **SSH Keys**: Update `ssh_keys` in `flake.nix` with your public key(s):
   ```nix
   ssh_keys = [
     "ssh-ed25519 AAAA... your-key@example.com"
   ];
   ```

2. **SSH Config**: Add your server to `~/.ssh/config`:
   ```
   Host guix-ci
       HostName <your-server-ip>
       Port 22
       User root
       IdentityFile ~/.ssh/your-key
   ```

3. **Disk Configuration**: Update disk device paths in `hosts/guix-ci/disk-config.nix` to match your server:
   ```nix
   disk.disk1.device = lib.mkDefault "/dev/sda";  # or /dev/nvme0n1, etc.
   disk.disk2.device = lib.mkDefault "/dev/sdb";  # for /data partition
   ```

   Run `lsblk` on the target to identify disk names.

### Initial Deployment

1. Boot your server into a NixOS installer ISO or rescue system
2. Ensure SSH access works: `ssh guix-ci echo "connected"`
3. Deploy:
   ```bash
   just deploy
   ```

This partitions disks and installs NixOS with the full CI configuration.

### Updating an Existing Deployment

Syncing first performs the build on the remote, which saves bandwidth/time.

```bash
just sync-rebuild
```

Or separately:
```bash
just sync      # copy config to remote
just rebuild   # rebuild on remote
```

### Monitoring

```bash
# Follow CI logs
ssh guix-ci "journalctl -u bitcoin-ci -f"

# Check service status
ssh guix-ci "systemctl status bitcoin-ci"

# Check all CI-related services
ssh guix-ci "systemctl status bitcoin-*"
```

## Data Layout

All build data is stored on a dedicated `/data` partition:

```
/data/
├── bitcoin/    # Git repository
├── sdk/        # macOS SDK for cross-compilation
├── sources/    # Guix depends source cache
└── cache/      # Guix built package cache
```

## Environment Variables

The CI service sets these environment variables for the Guix build:

- `SDK_PATH=/data/sdk` - macOS SDK location
- `SOURCES_PATH=/data/sources` - Depends source cache
- `BASE_CACHE=/data/cache` - Built package cache

## Future Plans

If the CTest/CDash integration commits are merged into bitcoin/bitcoin upstream, the `guix.cmake` and `CTestConfig.cmake` files could be maintained in this repository instead, making the setup fully self-contained.

## Available Commands

```bash
just              # List all commands
just build        # Build configuration locally
just build-vm     # Build VM for testing
just dry-run      # Show what would change
just deploy       # Initial deployment to fresh server
just sync         # Copy config to remote
just rebuild      # Rebuild on remote
just sync-rebuild # Sync and rebuild in one step
```
