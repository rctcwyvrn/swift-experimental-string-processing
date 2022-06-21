// This file has lines generated by createBenchmark.py
// Do not remove the start of registration or end of registration markers

extension BenchmarkRunner {
  public static func makeRunner(
    _ samples: Int,
    _ outputPath: String
  ) -> BenchmarkRunner {
    var benchmark = BenchmarkRunner("RegexBench", samples, outputPath)
    // -- start of registrations --
    benchmark.addReluctantQuant()
    benchmark.addCSS()
    benchmark.addNotFound()
    benchmark.addGraphemeBreak()
    benchmark.addHangulSyllable()
    benchmark.addHTML()
    benchmark.addEmail()
    // -- end of registrations --
    return benchmark
  }
}
