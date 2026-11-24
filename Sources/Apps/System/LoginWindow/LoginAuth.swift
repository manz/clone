import Foundation

// Linux login: authenticate the entered password against PAM before signalling
// the compositor that the session is ready. PAM's stack runs pam_systemd, so a
// successful auth is what registers/validates the logind session + seat, the
// same role macOS loginwindow plays. Loaded via dlopen so the app (built by
// ycodebuild against the SDK frameworks) needs no extra linked target.
//
// macOS / dev builds have no PAM stack to gate against, so authentication is a
// no-op there and any password is accepted.

#if os(Linux)
import Glibc

// struct pam_message { int msg_style; const char *msg; }
private struct CPamMessage {
    var msg_style: Int32
    var msg: UnsafePointer<CChar>?
}

// struct pam_response { char *resp; int resp_retcode; }
private struct CPamResponse {
    var resp: UnsafeMutablePointer<CChar>?
    var resp_retcode: Int32
}

// The conv callback C type:
//   int (*)(int, const struct pam_message **, struct pam_response **, void *)
// The message/response pointers must be RAW here: a @convention(c) signature
// can't carry typed pointers to Swift structs. We reinterpret them inside.
private typealias PamConvFn = @convention(c) (
    Int32,
    UnsafePointer<UnsafeRawPointer?>?,            // const pam_message **
    UnsafeMutablePointer<UnsafeMutableRawPointer?>?, // pam_response **
    UnsafeMutableRawPointer?
) -> Int32

// struct pam_conv { int (*conv)(...); void *appdata_ptr; }
private struct CPamConv {
    var conv: PamConvFn
    var appdata_ptr: UnsafeMutableRawPointer?
}

private let PAM_SUCCESS: Int32 = 0
private let PAM_PROMPT_ECHO_OFF: Int32 = 1
private let PAM_PROMPT_ECHO_ON: Int32 = 2
private let PAM_CONV_ERR: Int32 = 19

// PAM conversation callback. For every prompt the stack issues, hand back the
// password carried in appdata_ptr. PAM takes ownership of the strdup'd buffers
// and frees them, so the response array is calloc'd, not Swift-managed.
private func clonePamConv(
    numMsg: Int32,
    msgs: UnsafePointer<UnsafeRawPointer?>?,
    resp: UnsafeMutablePointer<UnsafeMutableRawPointer?>?,
    appdata: UnsafeMutableRawPointer?
) -> Int32 {
    guard numMsg > 0, let resp = resp else { return PAM_CONV_ERR }
    let n = Int(numMsg)
    guard let raw = calloc(n, MemoryLayout<CPamResponse>.stride) else { return PAM_CONV_ERR }
    let replies = raw.assumingMemoryBound(to: CPamResponse.self)
    let password = appdata.map { String(cString: $0.assumingMemoryBound(to: CChar.self)) } ?? ""

    for i in 0..<n {
        // msgs[i] is a raw pointer to a pam_message; reinterpret to read msg_style.
        let style = (msgs?[i] ?? nil)?
            .assumingMemoryBound(to: CPamMessage.self).pointee.msg_style ?? 0
        if style == PAM_PROMPT_ECHO_OFF || style == PAM_PROMPT_ECHO_ON {
            replies[i].resp = strdup(password)
        }
        replies[i].resp_retcode = 0
    }
    resp.pointee = raw
    return PAM_SUCCESS
}

// The conv arg is `&CPamConv`, but CPamConv holds a function pointer so a typed
// `UnsafePointer<CPamConv>` isn't representable in a @convention(c) signature.
// Pass it as a raw pointer (ABI-identical); `&conv` converts at the call site.
private typealias PamStartFn = @convention(c) (
    UnsafePointer<CChar>, UnsafePointer<CChar>?,
    UnsafeRawPointer, UnsafeMutablePointer<OpaquePointer?>
) -> Int32
private typealias PamAuthFn = @convention(c) (OpaquePointer?, Int32) -> Int32
private typealias PamEndFn = @convention(c) (OpaquePointer?, Int32) -> Int32

enum LoginAuth {
    static func authenticate(user: String, password: String) -> Bool {
        guard let lib = dlopen("libpam.so.0", RTLD_NOW) else { return false }
        defer { dlclose(lib) }

        guard
            let startSym = dlsym(lib, "pam_start"),
            let authSym = dlsym(lib, "pam_authenticate"),
            let acctSym = dlsym(lib, "pam_acct_mgmt"),
            let endSym = dlsym(lib, "pam_end")
        else { return false }

        let pamStart = unsafeBitCast(startSym, to: PamStartFn.self)
        let pamAuth = unsafeBitCast(authSym, to: PamAuthFn.self)
        let pamAcct = unsafeBitCast(acctSym, to: PamAuthFn.self)
        let pamEnd = unsafeBitCast(endSym, to: PamEndFn.self)

        let appdata = strdup(password)
        defer { free(appdata) }

        var conv = CPamConv(conv: clonePamConv, appdata_ptr: UnsafeMutableRawPointer(appdata))
        var handle: OpaquePointer? = nil

        let started = user.withCString { u in
            "login".withCString { svc in
                pamStart(svc, u, &conv, &handle)
            }
        }
        guard started == PAM_SUCCESS else { return false }
        defer { _ = pamEnd(handle, started) }

        guard pamAuth(handle, 0) == PAM_SUCCESS else { return false }
        // Account valid (not expired / locked), required by the logind handoff.
        return pamAcct(handle, 0) == PAM_SUCCESS
    }
}

#else

enum LoginAuth {
    // No PAM stack off-Linux: dev builds accept any password.
    static func authenticate(user: String, password: String) -> Bool { true }
}

#endif

// Bring up the authenticated user's session (Dock, MenuBar, Finder), the way
// loginwindow hands off to the Aqua session on macOS. LoginWindow runs as root,
// so it reaches into the target user's systemd --user manager (kept ready by
// `linger`) and starts clone-session.target there. The session apps then run as
// that user and connect to the persistent compositor over /run/clone.
// macOS / dev: no-op (the compositor self-spawns the session apps).
enum SessionLauncher {
    static func startSession(user: String) {
        #if os(Linux)
        guard ProcessInfo.processInfo.environment["CLONE_SESSION_EXTERNAL"] != nil else { return }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        // --machine=<user>@.host targets that user's --user manager (root only).
        proc.arguments = ["systemctl", "--user", "--machine=\(user)@.host", "start", "clone-session.target"]
        proc.standardError = FileHandle.standardError
        do {
            try proc.run()
        } catch {
            FileHandle.standardError.write(Data("LoginWindow: failed to start clone-session.target for \(user): \(error)\n".utf8))
        }
        #endif
    }
}
