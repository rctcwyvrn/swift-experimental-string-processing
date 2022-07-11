import _StringProcessing

extension BenchmarkRunner {
  mutating func addBuiltinCC() {
    let basic = CrossBenchmark(
      baseName:
        "BasicBuiltinCharacterClass",
      regex: #"\d\w"#,
      input: Inputs.graphemeBreakData)
    
    // An imprecise email matching regex using mostly builtin character classes
    let email = CrossBenchmark(
      baseName:
        "EmailBuiltinCharacterClass",
      regex: #"(?:\d|\w|\.|-|_|%|\+)+@(?:\d|\w|\.|-|_|%|\+)+"#,
      input: Inputs.validEmails)
    basic.register(&self)
    email.register(&self)
  }
}
