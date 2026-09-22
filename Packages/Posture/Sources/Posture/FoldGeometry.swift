import CoreGraphics

/// The inner display split around the crease. CLAUDE.md: never hardcode the
/// fold position or a 50/50 split — every rect here is derived from the
/// `ReservedRegion` the system reports.
public struct FoldSplit: Sendable, Equatable {
    /// The vertical half the describer reads (PRD §3.2's "lid").
    public let lid: CGRect
    /// The half lying on the table.
    public let flat: CGRect
    /// The reserved crease itself — nothing is drawn here.
    public let crease: CGRect
}

/// How the flat half divides between the describer's blind-tap zones and the
/// far edge the guessers read (PRD §3.2).
public struct FlatHalfLayout: Sendable, Equatable {
    /// Adjacent to the crease: timer + live score, rotated 180°.
    public let farEdge: CGRect
    /// Toward the crease, directly below the far edge.
    public let correct: CGRect
    /// Toward the describer — the outermost edge, easiest to reach.
    public let skip: CGRect
}

public enum FoldGeometry {
    /// Splits `container` around a horizontal crease.
    ///
    /// Returns `nil` — meaning "use the single-screen layout" — when the
    /// division is missing, runs the wrong way (a crease parallel to the long
    /// axis can't produce a lid-over-table split), or leaves no room on one
    /// side.
    ///
    /// Convention: the half *above* the crease in the current UI orientation
    /// is the lid. iOS orients the UI by gravity, so in tabletop posture the
    /// standing half is the one that reads as "up".
    public static func split(container: CGSize, division: CGRect?) -> FoldSplit? {
        guard container.width > 0, container.height > 0, let division else { return nil }

        // A crease that doesn't span nearly the full width isn't the
        // horizontal division this layout is built around.
        guard division.width >= container.width * 0.9 else { return nil }

        let creaseTop = max(0, division.minY)
        let creaseBottom = min(container.height, division.maxY)
        guard creaseBottom > creaseTop, creaseTop > 0, creaseBottom < container.height else { return nil }

        return FoldSplit(
            lid: CGRect(x: 0, y: 0, width: container.width, height: creaseTop),
            flat: CGRect(
                x: 0,
                y: creaseBottom,
                width: container.width,
                height: container.height - creaseBottom
            ),
            crease: CGRect(
                x: 0,
                y: creaseTop,
                width: container.width,
                height: creaseBottom - creaseTop
            )
        )
    }

    /// PRD §3.2/§2.1 — the two hit zones split what's left of the flat half
    /// evenly, edge to edge, with no margins or competing controls, because
    /// they're tapped blind at an angle from a standing reach.
    public static func flatHalfLayout(flat: CGRect, farEdgeFraction: Double = 0.28) -> FlatHalfLayout {
        let fraction = min(0.6, max(0, farEdgeFraction))
        let farEdgeHeight = flat.height * fraction
        let zoneHeight = (flat.height - farEdgeHeight) / 2

        return FlatHalfLayout(
            farEdge: CGRect(x: flat.minX, y: flat.minY, width: flat.width, height: farEdgeHeight),
            correct: CGRect(
                x: flat.minX,
                y: flat.minY + farEdgeHeight,
                width: flat.width,
                height: zoneHeight
            ),
            skip: CGRect(
                x: flat.minX,
                y: flat.minY + farEdgeHeight + zoneHeight,
                width: flat.width,
                height: zoneHeight
            )
        )
    }
}
