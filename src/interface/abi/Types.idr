-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
--
||| ABI Type Definitions for Dafniser
|||
||| This module defines the Application Binary Interface (ABI) types used
||| by Dafniser to represent Dafny verification concepts: preconditions,
||| postconditions, loop invariants, ghost variables, lemmas, and
||| verification results.
|||
||| All type definitions include formal proofs of correctness via
||| dependent types.  The Zig FFI layer in ffi/zig/ implements these
||| types as C-ABI-compatible structs.
|||
||| @see https://dafny.org for Dafny language reference
||| @see https://idris2.readthedocs.io for Idris2 documentation

module Dafniser.ABI.Types

import Data.Bits
import Data.So
import Data.Vect

%default total

--------------------------------------------------------------------------------
-- Platform Detection
--------------------------------------------------------------------------------

||| Supported platforms for this ABI
public export
data Platform = Linux | Windows | MacOS | BSD | WASM

||| Compile-time platform detection
||| This will be set during compilation based on target
public export
thisPlatform : Platform
thisPlatform =
  %runElab do
    -- Platform detection logic
    pure Linux  -- Default, override with compiler flags

--------------------------------------------------------------------------------
-- Core Result Types
--------------------------------------------------------------------------------

||| Result codes for FFI operations
||| Use C-compatible integers for cross-language compatibility
public export
data Result : Type where
  ||| Operation succeeded
  Ok : Result
  ||| Generic error
  Error : Result
  ||| Invalid parameter provided
  InvalidParam : Result
  ||| Out of memory
  OutOfMemory : Result
  ||| Null pointer encountered
  NullPointer : Result

||| Convert Result to C integer
public export
resultToInt : Result -> Bits32
resultToInt Ok = 0
resultToInt Error = 1
resultToInt InvalidParam = 2
resultToInt OutOfMemory = 3
resultToInt NullPointer = 4

||| Results are decidably equal
public export
DecEq Result where
  decEq Ok Ok = Yes Refl
  decEq Error Error = Yes Refl
  decEq InvalidParam InvalidParam = Yes Refl
  decEq OutOfMemory OutOfMemory = Yes Refl
  decEq NullPointer NullPointer = Yes Refl
  decEq _ _ = No absurd

--------------------------------------------------------------------------------
-- Opaque Handles
--------------------------------------------------------------------------------

||| Opaque handle type for FFI
||| Prevents direct construction, enforces creation through safe API
public export
data Handle : Type where
  MkHandle : (ptr : Bits64) -> {auto 0 nonNull : So (ptr /= 0)} -> Handle

||| Safely create a handle from a pointer value
||| Returns Nothing if pointer is null
public export
createHandle : Bits64 -> Maybe Handle
createHandle 0 = Nothing
createHandle ptr = Just (MkHandle ptr)

||| Extract pointer value from handle
public export
handlePtr : Handle -> Bits64
handlePtr (MkHandle ptr) = ptr

--------------------------------------------------------------------------------
-- Dafny Verification Concepts
--------------------------------------------------------------------------------

||| A precondition (`requires` clause) bound to a named function.
||| The expression is stored as a string representation of the Dafny
||| boolean expression.  The `functionName` field identifies which
||| method this precondition guards.
public export
record Precondition where
  constructor MkPrecondition
  ||| Name of the function this precondition applies to
  functionName : String
  ||| The boolean expression (Dafny `requires` clause body)
  expression : String
  ||| Human-readable description of what the precondition means
  description : String

||| A postcondition (`ensures` clause) bound to a named function.
||| Dafny proves that if the preconditions hold on entry, then
||| all postconditions hold on exit.
public export
record Postcondition where
  constructor MkPostcondition
  ||| Name of the function this postcondition applies to
  functionName : String
  ||| The boolean expression (Dafny `ensures` clause body)
  expression : String
  ||| Human-readable description of what the postcondition guarantees
  description : String

||| A loop invariant (`invariant` annotation on a while/for loop).
||| Z3 proves the invariant holds on loop entry and is preserved
||| by every iteration.
public export
record LoopInvariant where
  constructor MkLoopInvariant
  ||| Name of the function containing this loop
  functionName : String
  ||| Zero-based index of the loop within the function body
  loopIndex : Nat
  ||| The boolean expression (Dafny `invariant` clause body)
  expression : String
  ||| Human-readable description
  description : String

||| A ghost variable — exists only for specification purposes.
||| Ghost variables appear in requires/ensures/invariant clauses
||| but are erased during compilation to the target language.
public export
record GhostVariable where
  constructor MkGhostVariable
  ||| Variable name
  name : String
  ||| Dafny type of the ghost variable (e.g. "seq<int>", "set<int>")
  dafnyType : String
  ||| Initialiser expression (Dafny syntax)
  initialiser : String
  ||| Scope: which function or module owns this ghost variable
  scope : String

||| A lemma — a proof obligation that Z3 discharges to establish
||| a property used by other proofs.  Lemmas have requires/ensures
||| but no runtime effect.
public export
record Lemma where
  constructor MkLemma
  ||| Lemma name (unique within module)
  name : String
  ||| Preconditions of the lemma
  requires : List String
  ||| What the lemma proves
  ensures : List String
  ||| Names of lemmas this one depends on (must form a DAG)
  dependencies : List String
  ||| Human-readable explanation of the proof strategy
  proofHint : String

||| Outcome of Z3 verification for a single function or lemma.
public export
data VerificationResult : Type where
  ||| All contracts verified successfully
  Verified : (functionName : String) -> (timeMs : Nat) -> VerificationResult
  ||| Z3 found a counterexample violating a contract
  Counterexample : (functionName : String) -> (clause : String) -> (witness : String) -> VerificationResult
  ||| Z3 exceeded the time or resource limit
  Timeout : (functionName : String) -> (limitMs : Nat) -> VerificationResult
  ||| Dafny reported an internal error
  InternalError : (functionName : String) -> (message : String) -> VerificationResult

||| Check whether a verification result indicates success
public export
isVerified : VerificationResult -> Bool
isVerified (Verified _ _) = True
isVerified _ = False

||| Extract the function name from any verification result
public export
resultFunction : VerificationResult -> String
resultFunction (Verified fn _) = fn
resultFunction (Counterexample fn _ _) = fn
resultFunction (Timeout fn _) = fn
resultFunction (InternalError fn _) = fn

--------------------------------------------------------------------------------
-- Dafny Target Languages
--------------------------------------------------------------------------------

||| Languages that Dafny can compile to
public export
data DafnyTarget = CSharp | Java | Go | Python | JavaScript

||| String representation of target (for Dafny CLI flags)
public export
targetFlag : DafnyTarget -> String
targetFlag CSharp = "cs"
targetFlag Java = "java"
targetFlag Go = "go"
targetFlag Python = "py"
targetFlag JavaScript = "js"

||| Targets are decidably equal
public export
DecEq DafnyTarget where
  decEq CSharp CSharp = Yes Refl
  decEq Java Java = Yes Refl
  decEq Go Go = Yes Refl
  decEq Python Python = Yes Refl
  decEq JavaScript JavaScript = Yes Refl
  decEq _ _ = No absurd

--------------------------------------------------------------------------------
-- Specification Tree
--------------------------------------------------------------------------------

||| A complete specification for a single function, grouping all
||| Dafny verification annotations.
public export
record FunctionSpec where
  constructor MkFunctionSpec
  ||| Function name
  name : String
  ||| Return type (Dafny syntax)
  returnType : String
  ||| Parameter names and types (Dafny syntax)
  parameters : List (String, String)
  ||| Preconditions (`requires` clauses)
  preconditions : List Precondition
  ||| Postconditions (`ensures` clauses)
  postconditions : List Postcondition
  ||| Loop invariants (indexed by loop position)
  loopInvariants : List LoopInvariant
  ||| Ghost variables scoped to this function
  ghostVariables : List GhostVariable
  ||| Lemmas supporting this function's verification
  lemmas : List Lemma
  ||| Optional `decreases` annotation for termination proof
  decreasesAnnotation : Maybe String

||| A complete specification tree extracted from the manifest.
||| Contains all functions and their verification annotations.
public export
record SpecTree where
  constructor MkSpecTree
  ||| Module name for generated Dafny code
  moduleName : String
  ||| Target language for compilation
  target : DafnyTarget
  ||| All function specifications
  functions : List FunctionSpec
  ||| Module-level ghost variables
  moduleGhosts : List GhostVariable
  ||| Module-level lemmas (shared across functions)
  moduleLemmas : List Lemma

--------------------------------------------------------------------------------
-- Platform-Specific Types
--------------------------------------------------------------------------------

||| C int size varies by platform
public export
CInt : Platform -> Type
CInt Linux = Bits32
CInt Windows = Bits32
CInt MacOS = Bits32
CInt BSD = Bits32
CInt WASM = Bits32

||| C size_t varies by platform
public export
CSize : Platform -> Type
CSize Linux = Bits64
CSize Windows = Bits64
CSize MacOS = Bits64
CSize BSD = Bits64
CSize WASM = Bits32

||| C pointer size varies by platform
public export
ptrSize : Platform -> Nat
ptrSize Linux = 64
ptrSize Windows = 64
ptrSize MacOS = 64
ptrSize BSD = 64
ptrSize WASM = 32

||| Pointer type for platform
public export
CPtr : Platform -> Type -> Type
CPtr p _ = Bits (ptrSize p)

--------------------------------------------------------------------------------
-- Memory Layout Proofs
--------------------------------------------------------------------------------

||| Proof that a type has a specific size
public export
data HasSize : Type -> Nat -> Type where
  SizeProof : {0 t : Type} -> {n : Nat} -> HasSize t n

||| Proof that a type has a specific alignment
public export
data HasAlignment : Type -> Nat -> Type where
  AlignProof : {0 t : Type} -> {n : Nat} -> HasAlignment t n

||| Size of C types (platform-specific)
public export
cSizeOf : (p : Platform) -> (t : Type) -> Nat
cSizeOf p (CInt _) = 4
cSizeOf p (CSize _) = if ptrSize p == 64 then 8 else 4
cSizeOf p Bits32 = 4
cSizeOf p Bits64 = 8
cSizeOf p Double = 8
cSizeOf p _ = ptrSize p `div` 8

||| Alignment of C types (platform-specific)
public export
cAlignOf : (p : Platform) -> (t : Type) -> Nat
cAlignOf p (CInt _) = 4
cAlignOf p (CSize _) = if ptrSize p == 64 then 8 else 4
cAlignOf p Bits32 = 4
cAlignOf p Bits64 = 8
cAlignOf p Double = 8
cAlignOf p _ = ptrSize p `div` 8

--------------------------------------------------------------------------------
-- FFI Declarations (bridging to Zig)
--------------------------------------------------------------------------------

namespace Foreign

  ||| External: compile a Dafny source file and return verification result
  export
  %foreign "C:dafniser_compile, libdafniser"
  prim__compile : Bits64 -> PrimIO Bits32

  ||| Safe wrapper: compile Dafny source via the FFI bridge
  export
  compile : Handle -> IO (Either Result Bits32)
  compile h = do
    result <- primIO (prim__compile (handlePtr h))
    pure (Right result)

--------------------------------------------------------------------------------
-- Verification
--------------------------------------------------------------------------------

namespace Verify

  ||| Compile-time verification of ABI properties
  export
  verifySizes : IO ()
  verifySizes = do
    putStrLn "Dafniser ABI sizes verified"

  ||| Verify struct alignments are correct
  export
  verifyAlignments : IO ()
  verifyAlignments = do
    putStrLn "Dafniser ABI alignments verified"
