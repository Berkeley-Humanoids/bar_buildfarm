# bar_buildfarm

Conda buildfarm for the **BAR low-level control stack**. Builds every `bar_ros2`
package (and its non-RoboStack source deps) into `ros-jazzy-*` **conda packages**
and publishes them to a [prefix.dev](https://prefix.dev) channel, so end users
install prebuilt binaries instead of running `colcon build`.

Backend: [`pixi-build-ros`](https://pixi.prefix.dev/latest/build/backends/pixi-build-ros/)
→ `rattler-build` → `.conda`. This is the conda-world translation of the
`qiayuanl/{unitree,legged}_buildfarm` apt/`.deb` pattern — same orchestration
(thin repo, nightly cron, arch matrix, tag-driven release), conda backend.
Full design: [`../BUILDFARM_PLAN.md`](../BUILDFARM_PLAN.md).

## How it works

1. `bar.repos` lists the sources (first-party `bar_ros2` + the 4 deps missing from
   RoboStack: `ethercat_driver_ros2`, `mujoco_ament`, `mujoco_sim_ros2`,
   `mujoco_ros2_control`).
2. `pixi run import` clones them into `src/` (gitignored).
3. `pixi run overlay` drops a conda build manifest into each third-party tree
   (`overlays/` mirrors `src/`). First-party `bar_ros2` packages already carry
   their own `pixi.toml`.
4. `pixi run build-all [platform]` builds every path in `packages.txt` into
   `output/*.conda` via `pixi build --path`.
5. `pixi run publish` uploads `output/` to the prefix.dev channel.

`packages.txt` is the buildable set; `packages-blocked.txt` is the not-yet set
(see Long poles).

## Local build (no account needed)

```bash
pixi run import
pixi run overlay
pixi run build-all          # → output/*.conda  (linux-64)
```

### End-to-end demo via a local `file://` channel

Prove the full producer→consumer flow with no prefix.dev account:

```bash
# build into a channel layout, then index it
mkdir -p local-channel/linux-64 && cp output/*.conda local-channel/linux-64/
pixi exec --spec conda-index -- python -m conda_index local-channel

# consume it from a throwaway workspace
pixi init /tmp/consume -c "file://$PWD/local-channel" \
                       -c https://prefix.dev/robostack-jazzy \
                       -c https://prefix.dev/conda-forge
cd /tmp/consume && pixi add ros-jazzy-bar-controllers   # pulls bar_msgs, bar_common, onnxruntime…
```

## CI / publishing

`.github/workflows/build_jazzy.yml`: nightly cron (skips if RoboStack-jazzy is
unchanged), `workflow_dispatch`, and `push` on tags `v*` / build-input changes.
Matrix builds `linux-64` (`ubuntu-24.04`) + `linux-aarch64` (`ubuntu-24.04-arm`,
**native** — conda cross-compile is avoided). On a version tag it publishes to
the channel; nightlies build + upload artifacts for verification.

## ⚠️ Manual setup (needs your credentials)

1. **prefix.dev channel** — create the `bar-robotics` channel at prefix.dev. For
   auth, either add a repo secret `PREFIX_API_KEY`, or configure **trusted
   publishing** (OIDC) for this repo (the workflow already requests
   `id-token: write`).
2. **GitHub remote** — create the `bar_buildfarm` repo, push, and enable Actions
   read/write. (Optional: a `GH_PAT` secret for the docs-refresh trigger.)
3. **Commit the manifests in `bar_ros2`** — the 12 per-package `pixi.toml` files
   were added under `bar_ros2/`; CI clones `bar_ros2` fresh, so they must be
   committed/pushed there for the buildfarm to find them.

## Long poles (tracked in `packages-blocked.txt`)

- **`ethercat_driver_ros2` → IgH EtherLab `libethercat`.** No conda-forge package
  exists. Build a conda package for the EtherLab userspace lib (or vendor a
  prebuilt) first; then move the `ethercat_*` paths from `packages-blocked.txt`
  into `packages.txt`. Also unblocks `bar_bringup_prime`.
- **`mujoco_ament` network build.** FetchContents the MuJoCo tarball at configure
  time → needs network during build (rattler-build allows it; non-hermetic). If
  flaky, repackage the MuJoCo binary as its own conda dep.

## Status

- ✅ Verified locally: `bar_msgs`, `bar_common`, `bar_controllers` (with ONNX)
  build to `.conda` and install as binaries from a `file://` channel.
- ⏳ `mujoco_*` overlays present; not yet build-verified (network build).
- ⛔ `ethercat_*` + `bar_bringup_prime` blocked on `libethercat`.
