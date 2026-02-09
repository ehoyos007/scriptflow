//
//  BranchManager.swift
//  ScriptFlow
//
//  Manages which branch conditions are highlighted in the teleprompter.
//  When no conditions are selected (neutral mode), all branches render equally.
//  When one or more are selected, matching branch content stays bright and
//  non-matching content dims to 25% opacity.
//

import Foundation

@Observable
class BranchManager {
    var highlightedConditions: Set<String> = []

    func toggle(_ condition: String) {
        if highlightedConditions.contains(condition) {
            highlightedConditions.remove(condition)
        } else {
            highlightedConditions.insert(condition)
        }
    }

    /// Returns true when this word should be dimmed:
    /// set is non-empty AND word's branchCondition is non-nil AND not in the set.
    /// Top-level words (nil branchCondition) are never dimmed.
    func shouldDim(branchCondition: String?) -> Bool {
        guard !highlightedConditions.isEmpty else { return false }
        guard let condition = branchCondition else { return false }
        return !highlightedConditions.contains(condition)
    }

    /// Opacity for a word given its branch condition.
    func opacity(for branchCondition: String?) -> Double {
        shouldDim(branchCondition: branchCondition) ? 0.25 : 1.0
    }

    /// Whether a specific condition is currently highlighted.
    func isHighlighted(_ condition: String) -> Bool {
        highlightedConditions.contains(condition)
    }

    func clearAll() {
        highlightedConditions.removeAll()
    }
}
