import Foundation

class AIService {
    static let shared = AIService()

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = false
        config.httpMaximumConnectionsPerHost = 4
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: config)
    }

    /// Calculate appropriate max_tokens based on input length to reduce latency
    private func calculateMaxTokens(for text: String) -> Int {
        let estimatedInputTokens = text.count / 4
        // Allow 2x input for transformations, clamped between 256 and 2048
        return max(256, min(estimatedInputTokens * 2, 2048))
    }
    
    func transform(text: String, prompt: Prompt, settings: SettingsManager) async throws -> String {
        switch settings.selectedProvider {
        case .openai:
            return try await callOpenAI(text: text, instruction: prompt.instruction, apiKey: settings.openAIKey, model: settings.selectedModel)
        case .anthropic:
            return try await callAnthropic(text: text, instruction: prompt.instruction, apiKey: settings.anthropicKey, model: settings.selectedModel)
        case .groq:
            return try await callGroq(text: text, instruction: prompt.instruction, apiKey: settings.groqKey, model: settings.selectedModel)
        case .gemini:
            return try await callGemini(text: text, instruction: prompt.instruction, apiKey: settings.geminiKey, model: settings.selectedModel)
        }
    }
    
    // MARK: - OpenAI (Responses API)
    private func callOpenAI(text: String, instruction: String, apiKey: String, model: String) async throws -> String {
        guard let url = URL(string: "https://api.openai.com/v1/responses") else {
            throw AIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Check if this is a GPT-5 family model (needs reasoning/verbosity params)
        let isGPT5Model = model.hasPrefix("gpt-5")

        var body: [String: Any] = [
            "model": model,
            "instructions": instruction,
            "input": text,
            "store": false
        ]

        if isGPT5Model {
            // GPT-5 models: disable reasoning, use low verbosity for faster responses
            body["reasoning"] = ["effort": "none"]
            body["text"] = ["verbosity": "low"]
        } else {
            // GPT-4.1 and older: use temperature
            body["temperature"] = 0.3
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJson["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw AIError.apiError(message)
            }
            throw AIError.apiError("HTTP \(httpResponse.statusCode)")
        }

        // Parse Responses API format: output[0].content[0].text
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let output = json?["output"] as? [[String: Any]],
              let firstOutput = output.first,
              let content = firstOutput["content"] as? [[String: Any]],
              let firstContent = content.first,
              let responseText = firstContent["text"] as? String else {
            throw AIError.parseError
        }

        return responseText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Anthropic
    private func callAnthropic(text: String, instruction: String, apiKey: String, model: String) async throws -> String {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw AIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": model,
            "max_tokens": calculateMaxTokens(for: text),
            "system": instruction,
            "messages": [
                ["role": "user", "content": text]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJson["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw AIError.apiError(message)
            }
            throw AIError.apiError("HTTP \(httpResponse.statusCode)")
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let content = json?["content"] as? [[String: Any]],
              let firstBlock = content.first,
              let text = firstBlock["text"] as? String else {
            throw AIError.parseError
        }
        
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Groq
    private func callGroq(text: String, instruction: String, apiKey: String, model: String) async throws -> String {
        guard let url = URL(string: "https://api.groq.com/openai/v1/chat/completions") else {
            throw AIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": instruction],
                ["role": "user", "content": text]
            ],
            "temperature": 0.3,
            "max_tokens": calculateMaxTokens(for: text)
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJson["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw AIError.apiError(message)
            }
            throw AIError.apiError("HTTP \(httpResponse.statusCode)")
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let choices = json?["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIError.parseError
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Gemini
    private func callGemini(text: String, instruction: String, apiKey: String, model: String) async throws -> String {
        guard let encodedModel = model.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(encodedModel):generateContent") else {
            throw AIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")

        let body: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": "\(instruction)\n\n\(text)"]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.3,
                "maxOutputTokens": calculateMaxTokens(for: text)
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJson["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw AIError.apiError(message)
            }
            throw AIError.apiError("HTTP \(httpResponse.statusCode)")
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let candidates = json?["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            throw AIError.parseError
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum AIError: LocalizedError {
    case invalidResponse
    case parseError
    case apiError(String)
    case noAPIKey
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid response from API"
        case .parseError: return "Failed to parse API response"
        case .apiError(let msg): return msg
        case .noAPIKey: return "No API key configured"
        case .invalidURL: return "Invalid API URL"
        }
    }
}
