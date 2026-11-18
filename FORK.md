# PSMutant: patch branch for QUINDOS

This repository carries changes to [PSMutant](https://github.com/Fortigi/PSMutant) that the
QUINDOS test tier needs, until they are merged upstream. It is not a separate product. Every
change is meant for upstream, except the fork-only files listed below.

## Branches

| Branch | Content |
|---|---|
| `main` | Mirror of `Fortigi/PSMutant` `main`. Never commit here. |
| `upstream/<topic>` | One upstream pull request per branch, based on `main`. Each one has its regression tests, keeps the gates of `CLAUDE.md` (100 % coverage, 100 % self-mutation, lint, complexity) and has nothing fork-specific. Each bumps `ModuleVersion` and adds a `CHANGELOG.md` entry, as upstream asks of a change that ships. |
| `quindos` (default) | `main` + the commits of all `upstream/*` branches + fork-only commits. Releases are tagged here. |

### Changes waiting for upstream

| Branch | Change | Upstream issue / PR |
|---|---|---|
| `upstream/changed-lines` | `-ChangedLine` narrows a `-ChangedFile` run to the changed lines of each named file. A mutant is kept when a named line lies between its first and its last line. A changed file without a key is mutated whole. ModuleVersion 0.10.0. Based on `main` at `240b644`. | PR [#331](https://github.com/Fortigi/PSMutant/pull/331) |
| `upstream/uncovered-mutants` | The full report lists each mutant the covered-lines filter removed in `uncoveredMutants`, with its file and line. An argument of a parameter attribute, such as `Mandatory = $true`, counts as covered when a line of its function's body ran. ModuleVersion 0.10.0. Based on `main` at `240b644` (0.9.3, not yet released upstream). | PR [#328](https://github.com/Fortigi/PSMutant/pull/328) |
| `upstream/failed-block-errors` | A run that fails with no failed test, such as a failed `AfterAll` or a TestDrive that Pester could not remove, says what failed. The worker green refusal gives one line of each error that Pester kept on a block or a test file, and a `Killed` row with an empty `KilledBy` carries them in the optional field `KilledByError`. ModuleVersion 0.10.0. Based on `main` at `240b644`. | PR [#330](https://github.com/Fortigi/PSMutant/pull/330), for issue [#329](https://github.com/Fortigi/PSMutant/issues/329) |
| `upstream/worker-death` | A worker start that fails by accident, or a sandbox file that another process holds, no longer stops the run. The write of a mutant and each restore of the sandbox wait while another process holds the file (Windows errors 32 and 33), 300 times 100 ms apart. A new worker process is started again, up to 3 times, when the first one ended during its start, or when it opened its runspace without a debugger. The second case is a race of the PowerShell client, and the process lives on; `quindos` has it since `v0.10.0-quindos.6`. ModuleVersion 0.10.0. Based on `main` at `240b644`. | Not filed yet |

Each commit on a topic branch ends its subject with its upstream issue, as `(#309)`, the form
that upstream uses. When a pull request merges, remove its branch from this table and from the
update steps below.

The two earlier topics are upstream now: `upstream/measured-deadline` merged as
[#310](https://github.com/Fortigi/PSMutant/issues/310), and upstream fixed
[#309](https://github.com/Fortigi/PSMutant/issues/309) with a named pipe in v0.9.2. Since
`v0.10.0-quindos.1`, `quindos` holds neither branch.

### Fork-only files

- `FORK.md` (this file).
- `fork/New-PSMutantForkPackage.ps1`: writes the release zip and its `.sha256` file.
- `Prerelease` in `PSMutant.psd1`, so that a fork build does not pass for the gallery release of
  the same `ModuleVersion`.

## Updating from upstream

```bash
git remote add upstream https://github.com/Fortigi/PSMutant.git   # once
git fetch upstream
old_main=$(git rev-parse main)
git checkout main && git merge --ff-only upstream/main
for b in upstream/changed-lines upstream/uncovered-mutants upstream/failed-block-errors upstream/worker-death; do
  git rebase main "$b"
done
git rebase --onto main "$old_main" quindos   # replays topic commits + fork-only commits
git push --force-with-lease origin main 'upstream/*' quindos
```

- Several topics bump `ModuleVersion` and add a `CHANGELOG.md` section for the same version. On
  `quindos` those sections are one. When upstream merges one topic, rebase the others on it and
  give them the next version, or the same one when upstream has not released it yet.
- If git reports a commit as already upstream during the rebase, drop it. When a topic is merged
  upstream, delete its branch and remove its row above.
- Consumers pin release zips (version + SHA-256), not branch commits, so rewriting `quindos`
  does not affect them.
- Exit: when no patches are left, pin the gallery release again and archive this repository.

## Releases

Tag `quindos` with `v<ModuleVersion>-quindos.<n>`, for example `v0.10.0-quindos.1`. Set
`Prerelease = 'quindos<n>'` in `PSMutant.psd1` in the same commit. Then:

```powershell
./fork/New-PSMutantForkPackage.ps1 -Release quindos.1
```

writes `dist/PSMutant-<ModuleVersion>-quindos.<n>.zip` and its `.sha256` file. Attach both to the
GitHub release of the tag. The zip holds what `publish.yml` stages for the gallery, at its root:

```
PSMutant.psd1, PSMutant.psm1   the module
src/, schemas/                 the code and the published schemas
LICENSE, README.md
```

This fork keeps `publish.yml` as upstream has it, but the workflow is disabled in the Actions
settings of the fork, so a pushed tag `v*` starts no run. The fork also has no `PSGALLERY_API_KEY`
secret, so a run would publish nothing to the gallery. Keep the workflow disabled.

## Checking a change

The gates are the ones of `CLAUDE.md`, with Pester 6.2.0 (`.github/pins.env`):

```powershell
Import-Module Pester -RequiredVersion 6.2.0 -Force
./tools/Invoke-PSMutantAnalyzer.ps1
./tools/Measure-PSMutantCoverage.ps1
./tools/New-PSMutantScopedConfig.ps1 -Run
```

On Windows without Developer Mode, the two symlink tests of `tests/Sandbox.Tests.ps1` fail with
"Administrator privilege required for this operation", on `main` too, and the coverage of
`PSMutation.Sandbox.ps1` is then below 100 %. `ci.yml` runs on Linux and Windows, where they pass.
It starts on a push to `main` only, and this fork keeps the file as upstream has it, so start it by
hand on a topic branch: `gh workflow run ci.yml --ref upstream/<topic>`.

`New-PSMutantScopedConfig.ps1 -Run` copies no `workers` value, so its mutants run in the host
process. The mutant `-gt -> -le` at `PSMutation.Runner.ps1:1595` then makes a Runner test call
`[Environment]::Exit(3)`, and the host ends without a report. On such a run, write the scoped
config with `workers: 3`, as `psmutant.self.config.json` has, and start `Invoke-PSMutation` on it.
