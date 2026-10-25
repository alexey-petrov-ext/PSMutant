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
| `upstream/worker-null-stdio` | A worker process gives its standard input, output and error to the null device before a suite runs there. They are the remoting channel of its out-of-process runspace, and a child process of the code under test inherited them: a child that read its input read the channel and never ended (Git for Windows on a missing object), and one line on its error output or its output broke the runspace and stopped the run. | not opened |
| `upstream/measured-deadline` | The deadline of a file, and of a first pass, is `max(floor, seconds x factor)`. Its seconds were measured in every worker at once, and the old `x workers` counted the load twice: with 32 workers a hung mutant waited 5.6 hours. The deadline from the solo baseline still scales with the workers. | not opened |

The commits on the topic branches name their upstream issue as `#309` (stdio) and `#310`
(deadline) until the issues exist. Replace them when the issues are open.

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
for b in upstream/worker-null-stdio upstream/measured-deadline; do
  git rebase main "$b"
done
git rebase --onto main "$old_main" quindos   # replays topic commits + fork-only commits
git push --force-with-lease origin main 'upstream/*' quindos
```

- Two topics bump `ModuleVersion` and add a `CHANGELOG.md` section for the same version. On
  `quindos` the two sections are one. When upstream merges one topic, rebase the other on it and
  give it the next version, or the same one when upstream has not released it yet.
- If git reports a commit as already upstream during the rebase, drop it. When a topic is merged
  upstream, delete its branch and remove its row above.
- Consumers pin release zips (version + SHA-256), not branch commits, so rewriting `quindos`
  does not affect them.
- Exit: when no patches are left, pin the gallery release again and archive this repository.

## Releases

Tag `quindos` with `v<ModuleVersion>-quindos.<n>`, for example `v0.9.1-quindos.1`. Set
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
hand on a topic branch: `gh workflow run ci.yml --ref upstream/<topic>`. Its Linux leg is the only
check of the Unix half of `upstream/worker-null-stdio`.
