//
//  Parser.swift
//  LaTeXSwiftUI
//
//  Created by Colin Campbell on 11/30/22.
//

import Foundation

/// Parses LaTeX equations.
@available(iOS 16.1, *)
internal struct Parser {
  
  // MARK: Types
  
  /// An equation component.
  private struct EquationComponent<T, U> {
    let regex: Regex<T>
    let terminatingRegex: Regex<U>
    let equation: Component.ComponentType
    let supportsRecursion: Bool
  }
  
  // MARK: Private properties
  
  /// An inline equation component.
  private static let inline = EquationComponent(
    regex: #/\$(.|\s)*?\$/#, //\$\$(.|\s)*?\$\$
    terminatingRegex: #/\$/#,
    equation: .inlineEquation,
    supportsRecursion: false)
  
  /// An TeX-style block equation component.
  private static let texBlock = EquationComponent(
    regex: #/\$\$(.|\s)*?\$\$/#,
    terminatingRegex: #/\$\$/#,
    equation: .texBlockEquation,
    supportsRecursion: false)
  
  /// A named equation component.
  private static let named = EquationComponent(
    regex: #/\\begin{equation}(.|\s)*\\end{equation}/#,
    terminatingRegex: #/\\end{equation}/#,
    equation: .namedEquation,
    supportsRecursion: true)
  
  // Order matters
  private static let allEquations = [inline, texBlock, named]
  
}

// MARK: Static methods

@available(iOS 16.1, *)
extension Parser {
  
  /// Parses the input text for component blocks.
  ///
  /// - Parameters:
  ///   - text: The input text.
  ///   - mode: The rendering mode.
  /// - Returns: An array of component blocks.
  static func parse(_ text: String, mode: LaTeX.RenderingMode) -> [ComponentBlock] {
    let components = mode == .all ? [Component(text: text, type: .inlineEquation)] : parse(text)
    var blocks = [ComponentBlock]()
    var blockComponents = [Component]()
    for component in components {
      if component.type.inline {
        blockComponents.append(component)
      }
      else {
        blocks.append(ComponentBlock(components: blockComponents))
        blocks.append(ComponentBlock(components: [component]))
        blockComponents.removeAll()
      }
    }
    if !blockComponents.isEmpty {
      blocks.append(ComponentBlock(components: blockComponents))
    }
    return blocks
  }
  
  /// Parses an input string for LaTeX components.
  ///
  /// - Parameter input: The input string.
  /// - Returns: An array of LaTeX components.
  static func parse(_ input: String) -> [Component] {
    let matches = allEquations.map({ ($0, input.firstMatch(of: $0.regex)) }).filter { match in
      guard let range = match.1?.range else { return false }
      let firstIndex = range.lowerBound
      let lastIndex = range.upperBound
      let componentIsEmpty = Component(text: String(input[range]), type: match.0.equation).text.isEmpty
      let previousIndexLast = input.index(lastIndex, offsetBy: -1 - match.0.equation.rightTerminator.count)
      
      if firstIndex == input.startIndex {
        return input[previousIndexLast] != "\\" && !componentIsEmpty
      }
      
      let previousIndexFirst = input.index(before: firstIndex)
      return input[previousIndexFirst] != "\\" && input[previousIndexLast] != "\\" && !componentIsEmpty
    }
    
    let allStart = matches.map({ $0.1?.range.lowerBound })
    var equationRange: Range<String.Index>?
    var equation: Component.ComponentType = .text
    
    for match in matches {
      guard isSmallest(match.1?.range.lowerBound, outOf: allStart) else {
        continue
      }
      guard let matchRange = match.1?.range else {
        continue
      }
      
      if match.0.supportsRecursion {
        let terminatingMatches = input.matches(of: match.0.terminatingRegex).filter { match in
          let index = match.range.lowerBound
          if index == input.startIndex { return true }
          let previousIndex = input.index(before: index)
          return input[previousIndex] != "\\"
        }
        if let lastMatch = terminatingMatches.last {
          equationRange = matchRange.lowerBound ..< lastMatch.range.upperBound
        }
      }
      else {
        equationRange = match.1?.range
      }
      
      if equationRange != nil {
        equation = match.0.equation
        break
      }
    }
    
    if let equationRange = equationRange {
      let stringBeforeEquation = String(input[..<equationRange.lowerBound])
      let equationString = String(input[equationRange])
      let remainingString = String(input[equationRange.upperBound...])
      var components = [Component]()
      if !stringBeforeEquation.isEmpty {
        components.append(Component(text: stringBeforeEquation, type: .text))
      }
      components.append(Component(text: equationString, type: equation))
      if remainingString.isEmpty {
        return components
      }
      else {
        return components + parse(remainingString)
      }
    }
    
    return input.isEmpty ? [] : [Component(text: input, type: .text)]
  }
  
}

// MARK: Private static methods

@available(iOS 16.1, *)
extension Parser {
  
  /// Determines if an index is smaller than all of the indexes in another
  /// array.
  ///
  /// - Parameters:
  ///   - index: The index to compare.
  ///   - indexes: The indexes. The value `index` should not be present in this.
  /// - Returns: A boolean.
  private static func isSmallest(_ index: String.Index?, outOf indexes: [String.Index?]) -> Bool {
    guard let index = index else { return false }
    let indexes = indexes.filter({ $0 != nil }).map({ $0! }) as! [String.Index]
    return indexes.first(where: { $0 < index }) == nil
  }
  
}