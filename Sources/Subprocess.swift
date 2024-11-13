import Foundation

actor Subprocess {
    static let DEBUG = false

    init(path: String) {
        if Self.DEBUG {
            print("Subprocess: initializing with path: \(path)")
        }
        let u = URL(fileURLWithPath: path)

        process = Process()
        process.executableURL = u

        input = Pipe()
        output = Pipe()
        error = Pipe()

        // let tmp = Pipe()
        //
        // let p2 = Process()
        // p2.executableURL = URL(fileURLWithPath: "/usr/bin/tee")
        // p2.standardOutput = output
        // p2.standardInput = tmp
        // p2.arguments = ["-a", "/tmp/\(UInt8.random(in: 0...250))"]
        // p2.launch()
        // print("\(path) -> \(p2.arguments![1])")

        process.standardInput = input
        process.standardOutput = output
        // process.standardOutput = tmp
        // process.standardError = FileHandle.standardError
        process.standardError = error
    }

    func start() {
        if Self.DEBUG {
            print("Subprocess: will launch")
        }
        process.launch()
        if Self.DEBUG {
            print("Subprocess: did launch")
        }
    }

    func stop() {
        if Self.DEBUG {
            print("Subprocess: will interrupt")
        }
        process.interrupt()
        if Self.DEBUG {
            print("Subprocess: did interrupt")
        }
    }

    func readNextLine() async throws -> String {
        if Self.DEBUG {
            print("Subprocess: will read line")
        }
        var it = output.fileHandleForReading.bytes.lines.makeAsyncIterator()
        return try await it.next()!
    }

    func write(_ data: Data, addNewline: Bool = true) {
        if Self.DEBUG {
            print("Subprocess: will write")
        }
        var data = data
        if addNewline {
            data.append(10)
        }
        input.fileHandleForWriting.write(data)
        if Self.DEBUG {
            print("Subprocess: did write")
        }
    }

    private let process: Process
    private let input: Pipe
    private let output: Pipe
    private let error: Pipe
}
