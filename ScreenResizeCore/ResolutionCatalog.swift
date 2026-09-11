import CoreGraphics

/// The single source of truth for resolution presets.
///
/// UI code reads from here and never spells out a resolution of its own. See
/// CLAUDE.md, "Resolution presets live in a single data model".
///
/// Every value is in points, applied as-is. The list is deliberately flat and
/// ordered largest first — by width, then height — so the menu needs no sorting
/// of its own: grouping by aspect ratio was removed because it added a layer
/// of navigation without adding information — the dimensions already tell you
/// the shape, and a hover to reach a size is a hover too many.
public enum ResolutionCatalog {

    public static let all: [Resolution] = [
        Resolution(name: "7680x4320", pointSize: PointSize(widthInPoints: 7680, heightInPoints: 4320), label: "8K UHD"),
        Resolution(name: "3840x2160", pointSize: PointSize(widthInPoints: 3840, heightInPoints: 2160), label: "4K UHD"),
        Resolution(name: "3440x1440", pointSize: PointSize(widthInPoints: 3440, heightInPoints: 1440), label: "UW-QHD"),
        Resolution(name: "3000x2000", pointSize: PointSize(widthInPoints: 3000, heightInPoints: 2000)),
        Resolution(name: "2560x1600", pointSize: PointSize(widthInPoints: 2560, heightInPoints: 1600), label: "WQXGA"),
        Resolution(name: "2560x1440", pointSize: PointSize(widthInPoints: 2560, heightInPoints: 1440), label: "1440p / QHD"),
        Resolution(name: "2560x1080", pointSize: PointSize(widthInPoints: 2560, heightInPoints: 1080), label: "UW-FHD"),
        Resolution(name: "2160x1440", pointSize: PointSize(widthInPoints: 2160, heightInPoints: 1440)),
        Resolution(name: "1920x1200", pointSize: PointSize(widthInPoints: 1920, heightInPoints: 1200), label: "WUXGA"),
        Resolution(name: "1920x1080", pointSize: PointSize(widthInPoints: 1920, heightInPoints: 1080), label: "1080p / Full HD"),
        Resolution(name: "1600x1200", pointSize: PointSize(widthInPoints: 1600, heightInPoints: 1200), label: "UXGA"),
        Resolution(name: "1280x720",  pointSize: PointSize(widthInPoints: 1280, heightInPoints: 720),  label: "720p / HD"),
        Resolution(name: "1024x768",  pointSize: PointSize(widthInPoints: 1024, heightInPoints: 768),  label: "XGA"),
        Resolution(name: "960x1080",  pointSize: PointSize(widthInPoints: 960,  heightInPoints: 1080)),
        Resolution(name: "640x480",   pointSize: PointSize(widthInPoints: 640,  heightInPoints: 480),  label: "VGA"),
    ]
}
