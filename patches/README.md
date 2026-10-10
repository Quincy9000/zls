# Local patches

This branch (`patched`) is upstream zls plus patches to **Zig's standard library**
that zls compiles in. They're for personal use and aren't meant to go upstream.
The patch was written with an AI assistant (Claude), and the Zig project doesn't
accept LLM-assisted contributions.

Build and install with `../build-patched.sh`. It copies the installed Zig lib,
applies every `*.patch` here, builds zls against that copy, and installs it to
`~/.local/bin/zls`.

## zig-std-parse-local-recovery.patch

**Symptom:** while typing a struct literal like `.{ . }`, completion returns
nothing:
- inside a function that's inside a struct (e.g. `ip.bind(io, .{ . })` in a method);
- in a function that returns a type defined *below* it (`return .{ . }`).

**Cause:** in `std/zig/Parse.zig`, an error inside `.{ ... }` escapes all the way
up to the statement, and `expectStatementRecoverable` → `findNextStmt` skips
forward from the error token, counting braces. The `{` of `.{` was consumed before
the error, so its `}` is taken as the end of the enclosing block. The braces after
it no longer match up, and the parser drops whatever follows: the enclosing
`const X = struct {...}`, or the declarations after the function.

**Fix:** brace-delimited lists recover from their own errors, so the error never
reaches the statement. When an element of an init list (`.{ ... }`, `T{ ... }`) or
a switch prong fails to parse, `recoverListElement` skips from the element's start
to the `,` or `}` that ends it. The broken element is left out, and the list and
statement finish normally. That `}` is only trusted when the file's braces balance
(`bracesBalanced`, computed once per parse). With an unclosed brace, probably in the
code being typed, the error goes up to the statement as before. The two duplicated
init-list loops are merged into one `parseInitList`.

Tested on Zig 0.16.0:
- All 405 `zig fmt` parser tests pass.
- All zls tests pass except one, `continue with label - structinit`. That test
  expects *no* completions for `.alpha => continue :blk .{ . }` and is marked
  `TODO this should have the following completion items: alpha, beta`. With the
  patch, zls returns exactly `alpha` and `beta`.

An earlier version of this patch rescanned the whole failed statement from its start
instead. It fixed the same cases, but this version keeps the error where it happened.

## When Zig updates

1. `git fetch origin --tags`, then rebase this branch onto the new zls tag that
   matches `zig version` (e.g. `git rebase --onto 0.17.0 0.16.0 patched`).
2. Run `./build-patched.sh`.
   - If the patch **doesn't apply**, check whether upstream changed or fixed the
     init-list parsing in `parsePrimaryTypeExpr` / `parseCurlySuffixExpr`, or
     `parseSwitchProngList`.
   - To check whether it's still needed, run stock zls and type `.{ .` in a
     method of a struct, or `return .{ .` in a function above the returned
     struct. If the fields show up, delete the patch and `~/.local/bin/zls`.
