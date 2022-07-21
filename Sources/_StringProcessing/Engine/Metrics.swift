extension Processor {
  struct ProcessorMetrics {
    var instructionCounts: [Instruction.OpCode: Int] = [:]
    var caseInsensitiveInstrs: Bool = false
  }
  
  func printMetrics() {
    // print("Total cycle count: \(cycleCount)")
    // print("Instructions:")
    let sorted = metrics.instructionCounts
      .filter({$0.1 != 0})
      .sorted(by: { (a,b) in a.1 > b.1 })
    for (opcode, count) in sorted {
      print("\(opcode),\(count)")
    }
  }

  mutating func measure() {
    let (encoded, _) = fetch().destructure
    let opcode = encoded.decoded
    if metrics.instructionCounts.keys.contains(opcode) {
      metrics.instructionCounts[opcode]! += 1
    } else {
      metrics.instructionCounts.updateValue(1, forKey: opcode)
    }
  }
  
  mutating func measureMetrics() {
    if shouldMeasureMetrics {
      measure()
    }
  }
}
