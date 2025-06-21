//
//  ConsistencyRatingView.swift
//  Shrednotes
//
//  Created by Karl Koch on 13/11/2024.
//
import SwiftUI

struct ConsistencyRatingView: View {
    @Binding var consistency: Int
    let labels = ["Never", "Not often", "Sometimes", "Often", "Always"]

    var body: some View {
        VStack {
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(0..<labels.count, id: \.self) { index in
                    VStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(consistency >= index ? LinearGradient(
                                gradient: Gradient(colors: [Color.indigo, Color.blue]),
                                startPoint: .top,
                                endPoint: .bottom
                            ) : LinearGradient(
                                gradient: Gradient(colors: [Color.secondary.opacity(0.3), Color.secondary.opacity(0.1)]),
                                startPoint: .top,
                                endPoint: .bottom
                            ))
                            .frame(height: CGFloat(40 + index * 20))
                        Text(labels[index])
                            .font(.caption)
                            .foregroundColor(consistency == index ? .primary : .secondary)
                    }
                    .onTapGesture {
                        consistency = index
                    }
                }
            }
        }
    }
}

struct ConsistencyRatingViewCondensed: View {
    var consistency: Int
    var onDark: Bool = false

    var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(0..<5, id: \.self) { index in
                    VStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(consistency >= index ? (
                                onDark ? LinearGradient(
                                    gradient: Gradient(colors: [Color.white, Color.white]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                ) : LinearGradient(
                                    gradient: Gradient(colors: [Color.indigo, Color.blue]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            ) : LinearGradient(
                                gradient: Gradient(colors: [Color.secondary.opacity(0.1), Color.secondary.opacity(0.3)]),
                                startPoint: .top,
                                endPoint: .bottom
                            ))
                            .frame(height: 4)
                    }
                }
            }
        }
    }
}

struct CircularProgressView: View {
    let progress: Double // 0.0 to 1.0
    let lineWidth: CGFloat
    let size: CGFloat
    let primaryColor: Color
    let backgroundColor: Color
    
    @State private var animatedProgress: Double = 0
    
    init(progress: Double, 
         lineWidth: CGFloat = 4,
         size: CGFloat = 44,
         primaryColor: Color = .blue,
         backgroundColor: Color = Color.secondary.opacity(0.2)) {
        self.progress = min(max(progress, 0), 1) // Clamp between 0 and 1
        self.lineWidth = lineWidth
        self.size = size
        self.primaryColor = primaryColor
        self.backgroundColor = backgroundColor
    }
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(backgroundColor, lineWidth: lineWidth)
                .frame(width: size, height: size)
            
            // Progress circle
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [primaryColor, primaryColor.opacity(0.7)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: animatedProgress)
            
            // Center content
            VStack(spacing: 0) {
                Text("\(Int(animatedProgress * 100))")
                    .font(.system(size: size * 0.3, weight: .bold, design: .rounded))
                    .foregroundColor(primaryColor)
                Text("%")
                    .font(.system(size: size * 0.15, weight: .medium, design: .rounded))
                    .foregroundColor(primaryColor.opacity(0.8))
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.easeInOut(duration: 0.5)) {
                animatedProgress = newValue
            }
        }
    }
}

struct ConsistencyProgressRing: View {
    let consistency: Int // 0-4 scale from the model
    let size: CGFloat
    
    init(consistency: Int, size: CGFloat = 44) {
        self.consistency = consistency
        self.size = size
    }
    
    var progress: Double {
        // Convert 0-4 scale to 0.0-1.0 progress
        return Double(consistency) / 4.0
    }
    
    var progressColor: Color {
        switch consistency {
        case 0: return .red
        case 1: return .orange
        case 2: return .yellow
        case 3: return .blue
        case 4: return .green
        default: return .gray
        }
    }
    
    var body: some View {
        CircularProgressView(
            progress: progress,
            lineWidth: size * 0.1,
            size: size,
            primaryColor: progressColor
        )
    }
}

struct HeatMapView: View {
    let trick: Trick
    let sessions: [SkateSession]
    let weeks: Int // Number of weeks to display
    
    private var practiceData: [Date: Int] {
        var data: [Date: Int] = [:]
        let calendar = Calendar.current
        
        // Count practice sessions per day
        for session in sessions {
            guard let sessionDate = session.date,
                  let tricks = session.tricks,
                  tricks.contains(where: { $0.id == trick.id }) else { continue }
            
            let startOfDay = calendar.startOfDay(for: sessionDate)
            data[startOfDay, default: 0] += 1
        }
        
        return data
    }
    
    private var dateRange: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let startDate = calendar.date(byAdding: .weekOfYear, value: -weeks, to: today) ?? today
        var dates: [Date] = []
        var currentDate = startDate
        while currentDate <= today {
            dates.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        return dates
    }
    
    private func colorForIntensity(_ count: Int) -> Color {
        switch count {
        case 0: return Color.gray.opacity(0.1)
        case 1: return Color.green.opacity(0.3)
        case 2: return Color.green.opacity(0.6)
        case 3: return Color.green.opacity(0.8)
        default: return Color.green
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            // The grid
            HeatMapGrid(
                dateRange: dateRange, 
                sessionData: practiceData, 
                columns: 7, 
                colorForIntensity: colorForIntensity
            )
            
            Spacer()
            
            // Legend
            HStack(spacing: 12) {
                Text("Less").font(.caption2).foregroundStyle(.secondary)
                HStack(spacing: 2) {
                    ForEach(0..<5) { intensity in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(colorForIntensity(intensity))
                            .frame(width: 10, height: 10)
                    }
                }
                Text("More").font(.caption2).foregroundStyle(.secondary)
                Spacer()
            }
        }
    }
}

private struct HeatMapGrid: View {
    let dateRange: [Date]
    let sessionData: [Date: Int]
    let columns: Int
    let colorForIntensity: (Int) -> Color

    var body: some View {
        // Use a fixed or default width for grid items
        let itemSize: CGFloat = 18 // Reasonable default for most screens
        let rows = dateRange.count / columns + 1
        LazyVGrid(
            columns: Array(repeating: GridItem(.fixed(itemSize), spacing: 2), count: columns),
            spacing: 2
        ) {
            ForEach(Array(dateRange.enumerated()), id: \.offset) { _, date in
                let count = sessionData[date] ?? 0
                RoundedRectangle(cornerRadius: 3)
                    .fill(colorForIntensity(count))
                    .frame(width: itemSize, height: itemSize)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: CGFloat(rows) * (itemSize + 2))
        .frame(minHeight: 100)
    }
}

struct CompactHeatMapView: View {
    let trick: Trick
    let sessions: [SkateSession]
    
    private var recentPracticeData: [(date: Date, count: Int)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: today)!
        
        var data: [Date: Int] = [:]
        
        // Count practice sessions per day for last 30 days
        for session in sessions {
            guard let sessionDate = session.date,
                  sessionDate >= thirtyDaysAgo,
                  let tricks = session.tricks,
                  tricks.contains(where: { $0.id == trick.id }) else { continue }
            
            let startOfDay = calendar.startOfDay(for: sessionDate)
            data[startOfDay, default: 0] += 1
        }
        
        // Create array for last 7 days
        var result: [(Date, Int)] = []
        for i in (0..<7).reversed() {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                result.append((date, data[date] ?? 0))
            }
        }
        
        return result
    }
    
    private func colorForIntensity(_ count: Int) -> Color {
        switch count {
        case 0: return Color.secondary.opacity(0.15)
        case 1: return Color.green.opacity(0.4)
        case 2: return Color.green.opacity(0.6)
        default: return Color.green.opacity(0.8)
        }
    }
    
    var body: some View {
        HStack(spacing: 1) {
            ForEach(recentPracticeData, id: \.date) { item in
                RoundedRectangle(cornerRadius: 1)
                    .fill(colorForIntensity(item.count))
                    .frame(width: 8, height: 3)
            }
        }
    }
}
