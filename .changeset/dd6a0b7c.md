---
bump: minor
---

Add `fail(error)` and `succeed(T, value)` primitive parsers. `fail` returns `Parser(noreturn)` and always emits the supplied `ParseError`. `succeed` returns `Parser(T)` and always returns the supplied value without consuming input. Both available as `parsil.fail` and `parsil.succeed` from the public barrel.
