import Foundation

struct JevAPIClient {
    private static let baseURL = URL(string: "https://api.typesafe.ai/v1/")!

    func validate(apiKey: String) async throws -> [String] {
        var request = URLRequest(url: Self.baseURL.appending(path: "models"))
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw JevAPIError.message("JEV returned an invalid response.")
        }
        guard (200..<300).contains(response.statusCode) else {
            throw JevAPIError.httpStatus(response.statusCode)
        }
        let availableModels = try JSONDecoder().decode(JevModelsResponse.self, from: data).models.map(\.name)
        guard !availableModels.isEmpty else {
            throw JevAPIError.message("This TypeSafe account has no available Jev models.")
        }
        return availableModels
    }

    func sort(apps: [LaunchableApp], categories: [String], model: String, apiKey: String) async throws -> [String: String] {
        guard !apps.isEmpty else { return [:] }
        guard categories.count >= 2, categories.count <= 24 else {
            throw JevAPIError.message("JEV requires between 2 and 24 app categories.")
        }

        let state = CatalogState(
            applications: apps.enumerated().map {
                CatalogApplication(index: $0.offset, id: $0.element.id, name: $0.element.name,
                                   bundleIdentifier: $0.element.bundleIdentifier)
            },
            applicationGroups: categories
        )
        let criteria = Dictionary(uniqueKeysWithValues: categories.map { ($0, Self.description(for: $0)) })
        var questions: [String: JevQuestion] = [:]
        var questionToApp: [String: String] = [:]

        for (appIndex, app) in apps.enumerated() {
            let questionID = "app_\(appIndex)"
            questions[questionID] = JevQuestion(
                type: "choice",
                instructions: "Choose the single most appropriate application group for the application named \(app.name) (catalog index: \(appIndex)). Use its primary purpose and bundle identifier. Select exactly one provided group.",
                criteria: criteria
            )
            questionToApp[questionID] = app.id
        }

        let body = JevDecisionRequest(model: model, state: state, questions: questions)
        let answers = try await decide(body, apiKey: apiKey)
        var assignments: [String: String] = [:]
        for (questionID, appID) in questionToApp {
            guard let category = answers[questionID]?.choice, categories.contains(category) else {
                throw JevAPIError.message("JEV did not return a valid app group for one or more applications.")
            }
            assignments[appID] = category
        }
        return assignments
    }

    private func decide(_ body: JevDecisionRequest, apiKey: String) async throws -> [String: JevAnswer] {
        var request = URLRequest(url: Self.baseURL.appending(path: "systemone"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("ctrl-esc-\(UUID().uuidString)", forHTTPHeaderField: "Idempotency-Key")
        request.timeoutInterval = 90
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw JevAPIError.message("JEV returned an invalid response.")
        }
        guard (200..<300).contains(response.statusCode) else {
            let apiError = try? JSONDecoder().decode(JevErrorEnvelope.self, from: data)
            throw JevAPIError.message(apiError?.error.detail ?? apiError?.error.message ?? "JEV request failed (HTTP \(response.statusCode)).")
        }
        return try JSONDecoder().decode(JevDecisionResponse.self, from: data).answers
    }

    private static func description(for category: String) -> String {
        switch category {
        case "Accessories": "Utilities, maintenance tools, file viewers, calculators, and small helper applications."
        case "Development": "Software development tools such as IDEs, code editors, terminals, version control, and developer utilities."
        case "Education": "Learning, teaching, reference, study, and educational content applications."
        case "Games": "Video games, game launchers, and gaming companion applications."
        case "Graphics": "Image editing, drawing, design, photography, video, audio production, and creative media tools."
        case "Internet": "Web browsers, email, messaging, social networking, and internet communication applications."
        case "Office": "Documents, spreadsheets, presentations, calendars, task management, and workplace productivity applications."
        case "System": "Operating system settings, administration, security, device management, and system maintenance applications."
        default: "Applications whose primary purpose does not fit any of the other available groups."
        }
    }
}

private struct CatalogState: Encodable {
    let applications: [CatalogApplication]
    let applicationGroups: [String]
}

private struct CatalogApplication: Encodable {
    let index: Int
    let id: String
    let name: String
    let bundleIdentifier: String?
}

private struct JevDecisionRequest: Encodable {
    let model: String
    let state: CatalogState
    let questions: [String: JevQuestion]
}

private struct JevQuestion: Encodable {
    let type: String
    let instructions: String
    let criteria: [String: String]
}

private struct JevDecisionResponse: Decodable {
    let answers: [String: JevAnswer]
}

private struct JevModelsResponse: Decodable {
    let models: [JevModel]
}

private struct JevModel: Decodable {
    let name: String
}

private struct JevAnswer: Decodable {
    let choice: String?
}

private struct JevErrorEnvelope: Decodable {
    let error: JevError
}

private struct JevError: Decodable {
    let message: String?
    let detail: String?
}

private enum JevAPIError: LocalizedError {
    case httpStatus(Int)
    case message(String)

    var errorDescription: String? {
        switch self {
        case .httpStatus(401): "JEV rejected this API key. Check that it is active and complete."
        case .httpStatus(let status): "JEV API key check failed (HTTP \(status))."
        case .message(let message): message
        }
    }
}
