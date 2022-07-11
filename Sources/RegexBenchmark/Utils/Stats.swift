import Foundation

enum Stats {}

extension Stats {
  // 300µs, maybe this should be a % of the runtime for each benchmark?
  static let maxAllowedStdev = 300e-6

  static func tTest(_ a: BenchmarkResult, _ b: BenchmarkResult) -> Bool {
    // Welch's t-test
    let numerator = a.median.seconds - b.median.seconds
    let denominator = ( pow(a.stdev, 2)/Double(a.samples) + pow(b.stdev, 2)/Double(b.samples) ).squareRoot()
    let tVal = numerator / denominator
    // just use a hardcoded constatnt instead of a full t-table
    // we don't need to be absolutely statistically sure, just an approximation
    // is good enough for us
    return abs(tVal) > 1.5
  }
}
