---
bump: minor
---

Add 9 fluent methods on `Parser(T)`: `.map`, `.chain`, `.errorMap`, `.skip`, `.then`, `.between`, `.lookahead`, `.withSpan`, `.spanMap`. All take `comptime self` to fit the comptime-monomorphic composition model. Adds `Span { start, end }` and `Spanned(T) { value, start, end }` helper types.
