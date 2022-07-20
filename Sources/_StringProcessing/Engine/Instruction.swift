//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2021-2022 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

/// A single instruction for the matching engine to execute
///
/// Instructions are 64-bits, consisting of an 8-bit opcode
/// and a 56-bit payload, which packs operands.
///
struct Instruction: RawRepresentable, Hashable {
  var rawValue: UInt64
  init(rawValue: UInt64){
    self.rawValue = rawValue
  }
}

extension Instruction {
  enum OpCode: UInt64 {
    case invalid = 0

    // MARK: - General Purpose

    /// Move an immediate value into a register
    ///
    ///     moveImmediate(_ i: Int, into: IntReg)
    ///
    /// Operands:
    ///   - Immediate value to move
    ///   - Int register to move into
    ///
    case moveImmediate = 1

    /// Move the current position into a register
    ///
    ///     moveCurrentPosition(into: PositionRegister)
    ///
    /// Operands:
    ///   - Position register to move into
    case moveCurrentPosition = 2

    // MARK: General Purpose: Control flow

    /// Branch to a new instruction
    ///
    ///     branch(to: InstAddr)
    ///
    /// Operand: instruction address to branch to
    case branch = 1000

    /// Conditionally branch if zero, otherwise decrement
    ///
    ///     condBranch(
    ///       to: InstAddr, ifZeroElseDecrement: IntReg)
    ///
    /// Operands:
    ///   - Instruction address to branch to, if zero
    ///   - Int register to check for zero, otherwise decrease
    ///
    case condBranchZeroElseDecrement = 3

    /// Conditionally branch if the current position is the same as the register
    ///
    ///     condBranch(
    ///       to: InstAddr, ifSamePositionAs: PositionRegister)
    ///
    /// Operands:
    ///   - Instruction address to branch to, if the position in the register is the same as currentPosition
    ///   - Position register to check against
    case condBranchSamePosition = 4
  
    // TODO: Function calls

    // MARK: - Matching

    /// Advance the input position.
    ///
    ///     advance(_ amount: Distance)
    ///
    /// Operand: Amount to advance by.
    case advance = 5

    // TODO: Is the amount useful here? Is it commonly more than 1?

    /// Composite assert-advance else restore.
    ///
    ///     match(_: EltReg, isCaseInsensitive: Bool)
    ///
    /// Operands:
    ///  - Element register to compare against.
    ///  - Boolean for if we should match in a case insensitive way
    case match = 2000

    /// Match against a scalar and possibly perform a boundary check or match in a case insensitive way
    ///
    ///     matchScalar(_: Unicode.Scalar, isCaseInsensitive: Bool, boundaryCheck: Bool)
    ///
    /// Operands: Scalar value to match against and booleans
    case matchScalar = 2001

    /// Match a character or a scalar against a set of valid ascii values stored in a bitset
    ///
    ///     matchBitset(_: AsciiBitsetRegister, isScalar: Bool)
    ///
    /// Operand:
    ///  - Ascii bitset register containing the bitset
    ///  - Boolean for if we should match by scalar value
    case matchBitset = 2002

    case matchBuiltin = 2003

    // MARK: Extension points

    /// Advance the input position based on the result by calling the consume
    /// function.
    ///
    /// Operand: Consume function register to call.
    case consumeBy = 2004

    /// Lookaround assertion operation. Performs a zero width assertion based on
    /// the assertion type and options stored in the payload
    ///
    ///     assert(_:AssertionPayload)
    ///
    /// Operands: AssertionPayload containing assertion type and options
    case assertBy = 6

    /// Custom value-creating consume operation.
    ///
    ///     match(
    ///       _ matchFunction: (
    ///         input: Input,
    ///         bounds: Range<Position>
    ///       ) -> (Position, Any),
    ///       into: ValueReg
    ///     )
    ///
    ///
    case matchBy = 7

    // MARK: Matching: Save points

    /// Add a save point
    ///
    /// Operand: instruction address to resume from
    ///
    /// A save point is:
    ///   - a position in the input to restore
    ///   - a position in the call stack to cut off
    ///   - an instruction address to resume from
    ///
    /// TODO: Consider if separating would improve generality
    case save = 1001

    ///
    /// Add a save point that doesn't preserve input position
    ///
    /// NOTE: This is a prototype for now, but exposes
    /// flaws in our formulation of back tracking. We could
    /// instead have an instruction to update the top
    /// most saved position instead
    case saveAddress = 8

    /// Remove the most recently saved point
    ///
    /// Precondition: There is a save point to remove
    case clear = 9

    /// Remove save points up to and including the operand
    ///
    /// Operand: instruction address to look for
    ///
    /// Precondition: The operand is in the save point list
    case clearThrough = 10

    /// Fused save-and-branch. 
    ///
    ///   split(to: target, saving: backtrackPoint)
    ///
    case splitSaving = 1002

    /// Fused quantify, execute, save instruction
    /// Quantifies the stored instruction in an inner loop instead of looping through instructions in processor
    /// Only quantifies specific nodes
    ///
    ///     quantify(_:QuantifyPayload)
    ///
    case quantify = 1003
    /// Begin the given capture
    ///
    ///     beginCapture(_:CapReg)
    ///
    case beginCapture = 1004

    /// End the given capture
    ///
    ///     endCapture(_:CapReg)
    ///
    case endCapture = 1005

    /// Transform a captured value, saving the built value
    ///
    ///     transformCapture(_:CapReg, _:TransformReg)
    ///
    case transformCapture = 11

    /// Save a value into a capture register
    ///
    ///     captureValue(_: ValReg, into _: CapReg)
    case captureValue = 12

    /// Match a previously captured value
    ///
    ///     backreference(_:CapReg)
    ///
    case backreference = 13

    // MARK: Matching: State transitions

    // TODO: State transitions need more work. We want
    // granular core but also composite ones that will
    // interact with save points

    /// Transition into ACCEPT and halt
    case accept = 14

    /// Signal failure (currently same as `restore`)
    case fail = 15

    // TODO: Fused assertions. It seems like we often want to
    // branch based on assertion fail or success.
  }
}

extension Instruction.OpCode {
  /// Returns the encoding for this opcode
  /// - if the 8th bit is set, it is a match instruction
  /// - if the 7th bit is set, it is a priority instruction
  /// - otherwise, interpret the entire uint as a number
  var encoded: EncodedOpcode {
    if let encoding = matchInstrEncoding {
      return EncodedOpcode(rawValue: encoding)
    }
    if let encoding = priorityInstrEncoding {
      return EncodedOpcode(rawValue: encoding)
    }
    return EncodedOpcode(rawValue: standardEncoding)
  }
  private var matchInstrBit: UInt64 { 1 << 7 }
  private var matchInstrEncoding: UInt64? {
    switch self {
    case .match:
      return matchInstrBit + 1 << 6
    case .matchScalar:
      return matchInstrBit + 1 << 5
    case .matchBitset:
      return matchInstrBit + 1 << 4
    case .matchBuiltin:
      return matchInstrBit + 1 << 3
    case .consumeBy:
      return matchInstrBit + 1 << 2
    // what other cases belong here? should this just be left open for future instrs?
    // or should the payload bits propagate here
    default:
      return nil
    }
  }
  private var priorityInstrBit: UInt64 { 1 << 6 }
  private var priorityInstrEncoding: UInt64? {
    switch self {
    case .splitSaving:
      return priorityInstrBit + 1 << 5
    case .branch:
      return priorityInstrBit + 1 << 4
    case .quantify:
      return priorityInstrBit + 1 << 3
    case .save:
      return priorityInstrBit + 1 << 2
      // is begin capture high enough priority?
    case .beginCapture:
      return priorityInstrBit + 1 << 1
    case .endCapture:
      return priorityInstrBit + 1 << 0
      // one more case can fit here, but what?
    default:
      return nil
    }
  }
  private var standardEncoding: UInt64 {
    assert(matchInstrEncoding == nil)
    assert(priorityInstrEncoding == nil)
    let raw = rawValue
    assert(raw < 1 << 6)
    return raw
  }
}

struct EncodedOpcode: RawRepresentable, Equatable {
  let rawValue: UInt64
}

extension EncodedOpcode {
  // fixme: if i switch on these values instead, will swift generate the right code?
  var isMatchInstr: Bool { (rawValue >> 7) & 1 == 1 }
  var isMatch: Bool {
    assert(isMatchInstr)
    return (rawValue >> 6) & 1 == 1
  }
  var isMatchScalar: Bool {
    assert(isMatchInstr)
    return (rawValue >> 5) & 1 == 1
  }
  var isMatchBitset: Bool {
    assert(isMatchInstr)
    return (rawValue >> 4) & 1 == 1
  }
  var isMatchBuiltin: Bool {
    assert(isMatchInstr)
    return (rawValue >> 3) & 1 == 1
  }
  var isConsumeBy: Bool {
    assert(isMatchInstr)
    return (rawValue >> 2) & 1 == 1
  }
  var isPriorityInstr: Bool { (rawValue >> 6) & 1 == 1 }
  var isSplitSaving: Bool {
    assert(isPriorityInstr)
    return (rawValue >> 5) & 1 == 1
  }
  var isBranch: Bool {
    assert(isPriorityInstr)
    return (rawValue >> 4) & 1 == 1
  }
  var isQuantify: Bool {
    assert(isPriorityInstr)
    return (rawValue >> 3) & 1 == 1
  }
  var isSave: Bool {
    assert(isPriorityInstr)
    return (rawValue >> 2) & 1 == 1
  }
  var isBeginCapture: Bool {
    assert(isPriorityInstr)
    return (rawValue >> 1) & 1 == 1
  }
  var isEndCapture: Bool {
    assert(isPriorityInstr)
    return rawValue & 1 == 1
  }
  private var defaultDecode: Instruction.OpCode {
    assert(rawValue < (1 << 6))
    return Instruction.OpCode.init(rawValue: rawValue).unsafelyUnwrapped
  }
  /// Decode back to a standard enum value
  var decoded: Instruction.OpCode {
    if isMatchInstr {
      if isMatch { return .match }
      if isMatchScalar { return .matchScalar }
      if isMatchBitset { return .matchBitset }
      if isMatchBuiltin { return .matchBuiltin }
      if isConsumeBy { return .consumeBy}
      fatalError()
    }
    if isPriorityInstr {
      if isSplitSaving { return .splitSaving }
      if isSave { return .save }
      if isBranch { return .branch }
      if isQuantify { return .quantify }
      if isBeginCapture { return .beginCapture }
      if isEndCapture { return .endCapture }
      fatalError()
    }
    return defaultDecode
  }
}

internal var _opcodeMask: UInt64 { 0xFF00_0000_0000_0000 }

var _payloadMask: UInt64 { ~_opcodeMask }

extension Instruction {
  var opcodeMask: UInt64 { 0xFF00_0000_0000_0000 }

  var opcode: EncodedOpcode {
    get { EncodedOpcode(rawValue: (rawValue & _opcodeMask) >> 56) }
    set {
      assert(newValue.rawValue < 256)
      self.rawValue &= ~_opcodeMask
      self.rawValue |= newValue.rawValue &<< 56
    }
  }
  var payload: Payload {
    get { Payload(rawValue: rawValue & ~opcodeMask) }
    set {
      self.rawValue &= opcodeMask
      self.rawValue |= newValue.rawValue
    }
  }

  var destructure: (opcode: EncodedOpcode, payload: Payload) {
    (opcode, payload)
  }

  init(_ opcode: OpCode, _ payload: Payload/* = Payload()*/) {
    self.init(rawValue: 0)
    self.opcode = opcode.encoded
    self.payload = payload
    // TODO: check invariants
  }
  init(_ opcode: EncodedOpcode, _ payload: Payload/* = Payload()*/) {
    self.init(rawValue: 0)
    self.opcode = opcode
    self.payload = payload
    // TODO: check invariants
  }
  init(_ opcode: OpCode) {
    self.init(rawValue: 0)
    self.opcode = opcode.encoded
    //self.payload = payload
    // TODO: check invariants
    // TODO: placeholder bit pattern for fill-in-later
  }
}

/*

 This is in need of more refactoring and design, the following
 are a rough listing of TODOs:

 - Save point and call stack interactions should be more formalized.
 - It's too easy to have unbalanced save/clears amongst function calls
 - Nominal type for conditions with an invert bit
 - Better bit allocation and layout for operand, instruction, etc
 - Use spare bits for better assertions
 - Check low-level compiler code gen for switches
 - Consider relative addresses instead of absolute addresses
 - Explore a predication bit
 - Explore using SIMD
 - Explore a larger opcode, so that we can have variant flags
   - E.g., opcode-local bits instead of flattening opcode space

 We'd like to eventually design:

 - A general-purpose core (future extensibility)
 - A matching-specific instruction area carved out
 - Leave a large area for future usage of run-time bytecode interpretation
 - Debate: allow for future variable-width instructions

 We'd like a testing / performance setup that lets us

 - Define new instructions in terms of old ones (testing, perf)
 - Version our instruction set in case we need future fixes

 */

// TODO: replace with instruction formatters...
extension Instruction {
  var instructionAddress: InstructionAddress? {
    switch opcode {
    case OpCode.branch.encoded, OpCode.save.encoded, OpCode.saveAddress.encoded:
      return payload.addr
    default: return nil
    }
  }
  var elementRegister: ElementRegister? {
    switch opcode {
    case OpCode.match.encoded:
      return payload.elementPayload.1
    default: return nil
    }
  }
  var consumeFunctionRegister: ConsumeFunctionRegister? {
    switch opcode {
    case OpCode.consumeBy.encoded: return payload.consumer
    default: return nil
    }
  }

}

extension Instruction: InstructionProtocol {
  var operandPC: InstructionAddress? { instructionAddress }
}


// TODO: better names for accept/fail/etc. Instruction
// conflates backtracking with signaling failure or success,
// could be clearer.
enum State {
  /// Still running
  case inProgress

  /// FAIL: halt and signal failure
  case fail

  /// ACCEPT: halt and signal success
  case accept
}
