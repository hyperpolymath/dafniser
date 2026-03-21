# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# TOPOLOGY.md — Dafniser module topology and data flow

## Overview

Dafniser transforms function specifications (pre/postconditions, invariants)
into verified Dafny implementations, proves them via Z3, and compiles to
target languages with a Zig FFI bridge.

## Data Flow

```
dafniser.toml
  │
  ├─► [Manifest Parser]  (src/manifest/)
  │       │
  │       ▼
  │   SpecTree { functions, preconditions, postconditions,
  │              invariants, ghost_vars, lemma_hints }
  │       │
  │       ├─► [Idris2 ABI]  (src/interface/abi/)
  │       │       │
  │       │       ▼
  │       │   Meta-proofs: spec consistency, termination,
  │       │   ghost scoping, refinement monotonicity
  │       │       │
  │       │       ▼
  │       │   C headers  (src/interface/generated/abi/)
  │       │
  │       └─► [Dafny Codegen]  (src/codegen/)
  │               │
  │               ▼
  │           .dfy files with requires/ensures/invariant/
  │           decreases/ghost/lemma annotations
  │               │
  │               ▼
  │           [Dafny Compiler + Z3]
  │               │
  │               ├─► Verification result (pass / counterexample)
  │               │
  │               └─► Target language output (C#/Java/Go/Python/JS)
  │                       │
  │                       ▼
  │                   [Zig FFI Bridge]  (src/interface/ffi/)
  │                       │
  │                       ▼
  │                   C-ABI shared library (libdafniser.so/.dylib/.dll)
  │
  └─► [CLI]  (src/main.rs)
          Subcommands: init, validate, generate, build, run, info
```

## Module Map

| Module | Path | Purpose |
|--------|------|---------|
| CLI | `src/main.rs` | Command dispatch, argument parsing |
| Library API | `src/lib.rs` | Public API for programmatic use |
| Manifest | `src/manifest/` | TOML parsing, spec extraction, validation |
| Codegen | `src/codegen/` | Dafny source generation with verification annotations |
| ABI Types | `src/interface/abi/Types.idr` | Precondition, Postcondition, LoopInvariant, GhostVariable, Lemma, VerificationResult |
| ABI Layout | `src/interface/abi/Layout.idr` | Spec tree memory layout, field alignment proofs |
| ABI Foreign | `src/interface/abi/Foreign.idr` | FFI declarations for Dafny compilation and Z3 invocation |
| FFI Impl | `src/interface/ffi/src/main.zig` | C-ABI implementation of Foreign.idr declarations |
| FFI Build | `src/interface/ffi/build.zig` | Zig build configuration (shared + static libs) |
| FFI Tests | `src/interface/ffi/test/integration_test.zig` | ABI compliance integration tests |
| Generated | `src/interface/generated/abi/` | Auto-generated C headers from Idris2 ABI |

## External Dependencies

| Dependency | Role | Required |
|------------|------|----------|
| Dafny | Verification-aware language compiler | Yes (Phase 2+) |
| Z3 | SMT solver backend for Dafny | Yes (Phase 3+) |
| .NET / Java / Go / Python / Node | Target language runtimes | Per target |
| Idris2 | ABI formal proofs | Yes (Phase 5+) |
| Zig | FFI bridge compilation | Yes (Phase 4+) |

## Key Types (Idris2 ABI)

| Type | Purpose |
|------|---------|
| `Precondition` | A `requires` clause bound to a function |
| `Postcondition` | An `ensures` clause bound to a function |
| `LoopInvariant` | An `invariant` annotation on a loop |
| `GhostVariable` | A specification-only variable (erased at compilation) |
| `Lemma` | A proof obligation discharged by Z3 |
| `VerificationResult` | Outcome of Z3 verification (Verified / Counterexample / Timeout) |
| `SpecTree` | Complete specification tree extracted from manifest |

## Verification Pipeline

1. **Parse**: TOML manifest -> SpecTree (Rust)
2. **Meta-prove**: SpecTree -> Idris2 ABI consistency proofs
3. **Generate**: SpecTree -> .dfy source files
4. **Verify**: .dfy -> Z3 -> VerificationResult
5. **Compile**: verified .dfy -> target language source
6. **Bridge**: target source -> Zig FFI -> C-ABI shared library
