import os.signpost

final public class OSSignpostController {
    private let log: OSLog
    private let name: StaticString
    public var signpostsEnabled: Bool = false

    init(subsystem: String = "com.zenangst.Family",
         category: String,
         name: StaticString = #function,
         signpostsEnabled: Bool) {
        self.log = OSLog(subsystem: subsystem, category: category)
        self.name = name
        self.signpostsEnabled = signpostsEnabled
    }

    func signpost(_ type: SignpostType, _ message: @autoclosure () -> String) {
        guard signpostsEnabled else { return }
        let suffix: String

        switch type {
        case .begin:
            suffix = " - begin"
        case .end:
            suffix = " - end"
        case .event:
            suffix = ""
        }

        let message = "\(message())\(suffix)"

        signpost(type, "%{public}s", message)
    }

    func signpost(_ type: SignpostType, _ format: StaticString, _ argument: CVarArg) {
        guard signpostsEnabled else { return }
        if #available(OSX 10.14, iOS 12.0, watchOS 5.0, tvOS 12.0, *) {
            os_signpost(type.os, log: log, name: name, signpostID: signpostID, format, argument)
        }
    }

    @available(OSX 10.14, iOS 12.0, watchOS 5.0, tvOS 12.0, *)
    var signpostID: OSSignpostID {
        OSSignpostID(log: log, object: self)
    }
}

enum SignpostType {
    case begin, event, end

    @available(OSX 10.14, iOS 12.0, watchOS 5.0, tvOS 12.0, *)
    var os: OSSignpostType {
        switch self {
        case .begin: return .begin
        case .event: return .event
        case .end: return .end
        }
    }
}
