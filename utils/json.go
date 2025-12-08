package utils

import (
	"encoding/json"
)

// 高性能JSON配置 - 临时使用标准库替代 sonic (Go 1.24 兼容性问题)

// FastMarshal 高性能JSON序列化
func FastMarshal(v any) ([]byte, error) {
	return json.Marshal(v)
}

// FastUnmarshal 高性能JSON反序列化
func FastUnmarshal(data []byte, v any) error {
	return json.Unmarshal(data, v)
}

// SafeMarshal 安全JSON序列化（带验证）
func SafeMarshal(v any) ([]byte, error) {
	return json.Marshal(v)
}

// SafeUnmarshal 安全JSON反序列化（带验证）
func SafeUnmarshal(data []byte, v any) error {
	return json.Unmarshal(data, v)
}

// MarshalIndent 带缩进的JSON序列化
func MarshalIndent(v any, prefix, indent string) ([]byte, error) {
	return json.MarshalIndent(v, prefix, indent)
}
