import Foundation
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
    @State private var selectedContainer: Container?

    @AppStorage("dailyGoalML") private var dailyGoalML = 2000
    @AppStorage("trainingDayGoalML") private var trainingDayGoalML = 3000
    @AppStorage("isTrainingDay") private var isTrainingDay = false
    @AppStorage("containers") private var containersJSON = Container.defaults.toJSON()

    private var containers: [Container] {
        Array<Container>.fromJSON(containersJSON)
    }
    
    private var currentGoal: Int {
        isTrainingDay ? trainingDayGoalML : dailyGoalML
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
        let ratio = Double(todayTotal) / Double(currentGoal)
        return min(ratio, 1.0)
    }

    private var percentageValue: Int {
        let ratio = Double(todayTotal) / Double(currentGoal)
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
                        goalAmount: currentGoal,
                        percentage: percentageValue,
                        waterAddedTrigger: waterAddedTrigger
                    )
                    .frame(height: 470)
                    
                    // Training Day Toggle
                    HStack {
                        Image(systemName: isTrainingDay ? "figure.run.circle.fill" : "figure.run.circle")
                            .font(.title2)
                            .foregroundStyle(isTrainingDay ? .orange : .secondary)
                        
                        Text("Training Day")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Toggle("", isOn: $isTrainingDay)
                            .labelsHidden()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isTrainingDay ? Color.orange.opacity(0.1) : Color.gray.opacity(0.1))
                    )
                    .padding(.horizontal)
                    .onChange(of: isTrainingDay) { _, newValue in
                        HapticManager.shared.impact(style: .medium)
                    }

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
                    
                    // Extra space to enable scrolling
                    Color.clear.frame(height: 200)
                }
            }
            .scrollIndicators(.hidden)
            .sheet(item: $selectedContainer) { container in
                if container.isCustom {
                    WheelPickerSheet(
                        container: container,
                        onPick: { amount in
                            addWaterCustomAmount(amount: amount, isTrainingDay: isTrainingDay)
                            selectedContainer = nil
                        },
                        onCancel: {
                            selectedContainer = nil
                        }
                    )
                } else {
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

        // Store current training day status with the entry
        let entry = WaterEntry(
            timestamp: Date(),
            amountML: ml,
            isTrainingDay: isTrainingDay,
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
    
    private func addWaterCustomAmount(amount: Int, isTrainingDay: Bool) {
        let oldProgress = progress

        let entry = WaterEntry(
            timestamp: Date(),
            amountML: amount,
            isTrainingDay: isTrainingDay,
            containerID: nil,  // No container ID for custom amounts
            fractionNumerator: nil,
            fractionDenominator: nil
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

// MARK: - Fraction Sheet
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

// MARK: - Wheel Picker Sheet
struct WheelPickerSheet: View {
    let container: Container
    let onPick: (Int) -> Void
    let onCancel: () -> Void
    
    @State private var selectedAmount = 250
    
    // Generate amounts from 50 to 1000 in 50mL increments
    private let amounts = Array(stride(from: 50, through: 1000, by: 50))
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Container display
                VStack(spacing: 12) {
                    ContainerIconView(container: container, size: 80)
                    
                    Text(container.name)
                        .font(.title2.bold())
                    
                    Text("\(selectedAmount) mL")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 40)
                .padding(.bottom, 20)
                
                // Wheel picker
                Picker("Amount", selection: $selectedAmount) {
                    ForEach(amounts, id: \.self) { amount in
                        Text("\(amount) mL")
                            .tag(amount)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 200)
                
                Spacer()
                
                // Confirm button
                Button(action: {
                    onPick(selectedAmount)
                }) {
                    Text("Add \(selectedAmount) mL")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .navigationTitle("Select Amount")
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

                if container.isCustom {
                    Text("Custom")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(container.volumeML) mL")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
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

// MARK: - Container Icon View
struct ContainerIconView: View {
    let container: Container
    let size: CGFloat
    
    var body: some View {
        Group {
            if let imageName = container.imageName,
               let uiImage = Container.loadImage(filename: imageName) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.2))
            } else {
                Text(container.emoji)
                    .font(.system(size: size * 0.7))
            }
        }
    }
}

// MARK: - Enhanced Water Glass (Realistic Fluid Physics)
struct EnhancedWaterGlassView: View {
    let progress: Double
    let currentAmount: Int
    let goalAmount: Int
    let percentage: Int
    let waterAddedTrigger: Int

    @State private var wavePhase: Double = 0
    @State private var bubbles: [BubbleParticle] = []
    
    // Physics state
    @State private var velocity: CGFloat = 0.0
    @State private var displacement: CGFloat = 0.0
    @State private var lastScrollY: CGFloat = 0.0
    @State private var isScrolling: Bool = false
    @State private var scrollTimeout: DispatchWorkItem?
    
    @State private var timer: Timer?
    
    let glassThickness: CGFloat = 4

    var body: some View {
        GeometryReader { geometry in
            let width = min(geometry.size.width * 0.65, 250)
            let height = geometry.size.height * 0.85
            
            let currentY = geometry.frame(in: .global).minY
            
            // Calculate vertical wave offset
            let verticalOffset = displacement * 0.3

            ZStack {
                // Glass Background
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
                    // Water with vertical sloshing
                    WaterWaveShape(
                        progress: progress,
                        phase: wavePhase,
                        amplitude: isScrolling ? 1.0 : 0.0,
                        verticalOffset: verticalOffset
                    )
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
                    .frame(width: width - glassThickness * 3, height: height * CGFloat(min(max(progress, 0.05), 1.0)))
                    .mask(GlassShape().padding(glassThickness))
                }

                // Glass Highlights
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
                        .foregroundStyle(progress >= 0.5 ? .white : .blue)
                        .shadow(color: .black.opacity(progress >= 0.5 ? 0.2 : 0), radius: 2)

                    Text("\(currentAmount) / \(goalAmount) mL")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(progress >= 0.5 ? .white.opacity(0.8) : .secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .onChange(of: currentY) { oldValue, newValue in
                handleScrollChange(from: oldValue, to: newValue)
            }
        }
        .onAppear {
            startPhysicsTimer()
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
        .onChange(of: waterAddedTrigger) { _, _ in
            spawnBubbles()
        }
    }
    
    private func startPhysicsTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            updatePhysics()
        }
    }
    
    private func handleScrollChange(from oldY: CGFloat, to newY: CGFloat) {
        if lastScrollY == 0 {
            lastScrollY = newY
            return
        }
        
        let deltaY = newY - lastScrollY
        lastScrollY = newY
        
        if abs(deltaY) > 0.1 {
            isScrolling = true
            velocity += deltaY * 0.8
            wavePhase += abs(deltaY) * 0.15
            
            scrollTimeout?.cancel()
            let workItem = DispatchWorkItem {
                isScrolling = false
            }
            scrollTimeout = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: workItem)
        }
    }

    private func updatePhysics() {
        let dt = 1.0 / 60.0
        
        // Spring physics for vertical displacement
        let springStiffness: CGFloat = 120.0
        let damping: CGFloat = 12.0
        
        let springForce = -springStiffness * displacement
        let dampingForce = -damping * velocity
        
        let acceleration = springForce + dampingForce
        velocity += acceleration * CGFloat(dt)
        displacement += velocity * CGFloat(dt)
        
        displacement = max(-20, min(20, displacement))
        
        if abs(displacement) < 0.01 && abs(velocity) < 0.1 {
            displacement = 0
            velocity = 0
        }
        
        // Update bubbles
        updateBubbles(dt: dt)
    }

    private func updateBubbles(dt: TimeInterval) {
        var active: [BubbleParticle] = []
        
        for var b in bubbles {
            b.y += b.speed * dt
            b.x += sin(b.y * 10) * 0.001
            b.opacity -= dt * 0.5
            
            if b.y < 1.0 && b.opacity > 0 {
                active.append(b)
            }
        }
        bubbles = active
    }

    private func spawnBubbles() {
        for _ in 0..<8 {
            bubbles.append(BubbleParticle())
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
    var amplitude: Double
    var verticalOffset: CGFloat

    var animatableData: AnimatablePair<Double, AnimatablePair<AnimatablePair<Double, Double>, CGFloat>> {
        get {
            AnimatablePair(
                phase,
                AnimatablePair(
                    AnimatablePair(progress, amplitude),
                    verticalOffset
                )
            )
        }
        set {
            phase = newValue.first
            progress = newValue.second.first.first
            amplitude = newValue.second.first.second
            verticalOffset = newValue.second.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height

        let waterHeight = height * CGFloat(progress)
        let topY = height - waterHeight + verticalOffset

        path.move(to: CGPoint(x: 0, y: height))
        path.addLine(to: CGPoint(x: width, y: height))
        path.addLine(to: CGPoint(x: width, y: topY))

        if progress > 0 && progress < 1.0 && amplitude > 0 {
            // Horizontal waves only when scrolling
            for x in stride(from: width, through: 0, by: -2) {
                let relativeX = x / width
                let sine1 = Foundation.sin(relativeX * 4 * .pi + phase) * 3 * amplitude
                let sine2 = Foundation.sin(relativeX * 6 * .pi + phase * 1.5) * 1.5 * amplitude
                let y = topY + sine1 + sine2
                path.addLine(to: CGPoint(x: x, y: y))
            }
        } else {
            // Flat surface when at rest
            path.addLine(to: CGPoint(x: 0, y: topY))
        }

        path.closeSubpath()
        return path
    }
}

struct BubbleParticle: Identifiable {
    let id = UUID()
    var x: Double = Double.random(in: 0.15...0.85)
    var y: Double = 0
    var speed: Double = Double.random(in: 0.8...1.5)  // Speed in units per second
    var size: Double = Double.random(in: 4...9)
    var opacity: Double = Double.random(in: 0.6...0.9)
}

#Preview {
    ContentView()
        .modelContainer(for: WaterEntry.self, inMemory: true)
}
