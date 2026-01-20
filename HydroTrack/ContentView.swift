import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allEntries: [WaterEntry]
    
    // State for celebration
    @State private var confettiCounter = 0
    @State private var previousProgress: Double = 0
    
    // State for water animation trigger
    @State private var waterAddedTrigger = 0
    
    // State for fraction selector
    @State private var selectedContainer: Container?
    @State private var showFractionSheet = false
    
    // Dynamic goal from AppStorage
    @AppStorage("dailyGoalML") private var dailyGoalML = 2000
    
    // Containers from AppStorage
    @AppStorage("containers") private var containersJSON = Container.defaults.toJSON()
    
    private var containers: [Container] {
        Array<Container>.fromJSON(containersJSON)
    }
    
    // Calculate today's entries
    private var todayEntries: [WaterEntry] {
        let today = Calendar.current.startOfDay(for: Date())
        return allEntries.filter { entry in
            Calendar.current.isDate(entry.timestamp, inSameDayAs: today)
        }
        .sorted { $0.timestamp > $1.timestamp } // Most recent first
    }
    
    // Calculate today's total
    private var todayTotal: Int {
        todayEntries.reduce(0) { $0 + $1.amountML }
    }
    
    // Calculate progress for visual (capped at 1.0)
    private var progress: Double {
        let ratio = Double(todayTotal) / Double(dailyGoalML)
        return min(ratio, 1.0)
    }
    
    // Calculate actual percentage (can go above 100%)
    private var percentageValue: Int {
        let ratio = Double(todayTotal) / Double(dailyGoalML)
        return Int(ratio * 100)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Spacer()
                        .frame(height: 20)
                    
                    // Water Glass with Enhanced Physics
                    EnhancedWaterGlassView(
                        progress: progress,
                        currentAmount: todayTotal,
                        goalAmount: dailyGoalML,
                        percentage: percentageValue,
                        waterAddedTrigger: waterAddedTrigger
                    )
                    .frame(height: 450)
                    
                    // Container quick-add buttons
                    if containers.isEmpty {
                        Text("Add containers in Settings")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.top, 20)
                    } else {
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 16) {
                            ForEach(containers.prefix(6)) { container in
                                ContainerButton(container: container) {
                                    selectedContainer = container
                                    showFractionSheet = true
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    Spacer()
                        .frame(height: 60)
                }
            }
            .scrollIndicators(.hidden)
            .sheet(isPresented: $showFractionSheet) {
                if let container = selectedContainer {
                    FractionSelectorView(
                        container: container,
                        onSelect: { fraction in
                            addWater(container: container, fraction: fraction)
                            showFractionSheet = false
                        }
                    )
                    .presentationDetents([.height(400)])
                    .presentationDragIndicator(.visible)
                }
            }
            .overlay(
                // Celebration overlay
                Group {
                    if progress >= 1.0 {
                        ZStack {
                            Color.black.opacity(0.3)
                                .ignoresSafeArea()
                            
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
            )
        }
    }
    
    // Function to add water entry with haptics & celebration
    private func addWater(container: Container, fraction: Double) {
        let oldProgress = progress
        let amount = Int(Double(container.volumeML) * fraction)
        
        // Add entry
        let entry = WaterEntry(timestamp: Date(), amountML: amount)
        modelContext.insert(entry)
        
        // Trigger water animation
        waterAddedTrigger += 1
        
        // Light haptic feedback for button tap
        HapticManager.shared.impact(style: .light)
        
        // Check if goal was just reached
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if oldProgress < 1.0 && progress >= 1.0 {
                // Goal reached! Success haptic + celebration
                HapticManager.shared.notification(type: .success)
                confettiCounter = 1
                
                // Auto-dismiss after 2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    confettiCounter = 2
                }
            }
        }
    }
}

// MARK: - Fraction Selector View
struct FractionSelectorView: View {
    let container: Container
    let onSelect: (Double) -> Void
    
    let fractions: [(name: String, value: Double)] = [
        ("1/4", 0.25),
        ("1/3", 0.33),
        ("1/2", 0.5),
        ("2/3", 0.67),
        ("3/4", 0.75),
        ("Full", 1.0)
    ]
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                ContainerIconView(container: container, size: 60)
                
                Text(container.name)
                    .font(.title2.bold())
                
                Text("\(container.volumeML) mL")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 20)
            
            Divider()
            
            // Fraction buttons
            VStack(spacing: 12) {
                ForEach(fractions, id: \.name) { fraction in
                    Button(action: {
                        onSelect(fraction.value)
                    }) {
                        HStack {
                            Text(fraction.name)
                                .font(.headline)
                            
                            Spacer()
                            
                            Text("\(Int(Double(container.volumeML) * fraction.value)) mL")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(.blue.opacity(0.1))
                        .foregroundStyle(.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            
            Spacer()
        }
    }
}

// MARK: - Container Button Component
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
                // 1. Back of Glass (Translucent)
                GlassShape()
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.1), .white.opacity(0.05)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: width, height: height)
                
                // 2. Water Body
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
                    
                    TimelineView(.animation) { timeline in
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

                // 3. Front Glass Glare
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

                // 4. Text Overlay
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
        .onAppear {
            startWaveAnimation()
        }
        .onChange(of: waterAddedTrigger) { _, _ in
            spawnBubbles()
        }
    }
    
    private func startWaveAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            wavePhase += 0.02
        }
    }
    
    private func spawnBubbles() {
        for _ in 0..<15 {
            bubbles.append(BubbleParticle())
        }
        
        Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { timer in
            if bubbles.isEmpty { timer.invalidate() }
            
            var activeBubbles: [BubbleParticle] = []
            
            for var bubble in bubbles {
                bubble.y += bubble.speed
                bubble.x += sin(bubble.y * 10) * 0.005
                
                if bubble.y < 1.0 {
                    activeBubbles.append(bubble)
                }
            }
            bubbles = activeBubbles
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
