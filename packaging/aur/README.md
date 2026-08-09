# AUR packaging

`PKGBUILD` here is the source of truth for the `habit-stack` AUR package. The
AUR checkout (`~/aur/habit-stack`) is a copy of this file plus a generated
`.SRCINFO`.

## Why the checksum can go stale

`source=` points at the GitHub tarball for tag `v$pkgver`, and `sha256sums`
is the hash of that tarball. A tarball contains this very file, so the
checksum for tag vX cannot be committed *before* vX is tagged. The copy here
is therefore a **template**: after pushing a new tag, run `updpkgsums` in the
AUR checkout to fill in the real hash, and copy the result back here.

## Release flow

```bash
# 1. bump `version:` in pubspec.yaml, commit, push
# 2. tag and push the SINGLE tag (never `git push --tags`)
git tag v1.2.3 && git push origin v1.2.3

# 3. sync + checksum + build + verify
cp packaging/aur/PKGBUILD ~/aur/habit-stack/PKGBUILD
cd ~/aur/habit-stack
# bump pkgver to match the tag, then:
updpkgsums
makepkg -Cf
namcap ./*.pkg.tar.zst
sudo pacman -U ./habit-stack-*.pkg.tar.zst
habit-stack   # must print: habit_stack serving on http://localhost:8731

# 4. publish
makepkg --printsrcinfo > .SRCINFO
git add PKGBUILD .SRCINFO && git commit && git push   # branch is `master`
```

## Notes

- `install_arch.sh` is deliberately **not** wired to this PKGBUILD. That script
  builds the working tree for local development; this one builds a downloaded
  release tarball. Merging them would destroy the dev loop.
- `options=('!strip')` is load-bearing — see the comment in the PKGBUILD.
- The bundle is `bin/`-only (no native dependencies), which is why `package()`
  guards the `lib/` copy with `if [[ -d ]]`.
- Building requires network access (`pub get`, plus a git fetch of the shared
  `crdt_sync` dependency). The tracked `pubspec.lock` pins what gets resolved.
