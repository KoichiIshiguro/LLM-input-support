import Foundation

final class GeminiClient {
    private var currentTask: URLSessionDataTask?

    func streamGenerate(
        prompt: String,
        context: String?,
        model: String,
        systemPrompt: String,
        apiKey: String,
        onToken: @escaping (String) -> Void,
        onComplete: @escaping () -> Void,
        onError: @escaping (String) -> Void
    ) {
        cancel()

        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(model):streamGenerateContent?alt=sse&key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            onError("不正な URL")
            return
        }

        var userContent = prompt
        if let ctx = context, !ctx.isEmpty {
            userContent = "Context:\n\(ctx)\n\nInstruction:\n\(prompt)"
        }

        let body: [String: Any] = [
            "system_instruction": [
                "parts": [["text": systemPrompt]]
            ],
            "contents": [
                ["role": "user", "parts": [["text": userContent]]]
            ],
            "generationConfig": [
                "temperature": 1.0
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 60

        let delegate = SSEDelegate(onToken: onToken, onComplete: onComplete, onError: onError)
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: .main)
        currentTask = session.dataTask(with: request)
        currentTask?.resume()
    }

    func cancel() {
        currentTask?.cancel()
        currentTask = nil
    }
}

private final class SSEDelegate: NSObject, URLSessionDataDelegate {
    let onToken: (String) -> Void
    let onComplete: () -> Void
    let onError: (String) -> Void
    private var buffer = ""

    init(onToken: @escaping (String) -> Void, onComplete: @escaping () -> Void, onError: @escaping (String) -> Void) {
        self.onToken = onToken
        self.onComplete = onComplete
        self.onError = onError
    }

    private var httpStatusCode: Int = 0

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        if let http = response as? HTTPURLResponse {
            httpStatusCode = http.statusCode
            NSLog("[LLMime] HTTP %d, type=%@", http.statusCode, http.mimeType ?? "nil")
        }
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let chunk = String(data: data, encoding: .utf8) else { return }
        NSLog("[LLMime] SSE chunk (%d bytes): %@", data.count, String(chunk.prefix(300)))

        if httpStatusCode != 200 {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = json["error"] as? [String: Any],
               let message = error["message"] as? String {
                onError("API エラー (\(httpStatusCode)): \(message)")
            } else {
                onError("API エラー (\(httpStatusCode)): \(chunk.prefix(200))")
            }
            return
        }

        buffer += chunk

        while let range = buffer.range(of: "\n") {
            let line = String(buffer[buffer.startIndex..<range.lowerBound])
            buffer = String(buffer[range.upperBound...])

            if line.hasPrefix("data: ") {
                let jsonStr = String(line.dropFirst(6))
                parseSSEData(jsonStr)
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        NSLog("[LLMime] Session complete. error=%@, buffer=%d chars", error?.localizedDescription ?? "nil", buffer.count)
        if !buffer.isEmpty {
            for line in buffer.components(separatedBy: "\n") {
                if line.hasPrefix("data: ") {
                    parseSSEData(String(line.dropFirst(6)))
                }
            }
            buffer = ""
        }

        if let error = error {
            if (error as NSError).code != NSURLErrorCancelled {
                onError(error.localizedDescription)
            }
        } else {
            onComplete()
        }
    }

    private func parseSSEData(_ jsonStr: String) {
        guard let data = jsonStr.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        if let error = json["error"] as? [String: Any], let message = error["message"] as? String {
            onError(message)
            return
        }

        guard let candidates = json["candidates"] as? [[String: Any]] else { return }
        for candidate in candidates {
            guard let content = candidate["content"] as? [String: Any],
                  let parts = content["parts"] as? [[String: Any]] else { continue }
            for part in parts {
                if let text = part["text"] as? String {
                    onToken(text)
                }
            }
        }
    }
}
