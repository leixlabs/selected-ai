//
//  LLMError.swift
//  selectedai
//

import Foundation

enum LLMError: Error, LocalizedError {
    case noActiveProvider
    case invalidURL(String)
    case authenticationFailed(String)
    case contextLimitExceeded
    case networkError(Error)
    case timeout
    case modelError(String)
    case protocolError(String)

    var errorDescription: String? {
        switch self {
        case .noActiveProvider:
            return "未配置 AI Provider，请先在设置中添加。"
        case .invalidURL(let url):
            return "无效的 API URL：\(url)"
        case .authenticationFailed(let detail):
            return "认证失败：\(detail)"
        case .contextLimitExceeded:
            return "输入内容过长，超出模型上下文限制。"
        case .networkError(let err):
            return "网络错误：\(err.localizedDescription)"
        case .timeout:
            return "请求超时，请检查网络或稍后重试。"
        case .modelError(let detail):
            return "模型错误：\(detail)"
        case .protocolError(let detail):
            return "协议错误：\(detail)"
        }
    }
}
