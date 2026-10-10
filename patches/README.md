# Local patches

This branch (`patched`) is upstream zls plus patches to **Zig's standard library**
that zls compiles in. They're for personal use and aren't meant to go upstream.
The patch was written with an AI assistant (Claude), and the Zig project doesn't
accept LLM-assisted contributions.

Build and install with `../build-patched.sh`. It copies the installed Zig lib,
applies every `*.patch` here, builds zls against that copy, and installs it to
`~/.local/bin/zls`.

## zig-std-parse-recovery.patch

**Symptom:** while typing a struct literal like `.{ . }`, completion returns
nothing:
- inside a function that's inside a struct (e.g. `ip.bind(io, .{ . })` in a method);
- in a function that returns a type defined *below* it (`return .{ . }`).

**Cause:** `std/zig/Parse.zig`, `expectStatementRecoverable`. On a parse error,
`findNextStmt` scans forward from the error token, counting braces. The `{` of
`.{` was consumed before the error, so its `}` is taken as the end of the enclosing
block. The braces after it no longer match up, and the parser drops whatever
follows: the enclosing `const X = struct {...}`, or the declarations after the
function.

**Fix:** if the whole file's `{`/`}` balance, rescan from the start of the failed
statement so its braces are counted. If they don't balance (an unclosed brace,
probably in the code being typed), keep the old behaviour.

Tested on Zig 0.16.0: all zls tests and all 405 `zig fmt` parser tests pass.

## When Zig updates

1. `git fetch origin --tags`, then rebase this branch onto the new zls tag that
   matches `zig version` (e.g. `git rebase --onto 0.17.0 0.16.0 patched`).
2. Run `./build-patched.sh`.
   - If the patch **doesn't apply**, check whether upstream's
     `expectStatementRecoverable` changed or fixed it.
   - To check whether it's still needed, run stock zls and type `.{ .` in a
     method of a struct, or `return .{ .` in a function above the returned
     struct. If the fields show up, delete the patch and `~/.local/bin/zls`.
