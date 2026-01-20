import SwiftUI
import SwiftData

// MARK: - Portion Type
enum ContainerPortion: CaseIterable, Identifiable {
    case quarter, third, half, twoThirds, threeQuarters, full

    var id: String { label }

    var numerator: Int {
        switch self {
        case .quarter: 1
        case .third: 1
        case .half: 1
        case .twoThirds: 2
        case .threeQuarters: 3
        case .full: 1
        }
    }

    var denominator: Int {
        switch self {
        case .quarter: 4
        case .third: 3
        case .half: 2
        case .twoThirds: 3
        case .threeQuarters: 4
        case .full: 1
        }
    }

    var label: String {
        switch self {
        case .quarter: "1/4"
        case .third: "1/3"
        case .half: "1/2"
        case .twoThirds: "2/3"
        case .threeQuarters: "3/4"
        case .full: "Full"
        }
    }

    var value: Double {
        Double(numerator) / Double(denominator)
    }
}

// MARK: - ContentView
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allEntries: [WaterEntry]

    @State private var confettiCounter = 0
    @State private var waterAddedTrigger = 0

    // Fraction sheet
    @State private var selectedContainer: Container?

    @AppStorage("dailyGoalML") private var dailyGoalML = 2000
    @AppStorage("containers") private var containersJSON = Container.defaults.toJSON()

    private var containers: [Container] {
        Array<Container>.fromJSON(containersJSON)
    }

    private var todayEntries: [WaterEntry] {
        let today = Calendar.current.startOfDay(for: Date())
        return allEntries
            .filter { Calendar.current.isDate($0.timestamp, inSameDayAs: today) }
            .sorted { $0.timestamp > $1.timestamp }
    }

    private var todayTotal: Int {
        todayEntries.reduce(0) { $0 + $1.amountML }
    }

    private var progress: Double {
        let ratio = Double(todayTotal) / Double(dailyGoalML)
        return min(ratio, 1.0)
    }

    private var percentageValue: Int {
        let ratio = Double(todayTotal) / Double(dailyGoalML)
        return Int(ratio * 100)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Spacer().frame(height: 12)

                    EnhancedWaterGlassView(
                        progress: progress,
                        currentAmount: todayTotal,
                        goalAmount: dailyGoalML,
                        percentage: percentageValue,
                        waterAddedTrigger: waterAddedTrigger
                    )
                    .frame(height: 470)

                    // Quick-add buttons
                    if containers.isEmpty {
                        Text("Add containers in Settings")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                    } else {
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 16) {
                            ForEach(containers.prefix(6)) { container in
                                ContainerButton(container: container) {
                                    selectedContainer = container
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    Spacer().frame(height: 24)
                }
            }
            .scrollIndicators(.hidden)
            .sheet(item: $selectedContainer) { container in
                FractionPickerSheet(
                    container: container,
                    onPick: { portion in
                        addWater(container: container, portion: portion)
                        selectedContainer = nil
                    },
                    onCancel: {
                        selectedContainer = nil
                    }
                )
            }
            .overlay {
                if progress >= 1.0 {
                    ZStack {
                        Color.black.opacity(0.3).ignoresSafeArea()
                        VStack(spacing: 20) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 100))
                                .foregroundStyle(.green)
                                .scaleEffect(confettiCounter > 0 ? 1.0 : 0.5)
                                .animation(.spring(response: 0.5, dampingFraction: 0.6), value: confettiCounter)

                            Text("Goal Reached! 🎉")
                                .font(.title.bold())
                                .foregroundStyle(.white)
                        }
                    }
                    .opacity(confettiCounter > 0 && confettiCounter < 2 ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: 0.3), value: confettiCounter)
                }
            }
        }
    }

    private func addWater(container: Container, portion: ContainerPortion) {
        let oldProgress = progress

        let ml = Int(round(Double(container.volumeML) * portion.value))

        let entry = WaterEntry(
            timestamp: Date(),
            amountML: ml,
            containerID: container.id,
            fractionNumerator: portion.numerator,
            fractionDenominator: portion.denominator
        )
        modelContext.insert(entry)

        waterAddedTrigger += 1
        HapticManager.shared.impact(style: .light)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if oldProgress < 1.0 && progress >= 1.0 {
                HapticManager.shared.notification(type: .success)
                confettiCounter = 1
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    confettiCounter = 2
                }
            }
        }
    }
}

// MARK: - Fraction Sheet (FIXED UI)
struct FractionPickerSheet: View {
    let container: Container
    let onPick: (ContainerPortion) -> Void
    let onCancel: () -> Void

    private func ml(for portion: ContainerPortion) -> Int {
        Int(round(Double(container.volumeML) * portion.value))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        ContainerIconView(container: container, size: 56)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(container.name)
                                .font(.headline)
                            Text("\(container.volumeML) mL")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 6)
                }

                Section("Log amount") {
                    ForEach(ContainerPortion.allCases) { portion in
                        Button {
                            onPick(portion)
                        } label: {
                            HStack {
                                Text(portion.label)
                                    .font(.headline)

                                Spacer()

                                Text("\(ml(for: portion)) mL")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Add drink")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Container Button
struct ContainerButton: View {
    let container: Container
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ContainerIconView(container: container, size: 44)

                Text(container.name)
                    .font(.caption.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text("\(container.volumeML) mL")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(.blue.opacity(0.1))
            .foregroundStyle(.blue)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Enhanced Water Glass Component
struct EnhancedWaterGlassView: View {
    let progress: Double
    let currentAmount: Int
    let goalAmount: Int
    let percentage: Int
    let waterAddedTrigger: Int

    @State private var wavePhase: Double = 0
    @State private var bubbles: [BubbleParticle] = []

    let glassThickness: CGFloat = 4

    var body: some View {
        GeometryReader { geometry in
            let width = min(geometry.size.width * 0.65, 250)
            let height = geometry.size.height * 0.85
            let waterHeight = height * CGFloat(min(max(progress, 0.05), 1.0))

            ZStack {
                GlassShape()
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.1), .white.opacity(0.05)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: width, height: height)

                ZStack(alignment: .bottom) {
                    WaterWaveShape(progress: progress, phase: wavePhase)
                        .fill(
                            LinearGradient(
                                colors: progress >= 1.0 ? [
                                    Color.green.opacity(0.4),
                                    Color.green,
                                    Color.green.opacity(0.9)
                                ] : [
                                    Color.blue.opacity(0.3),
                                    Color.blue,
                                    Color(red: 0, green: 0.2, blue: 0.8)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: width - glassThickness * 2, height: height - glassThickness)
                        .mask(GlassShape().padding(glassThickness))

                    TimelineView(.animation) { _ in
                        Canvas { context, size in
                            for bubble in bubbles {
                                let rect = CGRect(
                                    x: bubble.x * size.width,
                                    y: size.height - (bubble.y * size.height),
                                    width: bubble.size,
                                    height: bubble.size
                                )
                                context.opacity = bubble.opacity
                                context.fill(Circle().path(in: rect), with: .color(.white.opacity(0.6)))
                            }
                        }
                    }
                    .frame(width: width - glassThickness * 3, height: waterHeight)
                    .mask(GlassShape().padding(glassThickness))
                }

                GlassShape()
                    .stroke(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(0.1), location: 0),
                                .init(color: .white.opacity(0.6), location: 0.2),
                                .init(color: .white.opacity(0.1), location: 0.4),
                                .init(color: .white.opacity(0.1), location: 1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: width, height: height)

                Path { path in
                    path.move(to: CGPoint(x: width * 0.2, y: height * 0.1))
                    path.addQuadCurve(
                        to: CGPoint(x: width * 0.2, y: height * 0.9),
                        control: CGPoint(x: width * 0.15, y: height * 0.5)
                    )
                }
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.0), .white.opacity(0.4), .white.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 4
                )
                .frame(width: width, height: height)

                VStack(spacing: 4) {
                    Text("\(percentage)%")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(progress > 0.5 ? .white : .blue)
                        .shadow(color: .black.opacity(progress > 0.5 ? 0.2 : 0), radius: 2)

                    Text("\(currentAmount) / \(goalAmount) mL")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(progress > 0.5 ? .white.opacity(0.8) : .secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .onAppear { startWaveAnimation() }
        .onChange(of: waterAddedTrigger) { _, _ in spawnBubbles() }
    }

    private func startWaveAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            wavePhase += 0.02
        }
    }

    private func spawnBubbles() {
        for _ in 0..<15 { bubbles.append(BubbleParticle()) }

        Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { timer in
            if bubbles.isEmpty { timer.invalidate() }

            var active: [BubbleParticle] = []
            for var b in bubbles {
                b.y += b.speed
                b.x += sin(b.y * 10) * 0.005
                if b.y < 1.0 { active.append(b) }
            }
            bubbles = active
        }
    }
}

// MARK: - Shapes
struct GlassShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let bottomWidth = rect.width * 0.75
        let taper = (rect.width - bottomWidth) / 2

        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: taper, y: rect.height - 15))
        path.addQuadCurve(
            to: CGPoint(x: taper + 15, y: rect.height),
            control: CGPoint(x: taper, y: rect.height)
        )
        path.addLine(to: CGPoint(x: rect.width - taper - 15, y: rect.height))
        path.addQuadCurve(
            to: CGPoint(x: rect.width - taper, y: rect.height - 15),
            control: CGPoint(x: rect.width - taper, y: rect.height)
        )
        path.addLine(to: CGPoint(x: rect.width, y: 0))
        return path
    }
}

struct WaterWaveShape: Shape {
    var progress: Double
    var phase: Double

    var animatableData: Double {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height

        let waterHeight = height * CGFloat(progress)
        let topY = height - waterHeight

        path.move(to: CGPoint(x: 0, y: height))
        path.addLine(to: CGPoint(x: width, y: height))
        path.addLine(to: CGPoint(x: width, y: topY))

        if progress > 0 && progress < 1.0 {
            for x in stride(from: width, through: 0, by: -2) {
                let relativeX = x / width
                let sine1 = sin(relativeX * 4 * .pi + phase) * 4
                let sine2 = sin(relativeX * 6 * .pi + phase * 1.5) * 2
                let y = topY + sine1 + sine2
                path.addLine(to: CGPoint(x: x, y: y))
            }
        } else {
            path.addLine(to: CGPoint(x: 0, y: topY))
        }

        path.closeSubpath()
        return path
    }
}

struct BubbleParticle: Identifiable {
    let id = UUID()
    var x: Double = Double.random(in: 0.1...0.9)
    var y: Double = 0
    var speed: Double = Double.random(in: 0.01...0.02)
    var size: Double = Double.random(in: 4...10)
    var opacity: Double = Double.random(in: 0.4...0.8)
}

#Preview {
    ContentView()
        .modelContainer(for: WaterEntry.self, inMemory: true)
}
