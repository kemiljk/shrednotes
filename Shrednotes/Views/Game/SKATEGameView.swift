import SwiftUI
import SwiftData

struct SKATEGameView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Trick.name, order: .forward)]) private var allTricks: [Trick]
    
    @State private var players: [Player] = []
    @State private var currentPlayerIndex = 0
    @State private var gamePhase: GamePhase = .setup
    @State private var selectedTrick: Trick?
    @State private var showingTrickPicker = false
    @State private var gameHistory: [GameEvent] = []
    @State private var winner: Player?
    @State private var currentTrickSetter: Int = 0
    @State private var playersAttempting: [Int: Bool] = [:]
    @State private var currentAttemptingPlayer: Int = 0
    @State private var searchText = ""
    @State private var selectedTrickType: TrickType?
    
    @FocusState private var focusedField: FocusedField?
    
    enum GamePhase {
        case setup
        case readyToStart
        case settingTrick
        case setterAttempting
        case attemptingTrick
        case gameOver
    }
    
    enum FocusedField: Hashable {
        case playerName(Int)
        case search
    }
    
    struct Player: Identifiable, Equatable {
        let id = UUID()
        var name: String
        var letters: String = ""
        var isOut: Bool = false
        
        var isSkated: Bool {
            letters == "SKATE"
        }
        
        mutating func addLetter(_ letter: Character) {
            if !isSkated {
                letters.append(letter)
                if isSkated {
                    isOut = true
                }
            }
        }
    }
    
    struct GameEvent: Identifiable {
        let id = UUID()
        let player: String
        let trick: String
        let result: EventResult
        let action: ActionType
        let timestamp: Date = Date()
        
        enum EventResult {
            case landed
            case failed
        }
        
        enum ActionType {
            case set
            case attempt
        }
    }
    
    private var activePlayers: [Player] {
        players.filter { !$0.isOut }
    }
    
    private var availableTricks: [Trick] {
        let baseTricks = allTricks.filter { $0.isLearned || $0.isLearning }
        
        var filteredTricks = baseTricks
        
        if let selectedType = selectedTrickType {
            filteredTricks = filteredTricks.filter { $0.type == selectedType }
        }
        
        if !searchText.isEmpty {
            filteredTricks = filteredTricks.filter { 
                $0.name.localizedCaseInsensitiveContains(searchText) 
            }
        }
        
        return filteredTricks
    }
    
    private var currentPlayer: Player? {
        guard !players.isEmpty else { return nil }
        
        switch gamePhase {
        case .settingTrick, .setterAttempting:
            return players.indices.contains(currentTrickSetter) ? players[currentTrickSetter] : nil
        case .attemptingTrick:
            return players.indices.contains(currentAttemptingPlayer) ? players[currentAttemptingPlayer] : nil
        default:
            return nil
        }
    }
    
    private var trickTypes: [TrickType] {
        let uniqueTypes = Set(availableTricks.map { $0.type })
        return Array(uniqueTypes).sorted { $0.rawValue < $1.rawValue }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                switch gamePhase {
                case .setup:
                    setupView
                case .readyToStart:
                    readyToStartView
                case .settingTrick:
                    settingTrickView
                case .setterAttempting:
                    setterAttemptingView
                case .attemptingTrick:
                    attemptingView
                case .gameOver:
                    gameOverView
                }
            }
            .background(Color(.systemBackground))
            .navigationTitle("S.K.A.T.E")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .tint(.secondary)
                }
                
                if gamePhase == .attemptingTrick || gamePhase == .settingTrick || gamePhase == .setterAttempting {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("End Game") {
                            endGame()
                        }
                        .foregroundStyle(.red)
                    }
                }
                
                ToolbarItemGroup(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button {
                            dismissKeyboard()
                        } label: {
                            Image(systemName: "keyboard.chevron.compact.down")
                                .foregroundStyle(.accent)
                        }
                    }
                }
            }
        }
        .onAppear {
            // Initialize focus state array to match players count
            updateFocusStateArray()
        }
        .onChange(of: players.count) {
            updateFocusStateArray()
        }
        .sheet(isPresented: $showingTrickPicker) {
            trickPickerView
        }
    }
    
    private func updateFocusStateArray() {
        focusedField = nil
    }
    
    private func dismissKeyboard() {
        focusedField = nil
    }
    
    @ViewBuilder
    private var setupView: some View {
        ScrollView {
            VStack(spacing: 40) {
                VStack(spacing: 20) {
                    Image(systemName: "figure.skateboarding")
                        .font(.system(size: 60))
                        .foregroundStyle(.accent)
                    
                    VStack(spacing: 8) {
                        Text("S.K.A.T.E Game")
                            .font(.largeTitle.bold())
                            .fontWidth(.expanded)
                        
                        Text("Players take turns setting tricks. Everyone attempts each trick - miss it and get a letter!")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                
                VStack(spacing: 24) {
                    HStack {
                        Text("Players")
                            .font(.title3.bold())
                            .fontWidth(.expanded)
                        Spacer()
                    }
                    
                    VStack(spacing: 16) {
                        ForEach(players.indices, id: \.self) { index in
                            HStack(spacing: 12) {
                                TextField("Player \(index + 1)", text: $players[index].name)
                                    .textInputAutocapitalization(.words)
                                    .padding()
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(
                                                focusedField == .playerName(index) ? 
                                                LinearGradient(gradient: Gradient(colors: [Color.blue, Color.indigo, Color.pink]), startPoint: .topLeading, endPoint: .bottomTrailing) : 
                                                LinearGradient(gradient: Gradient(colors: [Color.secondary.opacity(0.2)]), startPoint: .topLeading, endPoint: .bottomTrailing), 
                                                lineWidth: focusedField == .playerName(index) ? 2 : 1
                                            )
                                    )
                                    .focused($focusedField, equals: .playerName(index))
                                
                                Button(action: {
                                    removePlayer(at: index)
                                }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.red)
                                        .font(.title3)
                                }
                                .disabled(players.count <= 2)
                                .opacity(players.count <= 2 ? 0.3 : 1.0)
                            }
                        }
                        
                        if players.count < 6 {
                            Button(action: addPlayer) {
                                HStack(spacing: 8) {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Add Player")
                                }
                                .foregroundStyle(.accent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                            }
                        }
                    }
                }
                
                Spacer(minLength: 100)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
        .safeAreaInset(edge: .bottom) {
            ZStack {
                VariableBlurView(maxBlurRadius: 4, direction: .blurredTopClearBottom)
                    .frame(height: 100)
                    .ignoresSafeArea(edges: .bottom)
                    .padding(.bottom, -44)
                
                Button("Randomize & Start") {
                    // Randomize starting player
                    currentTrickSetter = Int.random(in: 0..<players.count)
                    gamePhase = .readyToStart
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(.accent, in: RoundedRectangle(cornerRadius: 16))
                .disabled(players.count < 2 || players.contains { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
                .opacity(players.count < 2 || players.contains { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ? 0.6 : 1.0)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            if players.isEmpty {
                addPlayer()
                addPlayer()
            }
        }
    }
    
    @ViewBuilder
    private var readyToStartView: some View {
        VStack(spacing: 0) {
            playerCardsView
            
            VStack(spacing: 32) {
                VStack(spacing: 16) {
                    Image(systemName: "dice.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.accent)
                    
                    Text("Starting Player Selected!")
                        .font(.title2.bold())
                        .fontWidth(.expanded)
                    
                    Text("\(players[currentTrickSetter].name) will set the first trick")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.top, 40)
            
            Spacer()
        }
        .safeAreaInset(edge: .bottom) {
            ZStack {
                VariableBlurView(maxBlurRadius: 4, direction: .blurredTopClearBottom)
                    .frame(height: 100)
                    .ignoresSafeArea(edges: .bottom)
                    .padding(.bottom, -44)
                
                Button("Begin Game") {
                    gamePhase = .settingTrick
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(.accent, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
    }
    
    @ViewBuilder
    private var settingTrickView: some View {
        VStack(spacing: 0) {
            playerCardsView
            
            VStack(spacing: 32) {
                VStack(spacing: 16) {
                    Text("\(players[currentTrickSetter].name)'s Turn to Set")
                        .font(.title2.bold())
                        .fontWidth(.expanded)
                    
                    Text("Choose a trick and attempt to land it")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.top, 40)
            
            Spacer()
            
            if !gameHistory.isEmpty {
                gameHistoryView
            }
        }
        .safeAreaInset(edge: .bottom) {
            ZStack {
                VariableBlurView(maxBlurRadius: 4, direction: .blurredTopClearBottom)
                    .frame(height: 100)
                    .ignoresSafeArea(edges: .bottom)
                    .padding(.bottom, -44)
                
                Button("Choose Trick") {
                    showingTrickPicker = true
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(.accent, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
    }
    
    @ViewBuilder
    private var setterAttemptingView: some View {
        VStack(spacing: 0) {
            playerCardsView
            
            if let selectedTrick = selectedTrick {
                VStack(spacing: 32) {
                    VStack(spacing: 20) {
                        VStack(spacing: 8) {
                            Text("Setting Trick")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            Text(selectedTrick.name)
                                .font(.title.bold())
                                .fontWidth(.expanded)
                                .multilineTextAlignment(.center)
                        }
                        
                        Text("\(players[currentTrickSetter].name) attempts to set the trick")
                            .font(.title3.bold())
                            .fontWidth(.expanded)
                            .foregroundStyle(.accent)
                    }
                    .padding(.top, 40)
                    .padding(.horizontal, 20)
                    
                    HStack(spacing: 12) {
                        Button("Landed") {
                            handleSetterResult(landed: true)
                        }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.roundedRectangle(radius: 16))
                        .controlSize(.large)
                        
                        Button("Bailed") {
                            handleSetterResult(landed: false)
                        }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.roundedRectangle(radius: 16))
                        .controlSize(.large)
                    }
                    .padding(.horizontal, 20)
                }
            }
            
            Spacer()
            
            if !gameHistory.isEmpty {
                gameHistoryView
            }
        }
    }
    
    @ViewBuilder
    private var attemptingView: some View {
        VStack(spacing: 0) {
            playerCardsView
            
            if let selectedTrick = selectedTrick {
                VStack(spacing: 32) {
                    VStack(spacing: 20) {
                        VStack(spacing: 8) {
                            Text("Current Trick")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            Text(selectedTrick.name)
                                .font(.title.bold())
                                .fontWidth(.expanded)
                                .multilineTextAlignment(.center)
                        }
                        
                        Text("\(players[currentAttemptingPlayer].name)'s Turn")
                            .font(.title3.bold())
                            .fontWidth(.expanded)
                            .foregroundStyle(.accent)
                    }
                    .padding(.top, 40)
                    .padding(.horizontal, 20)
                    
                    HStack(spacing: 12) {
                        Button("Landed") {
                            handleTrickResult(landed: true)
                        }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.roundedRectangle(radius: 16))
                        .controlSize(.large)
                        
                        Button("Bailed") {
                            handleTrickResult(landed: false)
                        }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.roundedRectangle(radius: 16))
                        .controlSize(.large)
                    }
                    .padding(.horizontal, 20)
                }
            }
            
            Spacer()
            
            if !gameHistory.isEmpty {
                gameHistoryView
            }
        }
    }
    
    @ViewBuilder
    private var gameOverView: some View {
        ScrollView {
            VStack(spacing: 40) {
                VStack(spacing: 20) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.yellow)
                    
                    VStack(spacing: 8) {
                        Text("Game Over!")
                            .font(.largeTitle.bold())
                            .fontWidth(.expanded)
                        
                        if let winner = winner {
                            Text("\(winner.name) Wins!")
                                .font(.title2)
                                .fontWidth(.expanded)
                                .foregroundStyle(.accent)
                        }
                    }
                }
                
                VStack(spacing: 20) {
                    HStack {
                        Text("Final Results")
                            .font(.title3.bold())
                            .fontWidth(.expanded)
                        Spacer()
                    }
                    
                    VStack(spacing: 16) {
                        ForEach(players.sorted { !$0.isOut && $1.isOut }) { player in
                            HStack {
                                Text(player.name)
                                    .font(.headline)
                                Spacer()
                                Text(player.letters.isEmpty ? "Winner!" : player.letters)
                                    .font(.headline)
                                    .foregroundStyle(player.isOut ? .red : .green)
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
                
                Spacer(minLength: 140)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
        .safeAreaInset(edge: .bottom) {
            ZStack {
                VariableBlurView(maxBlurRadius: 4, direction: .blurredTopClearBottom)
                    .frame(height: 140)
                    .ignoresSafeArea(edges: .bottom)
                    .padding(.bottom, -44)
                
                VStack(spacing: 12) {
                    Button("Play Again") {
                        resetGame()
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.accent, in: RoundedRectangle(cornerRadius: 16))
                    
                    Button("New Players") {
                        gamePhase = .setup
                        players.removeAll()
                        resetGameState()
                    }
                    .font(.headline)
                    .foregroundStyle(.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
    }
    
    @ViewBuilder
    private var playerCardsView: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Players")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(players.indices, id: \.self) { index in
                        let player = players[index]
                        let isCurrentPlayer = (gamePhase == .settingTrick && index == currentTrickSetter) ||
                                            (gamePhase == .setterAttempting && index == currentTrickSetter) ||
                                            (gamePhase == .attemptingTrick && index == currentAttemptingPlayer)
                        
                        VStack(spacing: 12) {
                            Text(player.name)
                                .font(.subheadline.bold())
                                .lineLimit(1)
                                .foregroundStyle(isCurrentPlayer ? .white : .primary)
                            
                            HStack(spacing: 4) {
                                ForEach(Array("SKATE"), id: \.self) { letter in
                                    Text(String(letter))
                                        .font(.caption.bold())
                                        .frame(width: 20, height: 20)
                                        .background(player.letters.contains(letter) ? .red : Color(.systemGray5))
                                        .foregroundStyle(player.letters.contains(letter) ? .white : .secondary)
                                        .clipShape(Circle())
                                }
                            }
                            
                            if player.isOut {
                                Text("OUT")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.red)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.red.opacity(0.1), in: Capsule())
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(isCurrentPlayer ? .accent : Color(.systemGray6))
                        )
                        .scaleEffect(isCurrentPlayer ? 1.05 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: isCurrentPlayer)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 4)
            }
        }
        .padding(.top, 20)
    }
    
    @ViewBuilder
    private var gameHistoryView: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Recent Events")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 20)
            
            VStack(spacing: 8) {
                ForEach(gameHistory.suffix(5).reversed(), id: \.id) { event in
                    HStack {
                        Text(event.player)
                            .font(.subheadline.bold())
                        Text(event.trick)
                            .font(.subheadline)
                            .lineLimit(1)
                        Spacer()
                        Group {
                            switch event.result {
                            case .landed:
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            case .failed:
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.red)
                            }
                        }
                        .font(.subheadline)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
            }
        }
        .padding(.bottom, 20)
    }
    
    @ViewBuilder
    private var trickPickerView: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search and filter section
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)
                            TextField("Search tricks...", text: $searchText)
                                .focused($focusedField, equals: .search)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(
                                    focusedField == .search ? 
                                    LinearGradient(gradient: Gradient(colors: [Color.blue, Color.indigo, Color.pink]), startPoint: .topLeading, endPoint: .bottomTrailing) : 
                                    LinearGradient(gradient: Gradient(colors: [Color.secondary.opacity(0.2)]), startPoint: .topLeading, endPoint: .bottomTrailing), 
                                    lineWidth: focusedField == .search ? 2 : 1
                                )
                        )
                        
                        Menu {
                            Button("All Types") {
                                selectedTrickType = nil
                            }
                            
                            ForEach(trickTypes, id: \.self) { type in
                                Button(type.rawValue) {
                                    selectedTrickType = type
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "line.3.horizontal.decrease.circle")
                                if let selectedType = selectedTrickType {
                                    Text(selectedType.rawValue)
                                        .font(.caption)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(selectedTrickType != nil ? .accent.opacity(0.1) : Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(selectedTrickType != nil ? .accent : .secondary)
                        }
                    }
                    
                    if selectedTrickType != nil {
                        HStack {
                            Button("Clear Filter") {
                                selectedTrickType = nil
                            }
                            .font(.caption)
                            .foregroundStyle(.accent)
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color(.systemBackground))
                
                // Tricks list
                if availableTricks.isEmpty {
                    VStack(spacing: 20) {
                        Spacer()
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.orange)
                        VStack(spacing: 8) {
                            Text("No tricks available")
                                .font(.headline)
                            Text("Try learning some tricks first or adjust your filter")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 1) {
                            ForEach(availableTricks, id: \.id) { trick in
                                Button(action: {
                                    selectedTrick = trick
                                    showingTrickPicker = false
                                    startRound()
                                }) {
                                    HStack(spacing: 16) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(trick.name)
                                                .font(.headline)
                                                .foregroundStyle(.primary)
                                            
                                            HStack(spacing: 8) {
                                                Text("Difficulty: \(trick.difficulty)")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                
                                                Text("•")
                                                    .foregroundStyle(.secondary)
                                                
                                                Text(trick.type.rawValue)
                                                    .font(.caption)
                                                    .foregroundStyle(.accent)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(.accent.opacity(0.1), in: Capsule())
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        Group {
                                            if trick.isLearned {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundStyle(.green)
                                            } else {
                                                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                                                    .foregroundStyle(.orange)
                                            }
                                        }
                                        .font(.title3)
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 16)
                                    .background(Color(.systemBackground))
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Choose Trick")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        showingTrickPicker = false
                    }
                }
                
                ToolbarItemGroup(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button {
                            dismissKeyboard()
                        } label: {
                            Image(systemName: "keyboard.chevron.compact.down")
                                .foregroundStyle(.accent)
                        }
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    
    private func addPlayer() {
        let playerNumber = players.count + 1
        players.append(Player(name: "Player \(playerNumber)"))
    }
    
    private func removePlayer(at index: Int) {
        players.remove(at: index)
    }
    
    private func startGame() {
        gamePhase = .settingTrick
        currentTrickSetter = 0
        currentAttemptingPlayer = 0
        gameHistory.removeAll()
        playersAttempting.removeAll()
        
        // Reset all players
        for i in players.indices {
            players[i].letters = ""
            players[i].isOut = false
        }
        
        // Skip to first active player
        while players[currentTrickSetter].isOut && activePlayers.count > 1 {
            nextTrickSetter()
        }
    }
    
    private func startRound() {
        gamePhase = .setterAttempting
        playersAttempting.removeAll()
    }
    
    private func handleTrickResult(landed: Bool) {
        guard let selectedTrick = selectedTrick else { return }
        
        let event = GameEvent(
            player: players[currentAttemptingPlayer].name,
            trick: selectedTrick.name,
            result: landed ? .landed : .failed,
            action: .attempt
        )
        gameHistory.append(event)
        
        if !landed {
            let skateLetters = Array("SKATE")
            let currentPlayer = players[currentAttemptingPlayer]
            if let letterIndex = skateLetters.firstIndex(where: { letter in
                !currentPlayer.letters.contains(letter)
            }) {
                players[currentAttemptingPlayer].addLetter(skateLetters[letterIndex])
            }
        }
        
        playersAttempting[currentAttemptingPlayer] = true
        
        // Check if all active players have attempted
        let activePlayerIndices = players.indices.filter { !players[$0].isOut }
        let allAttempted = activePlayerIndices.allSatisfy { playersAttempting[$0] == true }
        
        if allAttempted {
            // Round complete, check for game over
            let remainingPlayers = players.filter { !$0.isOut }
            if remainingPlayers.count <= 1 {
                winner = remainingPlayers.first
                gamePhase = .gameOver
                return
            }
            
            // Setter continues setting tricks (doesn't rotate to next player)
            gamePhase = .settingTrick
            self.selectedTrick = nil
        } else {
            // Move to next player for attempting
            nextAttemptingPlayer()
        }
    }
    
    private func nextTrickSetter() {
        repeat {
            currentTrickSetter = (currentTrickSetter + 1) % players.count
        } while players[currentTrickSetter].isOut && activePlayers.count > 1
    }
    
    private func nextAttemptingPlayer() {
        repeat {
            currentAttemptingPlayer = (currentAttemptingPlayer + 1) % players.count
        } while (players[currentAttemptingPlayer].isOut || playersAttempting[currentAttemptingPlayer] == true) && activePlayers.count > 1
    }
    
    private func endGame() {
        let remainingPlayers = activePlayers
        winner = remainingPlayers.min { $0.letters.count < $1.letters.count }
        gamePhase = .gameOver
    }
    
    private func resetGame() {
        gamePhase = .settingTrick
        currentTrickSetter = 0
        currentAttemptingPlayer = 0
        self.selectedTrick = nil
        gameHistory.removeAll()
        winner = nil
        playersAttempting.removeAll()
        
        for i in players.indices {
            players[i].letters = ""
            players[i].isOut = false
        }
    }
    
    private func resetGameState() {
        self.selectedTrick = nil
        gameHistory.removeAll()
        winner = nil
        currentTrickSetter = 0
        currentAttemptingPlayer = 0
        playersAttempting.removeAll()
    }
    
    private func handleSetterResult(landed: Bool) {
        guard let selectedTrick = selectedTrick else { return }
        
        let event = GameEvent(
            player: players[currentTrickSetter].name,
            trick: selectedTrick.name,
            result: landed ? .landed : .failed,
            action: .set
        )
        gameHistory.append(event)
        
        if landed {
            // Setter landed the trick, now others must attempt it
            playersAttempting.removeAll()
            playersAttempting[currentTrickSetter] = true // Setter automatically "landed" it
            
            // Find first player (excluding setter) to attempt
            currentAttemptingPlayer = (currentTrickSetter + 1) % players.count
            while players[currentAttemptingPlayer].isOut && activePlayers.count > 1 {
                nextAttemptingPlayer()
            }
            
            gamePhase = .attemptingTrick
        } else {
            // Setter missed setting the trick, no letter given - just move to next setter
            // Check for game over
            let remainingPlayers = players.filter { !$0.isOut }
            if remainingPlayers.count <= 1 {
                winner = remainingPlayers.first
                gamePhase = .gameOver
                return
            }
            
            // Move to next trick setter
            nextTrickSetter()
            gamePhase = .settingTrick
            self.selectedTrick = nil
        }
    }
}

#Preview {
    SKATEGameView()
        .modelContainer(for: [Trick.self, SkateSession.self], inMemory: true)
} 
