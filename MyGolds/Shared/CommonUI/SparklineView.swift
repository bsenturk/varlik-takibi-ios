//
//  SparklineView.swift
//  MyGolds
//
//  A compact line chart used inside asset rows to show recent price movement.
//

import SwiftUI

struct SparklineView: View {
    let values: [Double]
    var lineColor: Color = .green

    var body: some View {
        GeometryReader { geo in
            let points = normalizedPoints(in: geo.size)
            ZStack {
                if points.count > 1 {
                    // Soft fill under the line.
                    fillPath(points: points, in: geo.size)
                        .fill(
                            LinearGradient(
                                colors: [lineColor.opacity(0.22), lineColor.opacity(0.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    linePath(points: points)
                        .stroke(
                            lineColor,
                            style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                        )
                } else {
                    // Flat baseline when there isn't enough data.
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: geo.size.height / 2))
                        p.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height / 2))
                    }
                    .stroke(lineColor.opacity(0.5), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                }
            }
        }
    }

    private func normalizedPoints(in size: CGSize) -> [CGPoint] {
        guard values.count > 1 else { return [] }
        let minV = values.min() ?? 0
        let maxV = values.max() ?? 1
        let range = maxV - minV
        let stepX = size.width / CGFloat(values.count - 1)

        return values.enumerated().map { index, value in
            let x = CGFloat(index) * stepX
            let normalized = range == 0 ? 0.5 : (value - minV) / range
            // Keep a little vertical padding so peaks aren't clipped.
            let y = size.height - (CGFloat(normalized) * (size.height * 0.8) + size.height * 0.1)
            return CGPoint(x: x, y: y)
        }
    }

    private func linePath(points: [CGPoint]) -> Path {
        Path { path in
            guard let first = points.first else { return }
            path.move(to: first)
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
        }
    }

    private func fillPath(points: [CGPoint], in size: CGSize) -> Path {
        Path { path in
            guard let first = points.first, let last = points.last else { return }
            path.move(to: CGPoint(x: first.x, y: size.height))
            path.addLine(to: first)
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
            path.addLine(to: CGPoint(x: last.x, y: size.height))
            path.closeSubpath()
        }
    }
}
