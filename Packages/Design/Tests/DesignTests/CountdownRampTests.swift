import Testing
@testable import Design

private func approxEqual(_ a: CountdownRamp.RGB, _ b: CountdownRamp.RGB, tolerance: Double = 1e-6) -> Bool {
    abs(a.r - b.r) < tolerance && abs(a.g - b.g) < tolerance && abs(a.b - b.b) < tolerance
}

struct CountdownRampTests {
    @Test func staysGreenUntilHalfway() {
        #expect(approxEqual(CountdownRamp.background(fractionElapsed: 0, increaseContrast: false), (0.20, 0.78, 0.35)))
        #expect(approxEqual(CountdownRamp.background(fractionElapsed: 0.49, increaseContrast: false), (0.20, 0.78, 0.35)))
    }

    @Test func passesThroughAmberRatherThanJumpingStraightToRed() {
        // Exactly at the green/amber-to-amber/red boundary (80% elapsed),
        // the ramp must actually be at amber.
        let atBoundary = CountdownRamp.background(fractionElapsed: 0.8, increaseContrast: false)
        #expect(approxEqual(atBoundary, (0.95, 0.70, 0.10)))
    }

    @Test func rampIsContinuousNoDiscontinuousJumps() {
        // A direct green→red jump would show up as a large delta between
        // adjacent samples. A proper ramp's per-step delta stays small and
        // bounded by the step size, everywhere — including across the
        // green/amber and amber/red boundaries.
        let step = 0.02
        let samples = stride(from: 0.0, through: 1.0, by: step).map {
            CountdownRamp.background(fractionElapsed: $0, increaseContrast: false)
        }
        for i in 1..<samples.count {
            #expect(abs(samples[i].r - samples[i - 1].r) < 0.08)
            #expect(abs(samples[i].g - samples[i - 1].g) < 0.08)
            #expect(abs(samples[i].b - samples[i - 1].b) < 0.08)
        }
    }

    @Test func reachesPureRedAtExpiry() {
        let atExpiry = CountdownRamp.background(fractionElapsed: 1.0, increaseContrast: false)
        #expect(approxEqual(atExpiry, (0.90, 0.20, 0.20)))
    }

    @Test func increaseContrastProducesThreeFlatStepsNotAGradient() {
        // Anywhere within a band, the colour must be identical — no
        // interpolation — for Increase Contrast.
        let earlyGreen = CountdownRamp.background(fractionElapsed: 0.1, increaseContrast: true)
        let lateGreen = CountdownRamp.background(fractionElapsed: 0.49, increaseContrast: true)
        #expect(approxEqual(earlyGreen, lateGreen))

        let earlyAmber = CountdownRamp.background(fractionElapsed: 0.51, increaseContrast: true)
        let lateAmber = CountdownRamp.background(fractionElapsed: 0.79, increaseContrast: true)
        #expect(approxEqual(earlyAmber, lateAmber))
        #expect(!approxEqual(earlyAmber, earlyGreen))

        let red = CountdownRamp.background(fractionElapsed: 0.9, increaseContrast: true)
        #expect(approxEqual(red, (0.90, 0.20, 0.20)))
    }

    /// PRD §3.3 — "Maintain WCAG AA contrast for the digits against every
    /// point of the gradient." AA requires ≥4.5:1 for normal text (our
    /// digits, at display sizes, would also clear the 3:1 large-text bar,
    /// but 4.5:1 is the stronger claim and the one we hold ourselves to).
    @Test func digitContrastMeetsWCAG_AA_AcrossTheWholeRamp() {
        for i in 0...100 {
            let fraction = Double(i) / 100
            for increaseContrast in [false, true] {
                let bg = CountdownRamp.background(fractionElapsed: fraction, increaseContrast: increaseContrast)
                let fg = CountdownRamp.foreground(fractionElapsed: fraction, increaseContrast: increaseContrast)
                let contrast = CountdownRamp.contrastRatio(
                    CountdownRamp.relativeLuminance(bg),
                    CountdownRamp.relativeLuminance(fg)
                )
                #expect(contrast >= 4.5, "fraction \(fraction) (increaseContrast: \(increaseContrast)) only reaches \(contrast):1")
            }
        }
    }

    @Test func foregroundIsAlwaysPureBlackOrPureWhite() {
        for i in 0...20 {
            let fg = CountdownRamp.foreground(fractionElapsed: Double(i) / 20, increaseContrast: false)
            #expect(fg == (0, 0, 0) || fg == (1, 1, 1))
        }
    }

    @Test func fractionIsClampedOutsideZeroToOne() {
        #expect(CountdownRamp.background(fractionElapsed: -5, increaseContrast: false) == CountdownRamp.background(fractionElapsed: 0, increaseContrast: false))
        #expect(CountdownRamp.background(fractionElapsed: 5, increaseContrast: false) == CountdownRamp.background(fractionElapsed: 1, increaseContrast: false))
    }
}
