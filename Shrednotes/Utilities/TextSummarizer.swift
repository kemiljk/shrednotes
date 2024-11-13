//
//  TextSummarizer.swift
//  Shrednotes
//
//  Created by Karl Koch on 12/11/2024.
//

import Foundation
import NaturalLanguage

class TextSummarizer {
    private let sentenceLimit = 2
    private let minimumWordCount = 3
    private let sentenceScoreThreshold = 0.3
    private let tricks: [Trick]
    
    init(tricks: [Trick]) {
        self.tricks = tricks
    }
    
    // Achievement and milestone related words
    private let achievementWords = Set([
        "landed", "first", "achieved", "managed", "finally", "learned", "mastered",
        "accomplished", "won", "succeeded", "completed", "breakthrough", "milestone",
        "personal best", "pb", "record", "improved"
    ])
    
    // Emotional content words
    private let emotionalWords = Set([
        "happy", "excited", "proud", "surprised", "amazed", "unbelievably",
        "unexpected", "shocked", "pleased", "confident", "scared", "nervous",
        "worried", "frustrated", "disappointed", "stoked", "hyped"
    ])
    
    // Common skating slang and informal terms
    private let colloquialTerms: [String: Double] = [
        "toe dragger": 1.5,
        "sketchy": 1.2,
        "steez": 1.3,
        "stomped": 1.4,
        "bailed": 1.2,
        "steezy": 1.3,
        "sent it": 1.4,
        "pop": 1.2,
        "catch": 1.2,
        "butter": 1.3,
        "clean": 1.3,
        "flow": 1.2
    ]
    
    // Safe word tokenization
    private func tokenizeWords(_ text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .word)
        let textToTokenize = text
        tokenizer.string = textToTokenize
        
        let range = textToTokenize.startIndex..<textToTokenize.endIndex
        
        return tokenizer.tokens(for: range).map {
            String(textToTokenize[$0]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    
    // Safe sentence tokenization
    private func tokenizeSentences(_ text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .sentence)
        let textToTokenize = text
        tokenizer.string = textToTokenize
        
        let range = textToTokenize.startIndex..<textToTokenize.endIndex
        
        return tokenizer.tokens(for: range).map {
            String(textToTokenize[$0]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    
    private func calculateWordFrequencies(_ text: String) -> [String: Double] {
        var wordFreq: [String: Double] = [:]
        let words = tokenizeWords(text.lowercased())
        
        for word in words {
            if word.count >= minimumWordCount {
                var score = 1.0
                
                if achievementWords.contains(word) {
                    score *= 2.0
                }
                
                if emotionalWords.contains(word) {
                    score *= 1.5
                }
                
                wordFreq[word, default: 0] += score
            }
        }
        
        // Check for tricks in the text
        for trick in tricks {
            if text.lowercased().contains(trick.name.lowercased()) {
                let trickWords = trick.name.lowercased().split(separator: " ")
                for word in trickWords {
                    let difficultyBoost = calculateDifficultyBoost(trick)
                    wordFreq[String(word), default: 0] *= difficultyBoost
                }
            }
        }
        
        // Check for colloquial phrases
        for (phrase, boost) in colloquialTerms {
            if text.lowercased().contains(phrase) {
                let words = phrase.split(separator: " ")
                for word in words {
                    wordFreq[String(word), default: 0] *= boost
                }
            }
        }
        
        // Normalize frequencies
        let maxFreq = wordFreq.values.max() ?? 1
        wordFreq = wordFreq.mapValues { $0 / maxFreq }
        
        return wordFreq
    }
    
    private func calculateDifficultyBoost(_ trick: Trick) -> Double {
        if trick.name.lowercased().contains("double") {
            return 2.5
        } else if trick.name.lowercased().contains("360") {
            return 2.0
        } else if trick.name.lowercased().contains("varial") {
            return 1.9
        } else if trick.name.lowercased().contains("flip") {
            return 1.8
        }
        return 1.5
    }
    
    private func scoreSentences(_ sentences: [String], wordFreq: [String: Double]) -> [(sentence: String, score: Double)] {
        return sentences.map { sentence in
            let words = tokenizeWords(sentence.lowercased())
            var score = 0.0
            
            var hasAchievement = false
            var hasEmotion = false
            var hasColloquial = false
            var hasTrick = false
            
            // Check for known tricks
            for trick in tricks {
                if sentence.lowercased().contains(trick.name.lowercased()) {
                    hasTrick = true
                    if achievementWords.contains(where: { sentence.lowercased().contains($0) }) {
                        score += calculateDifficultyBoost(trick)
                    }
                }
            }
            
            hasAchievement = achievementWords.contains { sentence.lowercased().contains($0) }
            hasEmotion = emotionalWords.contains { sentence.lowercased().contains($0) }
            hasColloquial = colloquialTerms.keys.contains { sentence.lowercased().contains($0) }
            
            for word in words {
                if let freq = wordFreq[word.lowercased()] {
                    score += freq
                }
            }
            
            var normalizedScore = words.isEmpty ? 0 : score / Double(words.count)
            if hasAchievement { normalizedScore *= 1.5 }
            if hasEmotion { normalizedScore *= 1.3 }
            if hasColloquial { normalizedScore *= 1.2 }
            if hasTrick { normalizedScore *= 1.4 }
            
            return (sentence, normalizedScore)
        }
    }
    
    private func generateTrickSummary(tricks: [Trick], date: Date) -> String {
        let trickCount = tricks.count
        
        // Group tricks by type
        let flipTricks = tricks.filter { $0.type == .flip }
        let nollieTricks = tricks.filter { $0.name.lowercased().contains("nollie") }
        let grindTricks = tricks.filter { $0.type == .grind }
        let slideTricks = tricks.filter { $0.type == .slide }
        let shoveTricks = tricks.filter { $0.type == .shuvit }
        
        // Varied opening phrases
        let openingPhrases = [
            "Solid session with ",
            "Good progress landing ",
            "Productive day getting ",
            "Nice session nailing ",
            "Strong session landing ",
            "Stoked to get ",
            "Great day locking in ",
            "Successful session with ",
            "Happy with landing ",
            "Decent day getting "
        ]
        
        // Use the date to deterministically select a phrase
        let dayComponent = Calendar.current.component(.day, from: date)
        let selectedPhraseIndex = dayComponent % openingPhrases.count
        var summaryText = openingPhrases[selectedPhraseIndex]
        
        if trickCount > 5 {
            // Many tricks - summarize by type
            var trickTypes: [String] = []
            if !flipTricks.isEmpty {
                trickTypes.append("\(flipTricks.count) flip trick\(flipTricks.count > 1 ? "s" : "")")
            }
            if !nollieTricks.isEmpty {
                trickTypes.append("\(nollieTricks.count) nollie trick\(nollieTricks.count > 1 ? "s" : "")")
            }
            if !grindTricks.isEmpty {
                trickTypes.append("\(grindTricks.count) grind\(grindTricks.count > 1 ? "s" : "")")
            }
            if !slideTricks.isEmpty {
                trickTypes.append("\(slideTricks.count) slide\(slideTricks.count > 1 ? "s" : "")")
            }
            if !shoveTricks.isEmpty {
                trickTypes.append("\(shoveTricks.count) shove it\(shoveTricks.count > 1 ? "s" : "")")
            }
            
            // Handle comma separation and "and" for the last item if there are multiple types
            if trickTypes.count > 1 {
                let lastType = trickTypes.removeLast()
                summaryText += trickTypes.joined(separator: ", ") + " and " + lastType + "."
            } else if let singleType = trickTypes.first {
                summaryText += singleType + "."
            }
        } else {
            // Few tricks - list them specifically
            let trickNames = tricks.map { $0.name }
            if trickNames.count > 1 {
                var names = trickNames
                let lastTrick = names.removeLast()
                summaryText += names.joined(separator: ", ") + " and " + lastTrick + "."
            } else if let singleTrick = trickNames.first {
                summaryText += singleTrick + "."
            }
        }
        
        return summaryText
    }
    
    func summarizeSession(notes: String, landedTricks: [Trick], date: Date) -> String {
        let sentences = tokenizeSentences(notes)
        let scoredSentences = scoreSentences(sentences, wordFreq: calculateWordFrequencies(notes))
        
        // Get the most relevant sentences from notes
        let topSentences = scoredSentences
            .sorted { $0.score > $1.score }
            .prefix(sentenceLimit)
            .map { $0.sentence }
            .sorted { sentences.firstIndex(of: $0)! < sentences.firstIndex(of: $1)! }
        
        let contextSummary = topSentences.joined(separator: " ")
        
        if !landedTricks.isEmpty {
            let trickSummary = generateTrickSummary(tricks: landedTricks, date: date)
            
            if let highestScoredSentence = scoredSentences.first,
               highestScoredSentence.score > 0.7 {
                return [trickSummary, highestScoredSentence.sentence].joined(separator: " ")
            } else {
                return [contextSummary, trickSummary].joined(separator: " ")
            }
        }
        
        return contextSummary
    }
}
