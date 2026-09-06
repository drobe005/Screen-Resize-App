import CoreGraphics

/// The single source of truth for resolution presets.
///
/// UI code reads from here and never spells out a resolution of its own. See
/// CLAUDE.md, "Resolution presets live in a single data model".
///
/// Every value is in physical pixels. A group's `heading` is a human-facing
/// label, not an aspect ratio to be parsed — see `AspectRatioGroup`.
public enum ResolutionCatalog {

    public static let groups: [AspectRatioGroup] = [
        AspectRatioGroup(heading: "16:9", resolutions: [
            Resolution(name: "1280x720",  pixelSize: PixelSize(widthInPixels: 1280, heightInPixels: 720),  label: "720p / HD"),
            Resolution(name: "1920x1080", pixelSize: PixelSize(widthInPixels: 1920, heightInPixels: 1080), label: "1080p / Full HD"),
            Resolution(name: "2560x1440", pixelSize: PixelSize(widthInPixels: 2560, heightInPixels: 1440), label: "1440p / QHD"),
            Resolution(name: "3840x2160", pixelSize: PixelSize(widthInPixels: 3840, heightInPixels: 2160), label: "4K UHD"),
            Resolution(name: "7680x4320", pixelSize: PixelSize(widthInPixels: 7680, heightInPixels: 4320), label: "8K UHD"),
        ]),
        AspectRatioGroup(heading: "16:10", resolutions: [
            Resolution(name: "1920x1200", pixelSize: PixelSize(widthInPixels: 1920, heightInPixels: 1200), label: "WUXGA"),
            Resolution(name: "2560x1600", pixelSize: PixelSize(widthInPixels: 2560, heightInPixels: 1600), label: "WQXGA"),
        ]),
        AspectRatioGroup(heading: "3:2", resolutions: [
            Resolution(name: "2160x1440", pixelSize: PixelSize(widthInPixels: 2160, heightInPixels: 1440)),
            Resolution(name: "3000x2000", pixelSize: PixelSize(widthInPixels: 3000, heightInPixels: 2000)),
        ]),
        // Neither of these is actually 21:9 (2.333). 2560x1080 is 64:27 (2.370)
        // and 3440x1440 is 43:18 (2.389). The heading is what the panels are
        // marketed as; the math always uses each resolution's own numbers.
        AspectRatioGroup(heading: "21:9", resolutions: [
            Resolution(name: "2560x1080", pixelSize: PixelSize(widthInPixels: 2560, heightInPixels: 1080), label: "UW-FHD"),
            Resolution(name: "3440x1440", pixelSize: PixelSize(widthInPixels: 3440, heightInPixels: 1440), label: "UW-QHD"),
        ]),
        AspectRatioGroup(heading: "4:3", resolutions: [
            Resolution(name: "640x480",   pixelSize: PixelSize(widthInPixels: 640,  heightInPixels: 480),  label: "VGA"),
            Resolution(name: "1024x768",  pixelSize: PixelSize(widthInPixels: 1024, heightInPixels: 768),  label: "XGA"),
            Resolution(name: "1600x1200", pixelSize: PixelSize(widthInPixels: 1600, heightInPixels: 1200), label: "UXGA"),
        ]),
    ]

    /// Every resolution across every group, flattened.
    public static var allResolutions: [Resolution] { groups.flatMap(\.resolutions) }
}
