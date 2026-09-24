import Testing
@testable import SoundforkCore

@Test func printableCodesRenderAsFourChars() {
    #expect(fourCC(0x7072_7323) == "'prs#'")
}

@Test func unprintableCodesRenderAsNumbers() {
    #expect(fourCC(1) == "1")
}
