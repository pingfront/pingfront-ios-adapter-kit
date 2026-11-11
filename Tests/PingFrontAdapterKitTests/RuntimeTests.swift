import Foundation
import Observation
import PingFrontAdapterKit
import PingFrontAdapterTestSupport
import Testing
import os

@Observable @MainActor final class TokenBox {
    var token: UUID?
}

/// Counts sleeps, and fails once `failAfter` is reached (as a cancelled task's sleep would).
final class SleepCounter: Sendable {
    private let count = OSAllocatedUnfairLock(initialState: 0)
    let failAfter: Int?
    init(failAfter: Int? = nil) { self.failAfter = failAfter }
    var sleeps: Int { count.withLock { $0 } }
    var sleep: Sleep {
        { [self] _ in
            let n = count.withLock { value -> Int in
                value += 1
                return value
            }
            if let failAfter, n >= failAfter { throw CancellationError() }
        }
    }
}

@Suite("Runtime")
@MainActor struct RuntimeTests {
    @Test("Readiness waits until the vendor is configured")
    func waits() async {
        var checks = 0
        let ready = await Readiness.wait(
            until: {
                checks += 1
                return checks >= 4
            }, sleep: noSleep)
        #expect(ready)
        #expect(checks == 4)
    }

    @Test("Readiness gives up after its attempts, and when the task is cancelled")
    func givesUp() async {
        let counter = SleepCounter()
        #expect(await Readiness.wait(until: { false }, sleep: counter.sleep, attempts: 5) == false)
        #expect(counter.sleeps == 5)
        let cancelled = SleepCounter(failAfter: 2)
        #expect(await Readiness.wait(until: { false }, sleep: cancelled.sleep) == false)
        #expect(cancelled.sleeps == 2)
    }

    @Test("ResumeOnce resumes the first time only")
    func resumesOnce() async {
        let value: Int = await withCheckedContinuation { (continuation: CheckedContinuation<Int, Never>) in
            let once = ResumeOnce(continuation)
            once.resume(1)
            once.resume(2)
        }
        #expect(value == 1)
    }

    @Test("Observed values start with the current value and follow changes, skipping repeats")
    func observes() async {
        let box = TokenBox()
        var seen: [UUID?] = []
        let stream = observedValues { box.token }
        let task = Task { @MainActor in
            for await token in stream { seen.append(token) }
        }
        #expect(await settle { seen.count == 1 })
        box.token = sampleToken
        #expect(await settle { seen.count == 2 })
        box.token = sampleToken
        box.token = nil
        #expect(await settle { seen.count == 3 })
        task.cancel()
        #expect(seen == [nil, sampleToken, nil])
    }
}
