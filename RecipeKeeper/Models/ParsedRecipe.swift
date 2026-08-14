import Foundation

struct ParsedIngredient: Codable, Equatable {
  let name: String
  let amount: String
}

struct ParsedRecipe: Codable, Equatable {
  let title: String
  let ingredients: [ParsedIngredient]
  let steps: [String]
  let categories: [String]?

  var resolvedCategories: [String] {
    categories ?? []
  }
}

struct DeepSeekChatRequest: Encodable {
  let model: String
  let messages: [Message]
  let responseFormat: ResponseFormat
  let thinking: ThinkingMode

  enum CodingKeys: String, CodingKey {
    case model
    case messages
    case responseFormat = "response_format"
    case thinking
  }

  init(
    model: String = DeepSeekAPI.flashModel,
    messages: [Message],
    responseFormat: ResponseFormat = .init(type: "json_object"),
    thinking: ThinkingMode = .disabled
  ) {
    self.model = model
    self.messages = messages
    self.responseFormat = responseFormat
    self.thinking = thinking
  }

  struct Message: Encodable {
    let role: String
    let content: String
  }

  struct ResponseFormat: Encodable {
    let type: String
  }

  struct ThinkingMode: Encodable {
    let type: String
    static let disabled = ThinkingMode(type: "disabled")
    static let enabled = ThinkingMode(type: "enabled")
  }
}

struct DeepSeekChatResponse: Decodable {
  struct Choice: Decodable {
    struct Message: Decodable {
      let content: String?
      let reasoningContent: String?

      enum CodingKeys: String, CodingKey {
        case content
        case reasoningContent = "reasoning_content"
      }
    }

    let message: Message
  }

  let choices: [Choice]

  var firstContent: String? {
    guard let raw = choices.first?.message.content?
      .trimmingCharacters(in: .whitespacesAndNewlines),
      !raw.isEmpty else {
      return nil
    }
    return raw
  }
}

enum DeepSeekAPI {
  /// 官方当前推荐：V4 Flash（快、便宜，适合 JSON 结构化任务）
  static let flashModel = "deepseek-v4-flash"
  /// 更强推理，一般不必用于本 App 的 JSON 任务
  static let proModel = "deepseek-v4-pro"
}

/// DeepSeek 请求走独立 URLSession。大图走 HTTPS 时，系统共享会话容易把 HTTP/2 连接弄坏，后续就会报 TLS。
enum DeepSeekHTTP {
  static let endpoint = URL(string: "https://api.deepseek.com/chat/completions")!

  private static let lock = NSLock()
  private static var session = makeSession()

  private static func makeSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.waitsForConnectivity = true
    config.timeoutIntervalForRequest = 90
    config.timeoutIntervalForResource = 120
    config.tlsMinimumSupportedProtocolVersion = .TLSv12
    config.httpMaximumConnectionsPerHost = 1
    config.requestCachePolicy = .reloadIgnoringLocalCacheData
    return URLSession(configuration: config)
  }

  private static func resetSession() {
    lock.lock()
    session.invalidateAndCancel()
    session = makeSession()
    lock.unlock()
  }

  private static func currentSession() -> URLSession {
    lock.lock()
    defer { lock.unlock() }
    return session
  }

  static func post(apiKey: String, body: Data, timeout: TimeInterval = 90, retries: Int = 2) async throws -> Data {
    var request = URLRequest(url: endpoint)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.setValue("close", forHTTPHeaderField: "Connection")
    request.httpBody = body
    request.timeoutInterval = timeout

    var lastError: Error?
    let attempts = max(retries, 0) + 1
    for attempt in 0..<attempts {
      do {
        let (data, response) = try await currentSession().data(for: request)
        guard let http = response as? HTTPURLResponse else {
          throw RecipeKeeperError.apiError("无响应")
        }
        if !(200..<300).contains(http.statusCode) {
          throw RecipeKeeperError.apiError(httpErrorMessage(data: data, status: http.statusCode))
        }
        return data
      } catch let error as RecipeKeeperError {
        throw error
      } catch {
        lastError = error
        if isTransient(error) {
          resetSession()
          if attempt < attempts - 1 {
            try await Task.sleep(nanoseconds: UInt64(350_000_000 * (attempt + 1)))
            continue
          }
        }
        throw RecipeKeeperError.apiError(networkErrorMessage(error))
      }
    }
    throw RecipeKeeperError.apiError(networkErrorMessage(lastError))
  }

  static func isTransient(_ error: Error) -> Bool {
    if let urlError = error as? URLError {
      switch urlError.code {
      case .secureConnectionFailed, .serverCertificateUntrusted, .serverCertificateHasBadDate,
           .serverCertificateHasUnknownRoot, .serverCertificateNotYetValid,
           .clientCertificateRejected, .clientCertificateRequired,
           .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed,
           .timedOut, .networkConnectionLost, .notConnectedToInternet,
           .dataNotAllowed, .internationalRoamingOff:
        return true
      default:
        break
      }
    }
    let text = String(describing: error).lowercased()
    return text.contains("tls") || text.contains("ssl") || text.contains("secure connection")
  }

  static func networkErrorMessage(_ error: Error?) -> String {
    guard let error else { return "网络请求失败，请稍后重试" }
    if isTransient(error) {
      let text = (error.localizedDescription + String(describing: error)).lowercased()
      if text.contains("tls") || text.contains("ssl") || text.contains("secure") || text.contains("certificate") {
        return "连不上 DeepSeek（TLS 安全连接失败）。请换个网络或关掉 VPN 后再试"
      }
      if let urlError = error as? URLError {
        switch urlError.code {
        case .timedOut:
          return "请求超时，请检查网络后重试"
        case .notConnectedToInternet, .dataNotAllowed:
          return "当前没有网络，请连上 Wi‑Fi 或蜂窝后再试"
        default:
          break
        }
      }
      return "网络不稳定，请稍后重试"
    }
    return error.localizedDescription
  }

  static func httpErrorMessage(data: Data, status: Int) -> String {
    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
      if let error = json["error"] as? [String: Any] {
        let message = (error["message"] as? String) ?? (error["code"] as? String) ?? ""
        if !message.isEmpty {
          if message.localizedCaseInsensitiveContains("model") {
            return "模型不可用，请检查 DeepSeek API Key 是否有效"
          }
          if message.localizedCaseInsensitiveContains("auth")
              || message.localizedCaseInsensitiveContains("key")
              || status == 401 {
            return "API Key 无效或未授权，请到设置里重新填写"
          }
          if message.localizedCaseInsensitiveContains("balance")
              || message.localizedCaseInsensitiveContains("quota") {
            return "DeepSeek 额度不足，请充值后再试"
          }
          return message
        }
      }
      if let message = json["message"] as? String, !message.isEmpty {
        return message
      }
    }
    let raw = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if !raw.isEmpty, raw.count < 180 {
      return "HTTP \(status)：\(raw)"
    }
    return "HTTP \(status)"
  }
}

enum RecipeKeeperError: LocalizedError {
  case missingAPIKey
  case invalidVideo
  case invalidImage
  case noTextFound
  case apiError(String)
  case parseError

  var errorDescription: String? {
    switch self {
    case .missingAPIKey:
      return "请先在设置中填写 DeepSeek API Key"
    case .invalidVideo:
      return "无法读取该视频"
    case .invalidImage:
      return "无法读取所选图片"
    case .noTextFound:
      return "没有识别到画面文字"
    case .apiError(let message):
      return "API 请求失败：\(message)"
    case .parseError:
      return "无法解析食谱"
    }
  }
}
