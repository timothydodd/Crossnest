import Foundation

/// Installs ~/Library/KeyBindings/DefaultKeyBinding.dict so Home/End, Ctrl+arrows and friends
/// behave like Windows in standard Mac text fields (Notes, Mail, Safari forms, TextEdit…).
/// Any file the user already had is moved aside and restored on uninstall.
enum KeyBindings {
    private static let marker = "Crossnest"

    static var fileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/KeyBindings/DefaultKeyBinding.dict")
    }

    private static var backupURL: URL {
        BackupStore.directory.appending(path: "DefaultKeyBinding.dict.original")
    }

    static var isInstalled: Bool {
        guard let text = try? String(contentsOf: fileURL, encoding: .utf8) else { return false }
        return text.contains(marker)
    }

    static func install() throws {
        let fm = FileManager.default
        try fm.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fm.fileExists(atPath: fileURL.path), !isInstalled {
            try fm.createDirectory(at: BackupStore.directory, withIntermediateDirectories: true)
            try? fm.removeItem(at: backupURL)
            try fm.copyItem(at: fileURL, to: backupURL)
        }
        try contents.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    static func uninstall() throws {
        guard isInstalled else { return }
        let fm = FileManager.default
        try fm.removeItem(at: fileURL)
        if fm.fileExists(atPath: backupURL.path) {
            try fm.moveItem(at: backupURL, to: fileURL)
        }
    }

    private static let contents = #"""
    /* Crossnest: PC-style navigation keys for standard Mac text fields.
       Remove it from the Crossnest app (Keyboard > Home and End keys) rather than editing by hand. */
    {
      "\UF729"   = moveToBeginningOfLine:;                       /* Home */
      "\UF72B"   = moveToEndOfLine:;                             /* End */
      "$\UF729"  = moveToBeginningOfLineAndModifySelection:;     /* Shift+Home */
      "$\UF72B"  = moveToEndOfLineAndModifySelection:;           /* Shift+End */
      "^\UF729"  = moveToBeginningOfDocument:;                   /* Ctrl+Home */
      "^\UF72B"  = moveToEndOfDocument:;                         /* Ctrl+End */
      "^$\UF729" = moveToBeginningOfDocumentAndModifySelection:; /* Ctrl+Shift+Home */
      "^$\UF72B" = moveToEndOfDocumentAndModifySelection:;       /* Ctrl+Shift+End */
      "\UF72C"   = pageUp:;                                      /* Page Up */
      "\UF72D"   = pageDown:;                                    /* Page Down */
      "$\UF72C"  = pageUpAndModifySelection:;
      "$\UF72D"  = pageDownAndModifySelection:;
      "^\UF702"  = moveWordBackward:;                            /* Ctrl+Left */
      "^\UF703"  = moveWordForward:;                             /* Ctrl+Right */
      "^$\UF702" = moveWordBackwardAndModifySelection:;
      "^$\UF703" = moveWordForwardAndModifySelection:;
      "^\U007F"  = deleteWordBackward:;                          /* Ctrl+Backspace */
      "^\UF728"  = deleteWordForward:;                           /* Ctrl+Delete */
    }

    """#
}
