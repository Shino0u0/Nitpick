import Foundation
import Testing
@testable import Vortext

struct PromptAssemblerTests {
    private let assembler = PromptAssembler()

    @Test func instructionsGoToSystemTranscriptToUser() {
        let messages = assembler.assemble(
            instructions: "Rewrite as a formal email.",
            transcript: "hey can we move the meeting",
            context: ContextSnapshot(),
            hasProtectedValues: false,
            attachScreenshot: false
        )
        #expect(messages.first?.role == .system)
        #expect(messages.first?.text.contains("Rewrite as a formal email.") == true)
        #expect(messages.last?.role == .user)
        #expect(messages.last?.text.contains("hey can we move the meeting") == true)
    }

    @Test func systemMessageStatesContextIsUntrustedData() {
        let messages = assembler.assemble(
            instructions: "x",
            transcript: "t",
            context: ContextSnapshot(clipboardText: "some clip"),
            hasProtectedValues: false,
            attachScreenshot: false
        )
        let system = messages.first!.text.lowercased()
        #expect(system.contains("data"))
        #expect(system.contains("must not") || system.contains("never"))
    }

    @Test func contextBlocksAreDelimitedAndSeparateFromInstructions() {
        let messages = assembler.assemble(
            instructions: "Improve the text.",
            transcript: "t",
            context: ContextSnapshot(
                appName: "Safari",
                clipboardText: "clip contents",
                localTime: "2026-08-16 10:00"
            ),
            hasProtectedValues: false,
            attachScreenshot: false
        )
        let user = messages.last!.text
        #expect(user.contains("[BEGIN UNTRUSTED CONTEXT]"))
        #expect(user.contains("[END UNTRUSTED CONTEXT]"))
        #expect(user.contains("Safari"))
        #expect(user.contains("clip contents"))
        #expect(user.contains("2026-08-16 10:00"))
        // Instructions never leak into the user context block.
        #expect(!user.contains("Improve the text."))
    }

    @Test func emptyContextProducesNoContextBlock() {
        let messages = assembler.assemble(
            instructions: "x",
            transcript: "t",
            context: ContextSnapshot(),
            hasProtectedValues: false,
            attachScreenshot: false
        )
        #expect(!messages.last!.text.contains("[BEGIN UNTRUSTED CONTEXT]"))
    }

    @Test func truncatedClipboardIsMarked() {
        let messages = assembler.assemble(
            instructions: "x",
            transcript: "t",
            context: ContextSnapshot(clipboardText: "abc", clipboardTruncated: true),
            hasProtectedValues: false,
            attachScreenshot: false
        )
        #expect(messages.last!.text.contains("truncated"))
    }

    @Test func protectedValueInstructionOnlyWhenPlaceholdersExist() {
        let with = assembler.assemble(
            instructions: "x", transcript: "t", context: ContextSnapshot(),
            hasProtectedValues: true, attachScreenshot: false
        )
        let without = assembler.assemble(
            instructions: "x", transcript: "t", context: ContextSnapshot(),
            hasProtectedValues: false, attachScreenshot: false
        )
        #expect(with.first!.text.contains("⟦"))
        #expect(!without.first!.text.contains("⟦"))
    }

    @Test func screenshotAttachedOnlyWhenRequested() {
        let png = Data([0x89, 0x50, 0x4E, 0x47])
        let attached = assembler.assemble(
            instructions: "x", transcript: "t",
            context: ContextSnapshot(screenPNG: png),
            hasProtectedValues: false, attachScreenshot: true
        )
        #expect(attached.last!.imagePNG == png)

        let notAttached = assembler.assemble(
            instructions: "x", transcript: "t",
            context: ContextSnapshot(screenPNG: png),
            hasProtectedValues: false, attachScreenshot: false
        )
        #expect(notAttached.last!.imagePNG == nil)
    }

    @Test func usedSourcesReflectPopulatedFields() {
        let snapshot = ContextSnapshot(
            appName: "Mail", clipboardText: "c", localTime: "now",
            screenPNG: Data([0x01])
        )
        #expect(Set(snapshot.usedSources) == Set([.app, .clipboard, .time, .screen]))
        #expect(ContextSnapshot().usedSources.isEmpty)
    }
}
