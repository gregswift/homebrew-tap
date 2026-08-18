#!/bin/sh
#
# bump-formula.sh <formula-file> <owner/repo>
#
# Points a formula at the newest release of its source repository, computing
# the checksum from the tarball rather than asking anyone to type one.
#
# Nothing here needs a credential: the source repository is public, and the
# only thing written is this repository, which the workflow's own token covers.
#
# Prints nothing and exits 0 when the formula is already current, so a run on a
# quiet week is silent.

set -eu

FORMULA=${1:?usage: bump-formula.sh <formula-file> <owner/repo>}
SOURCE=${2:?usage: bump-formula.sh <formula-file> <owner/repo>}

[ -f "$FORMULA" ] || { printf 'no such formula: %s\n' "$FORMULA" >&2; exit 1; }

TAG=$(gh release view -R "$SOURCE" --json tagName --jq .tagName 2>/dev/null) || TAG=""
if [ -z "$TAG" ]; then
    printf '%s has no releases yet; nothing to point at\n' "$SOURCE"
    exit 0
fi

URL="https://github.com/$SOURCE/archive/refs/tags/$TAG.tar.gz"

if grep -q "$URL" "$FORMULA"; then
    printf '%s is already on %s\n' "$FORMULA" "$TAG"
    exit 0
fi

# Downloaded once, hashed from the same bytes, so the checksum cannot disagree
# with what the URL serves at this moment.
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT INT TERM
curl -fsSL "$URL" -o "$TMP/src.tar.gz"
# sha256sum on most Linux, shasum on macOS, and plenty of boxes have both.
if command -v sha256sum >/dev/null 2>&1; then
    SHA=$(sha256sum "$TMP/src.tar.gz" | cut -d' ' -f1)
else
    SHA=$(shasum -a 256 "$TMP/src.tar.gz" | cut -d' ' -f1)
fi

# python rather than sed: this has to both replace an existing pair of lines and
# insert them where none exist, and the two sed dialects disagree about how.
python3 - "$FORMULA" "$URL" "$SHA" <<'PY'
import io, re, sys
path, url, sha = sys.argv[1], sys.argv[2], sys.argv[3]
s = io.open(path, encoding="utf-8").read()

if re.search(r'^\s*url\s+"', s, re.M):
    s = re.sub(r'^(\s*)url\s+".*"$',  lambda m: '%surl "%s"' % (m.group(1), url), s, count=1, flags=re.M)
    s = re.sub(r'^(\s*)sha256\s+".*"$', lambda m: '%ssha256 "%s"' % (m.group(1), sha), s, count=1, flags=re.M)
else:
    # No stable stanza yet. It belongs above head, which is where Homebrew's
    # own formulae put it.
    m = re.search(r'^(\s*)(head\s+")', s, re.M)
    if not m:
        sys.exit("formula has neither a url nor a head stanza; not guessing where to put one")
    indent = m.group(1)
    s = s[:m.start()] + '%surl "%s"\n%ssha256 "%s"\n' % (indent, url, indent, sha) + s[m.start():]

io.open(path, "w", encoding="utf-8").write(s)
PY

printf 'bumped %s to %s\n' "$FORMULA" "$TAG"
# For the workflow's commit message. Harmless when run by hand.
[ -z "${GITHUB_OUTPUT:-}" ] || printf 'tag=%s\n' "$TAG" >>"$GITHUB_OUTPUT"
