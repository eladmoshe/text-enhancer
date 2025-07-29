import Foundation

// MARK: - Response Model

struct EnhancementResponse: Codable {
    let enhancedText: String
    let model: String?
    let notes: String?
}

// MARK: - Error Types

enum JSONParseError: Error {
    case invalidUTF8
    case noJSONFound
    case invalidJSON(Error)
    case missingRequiredField(String)
}

extension JSONParseError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidUTF8:
            return "⚠️ Invalid response encoding from API"
        case .noJSONFound:
            return "⚠️ API returned unexpected response format"
        case .invalidJSON(let error):
            return "⚠️ Invalid response format: \(error.localizedDescription)"
        case .missingRequiredField(let field):
            return "⚠️ Incomplete response from API (missing: \(field))"
        }
    }
}

// MARK: - JSON Extractor

class JSONExtractor {
    
    /// Extracts and parses JSON from a potentially messy model response
    /// Handles common issues like prefixes, markdown code blocks, and extra whitespace
    static func extractJSONPayload(from rawResponse: String) throws -> EnhancementResponse {
        let cleaned = cleanResponse(rawResponse)
        
        guard let data = cleaned.data(using: .utf8) else {
            throw JSONParseError.invalidUTF8
        }
        
        do {
            let response = try JSONDecoder().decode(EnhancementResponse.self, from: data)
            
            // Validate required fields
            if response.enhancedText.isEmpty {
                throw JSONParseError.missingRequiredField("enhancedText")
            }
            
            return response
        } catch let decodingError {
            throw JSONParseError.invalidJSON(decodingError)
        }
    }
    
    /// Cleans up the raw response by removing prefixes and extracting JSON content
    private static func cleanResponse(_ response: String) -> String {
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check if response is wrapped in markdown code blocks
        if trimmed.contains("```") {
            return extractFromCodeBlock(trimmed)
        }
        
        // Find JSON object boundaries
        return extractJSONObject(trimmed)
    }
    
    /// Extracts JSON from markdown code blocks (```json ... ```)
    private static func extractFromCodeBlock(_ response: String) -> String {
        let lines = response.components(separatedBy: .newlines)
        var insideCodeBlock = false
        var jsonLines: [String] = []
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            if trimmedLine.hasPrefix("```") {
                if insideCodeBlock {
                    // End of code block
                    break
                } else {
                    // Start of code block
                    insideCodeBlock = true
                    continue
                }
            }
            
            if insideCodeBlock {
                jsonLines.append(line)
            }
        }
        
        let extracted = jsonLines.joined(separator: "\n")
        return extracted.isEmpty ? extractJSONObject(response) : extracted
    }
    
    /// Extracts JSON object by finding the first complete JSON object
    private static func extractJSONObject(_ response: String) -> String {
        // First try to find all potential JSON objects
        let possibleJSONs = findAllJSONObjects(in: response)
        
        // Try each potential JSON object until we find one that works
        for jsonCandidate in possibleJSONs where isValidJSON(jsonCandidate) {
            return jsonCandidate
        }
        
        // Fall back to original simple extraction
        guard let startIndex = response.firstIndex(of: "{") else {
            return response // Return as-is if no opening brace found
        }
        
        var braceCount = 0
        var currentIndex = startIndex
        
        // Find the matching closing brace
        while currentIndex < response.endIndex {
            let char = response[currentIndex]
            if char == "{" {
                braceCount += 1
            } else if char == "}" {
                braceCount -= 1
                if braceCount == 0 {
                    // Found the complete JSON object
                    let jsonRange = startIndex...currentIndex
                    return String(response[jsonRange])
                }
            }
            currentIndex = response.index(after: currentIndex)
        }
        
        // If we didn't find a complete JSON object, fall back to the original logic
        if let endIndex = response.lastIndex(of: "}") {
            let jsonRange = startIndex...endIndex
            return String(response[jsonRange])
        }
        
        return response
    }
    
    /// Finds all potential JSON objects in the response
    private static func findAllJSONObjects(in response: String) -> [String] {
        var objects: [String] = []
        var currentIndex = response.startIndex
        
        while currentIndex < response.endIndex {
            if response[currentIndex] == "{" {
                var braceCount = 0
                let jsonStart = currentIndex
                var jsonEnd = currentIndex
                
                // Find the matching closing brace for this opening brace
                while currentIndex < response.endIndex {
                    let char = response[currentIndex]
                    if char == "{" {
                        braceCount += 1
                    } else if char == "}" {
                        braceCount -= 1
                        if braceCount == 0 {
                            jsonEnd = currentIndex
                            let jsonRange = jsonStart...jsonEnd
                            let jsonCandidate = String(response[jsonRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                            objects.append(jsonCandidate)
                            break
                        }
                    }
                    currentIndex = response.index(after: currentIndex)
                }
            }
            
            if currentIndex < response.endIndex {
                currentIndex = response.index(after: currentIndex)
            }
        }
        
        return objects
    }
    
    /// Checks if a string is valid JSON
    private static func isValidJSON(_ string: String) -> Bool {
        guard let data = string.data(using: .utf8) else { return false }
        do {
            _ = try JSONSerialization.jsonObject(with: data, options: [])
            return true
        } catch {
            return false
        }
    }
} 