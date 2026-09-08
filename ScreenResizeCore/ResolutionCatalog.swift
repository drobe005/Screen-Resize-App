import CoreGraphics

/// The single source of truth for resolution presets.
///
/// UI code reads from here and never spells out a resolution of its own. See
/// CLAUDE.md, "Resolution presets live in a single data model".
///
/// Every value is in physical pixels. The list is deliberately flat and ordered
/// largest first: grouping by aspect ratio was removed because it added a layer
/// of navigation without adding information — the dimensions already tell you
/// the shape, and a hover to reach a size is a hover too many.
public enum ResolutionCatalog {

    public static let all: [Resolution] = [
        Resolution(name: "7680x4320", pixelSize: PixelSize(widthInPixels: 7680, heightInPixels: 4320), label: "8K UHD"),
        Resolution(name: "3840x2160", pixelSize: PixelSize(widthInPixels: 3840, heightInPixels: 2160), label: "4K UHD"),
        Resolution(name: "3440x1440", pixelSize: PixelSize(widthInPixels: 3440, heightInPixels: 1440), label: "UW-QHD"),
        Resolution(name: "3000x2000", pixelSize: PixelSize(widthInPixels: 3000, heightInPixels: 2000)),
        Resolution(name: "2560x1600", pixelSize: PixelSize(widthInPixels: 2560, heightInPixels: 1600), label: "WQXGA"),
        Resolution(name: "2560x1440", pixelSize: PixelSize(widthInPixels: 2560, heightInPixels: 1440), label: "1440p / QHD"),
        Resolution(name: "2560x1080", pixelSize: PixelSize(widthInPixels: 2560, heightInPixels: 1080), label: "UW-FHD"),
        Resolution(name: "2160x1440", pixelSize: PixelSize(widthInPixels: 2160, heightInPixels: 1440)),
        Resolution(name: "1920x1200", pixelSize: PixelSize(widthInPixels: 1920, heightInPixels: 1200), label: "WUXGA"),
        Resolution(name: "1920x1080", pixelSize: PixelSize(widthInPixels: 1920, heightInPixels: 1080), label: "1080p / Full HD"),
        Resolution(name: "1600x1200", pixelSize: PixelSize(widthInPixels: 1600, heightInPixels: 1200), label: "UXGA"),
        Resolution(name: "1280x720",  pixelSize: PixelSize(widthInPixels: 1280, heightInPixels: 720),  label: "720p / HD"),
        Resolution(name: "1024x768",  pixelSize: PixelSize(widthInPixels: 1024, heightInPixels: 768),  label: "XGA"),
        Resolution(name: "640x480",   pixelSize: PixelSize(widthInPixels: 640,  heightInPixels: 480),  label: "VGA"),
    ]
}
