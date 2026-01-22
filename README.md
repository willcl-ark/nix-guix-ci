# Bitcoin Guix CI

NixOS configuration for running continuous Guix builds of Bitcoin Core, with results uploaded to CDash.

## Dashboard

Build results are uploaded to: https://my.cdash.org/index.php?project=core

## Cross-checking guix builds

The GHA workflow in this repo runs periodically and cross-checks guix hashes (via the ctest "notes") from guix builds with matching revisions.

It will open a new issue in this repo if hashes of a revision do not match.

## How It Works

This NixOS configuration sets up three systemd services:

1. **bitcoin-sdk-download** - Downloads the macOS SDK required for cross-compilation (runs once)
2. **bitcoin-repo-setup** - Clones the Bitcoin repository (runs once)
3. **bitcoin-ci** - Runs `ctest -S guix.cmake` continuously, resetting to origin/master before each build

The CI service:
- Fetches and resets to latest `origin/master`
- Runs `contrib/guix/guix-build` for all platforms
- Generates build hashes for all output files
- Uploads results and hashes to CDash
- Cleans up build artifacts after each run
- Restarts on failure

### CI Scripts

The CTest/CDash configuration is self-contained in this repository:

- `scripts/guix.cmake` - CTest dashboard script that orchestrates the build
- `scripts/CTestConfig.cmake` - CDash submit URL configuration

These are symlinked to `/data/ci/` and `/data/bitcoin/` respectively on deployment.

## Hosts

Two CI runners are configured:

| Host | Arch | SSH Config | Disk Layout |
|------|------|------------|-------------|
| `guix-ci` | x86_64 | `guix-ci` | 2x NVMe (root LVM + /data) |
| `guix-ci-arm64` | aarch64 | `guix-ci-arm64` | HC_Volume (ESP) + QEMU HARDDISK (root + /data) |

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

3. **Disk Configuration**: Update disk device paths in `hosts/<hostname>/disk-config.nix` to match your server. Use stable `/dev/disk/by-id/` paths when possible:
   ```nix
   disk.disk1.device = lib.mkDefault "/dev/disk/by-id/scsi-...";
   ```

   Run `ls -la /dev/disk/by-id/` and `lsblk` on the target to identify disks.

4. **CDash URL** (optional): To use your own CDash instance, update `scripts/CTestConfig.cmake`:
   ```cmake
   set(CTEST_SUBMIT_URL https://your-cdash-server/submit.php?project=yourproject)
   ```

### Initial Deployment

1. Boot your server into a NixOS installer ISO or rescue system (or use existing OS with SSH)
2. Ensure SSH access works: `ssh <host> echo "connected"`
3. Deploy:
   ```bash
   # Same architecture (e.g., x86_64 -> x86_64)
   just deploy guix-ci guix-ci

   # Cross-architecture (e.g., x86_64 -> aarch64) - builds on remote
   just deploy-remote guix-ci-arm64 root@<ip>
   ```

This partitions disks and installs NixOS with the full CI configuration.

### Updating an Existing Deployment

Syncing first performs the build on the remote, which saves bandwidth/time.

```bash
just sync-rebuild guix-ci guix-ci           # x86_64 host
just sync-rebuild guix-ci-arm64 guix-ci-arm64  # arm64 host
```

Or separately:
```bash
just sync guix-ci           # copy config to remote
just rebuild guix-ci guix-ci  # rebuild on remote
```

### Monitoring

```bash
just logs guix-ci           # Follow CI logs
just status guix-ci         # Check CI service status
just status-all guix-ci     # Check all bitcoin-* services
```

## Data Layout

All build data is stored on a dedicated `/data` partition:

```
/data/
├── bitcoin/    # bitcoin/bitcoin
├── ci/         # CI scripts (symlinked from this repo)
├── sdk/        # macOS SDK for cross-compilation
├── sources/    # Guix depends source cache
└── cache/      # Guix built package cache
```

## Environment Variables

The CI service sets these environment variables for the Guix build:

- `SDK_PATH=/data/sdk` - macOS SDK location
- `SOURCES_PATH=/data/sources` - Depends source cache
- `BASE_CACHE=/data/cache` - Built package cache

## Build Hashes

After each successful build, SHA256 hashes of all output files are generated and uploaded to CDash as an artifact. The format matches the standard Guix attestation format:

```
x86_64
<sha256sum>  guix-build-<rev>/output/<file>
...
```

## Available Commands

Commands take optional `type` (flake config) and `host` (SSH target) parameters, defaulting to `guix-ci`:

```bash
just                                    # List all commands
just build [type]                       # Build configuration locally
just build-vm [type]                    # Build VM for testing
just dry-run [type]                     # Show what would change
just deploy [type] [host]               # Initial deployment (same arch)
just deploy-remote [type] [host]        # Initial deployment (cross-arch, builds on remote)
just sync [host]                        # Copy config to remote
just rebuild [type] [host]              # Rebuild on remote
just sync-rebuild [type] [host]         # Sync and rebuild in one step
just logs [host]                        # Follow CI logs
just status [host]                      # Check CI service status
just status-all [host]                  # Check all bitcoin-* services
```
