package auth

import (
	"encoding/json"
	"fmt"
	"os"

	"kiro2api/logger"
)

// AuthConfig 简化的认证配置
type AuthConfig struct {
	AuthType     string `json:"auth"`
	RefreshToken string `json:"refreshToken"`
	ClientID     string `json:"clientId,omitempty"`
	ClientSecret string `json:"clientSecret,omitempty"`
	Disabled     bool   `json:"disabled,omitempty"`
}

// 认证方法常量
const (
	AuthMethodSocial = "Social"
	AuthMethodIdC    = "IdC"

	// defaultConfigFile 默认配置文件路径，用于持久化 Web 添加的 Token
	defaultConfigFile = "auth_config.json"
)

// loadConfigs 从环境变量加载配置（保持向后兼容）
func loadConfigs() ([]AuthConfig, error) {
	configs, _, err := loadConfigsWithPath()
	return configs, err
}

// loadConfigsWithPath 加载配置并返回用于持久化的文件路径
func loadConfigsWithPath() ([]AuthConfig, string, error) {
	// 检测并警告弃用的环境变量
	deprecatedVars := []string{
		"REFRESH_TOKEN",
		"AWS_REFRESHTOKEN",
		"IDC_REFRESH_TOKEN",
		"BULK_REFRESH_TOKENS",
	}

	for _, envVar := range deprecatedVars {
		if os.Getenv(envVar) != "" {
			logger.Warn("检测到已弃用的环境变量",
				logger.String("变量名", envVar),
				logger.String("迁移说明", "请迁移到KIRO_AUTH_TOKEN的JSON格式"))
			logger.Warn("迁移示例",
				logger.String("新格式", `KIRO_AUTH_TOKEN='[{"auth":"Social","refreshToken":"your_token"}]'`))
		}
	}

	configFilePath := defaultConfigFile
	jsonData := os.Getenv("KIRO_AUTH_TOKEN")

	// 优先级 1: 环境变量指向的文件
	if jsonData != "" {
		if fileInfo, err := os.Stat(jsonData); err == nil && !fileInfo.IsDir() {
			configs, err := loadConfigsFromFile(jsonData)
			if err != nil {
				return nil, jsonData, err
			}
			return configs, jsonData, nil
		}
	}

	// 优先级 2: 默认配置文件
	if fileInfo, err := os.Stat(configFilePath); err == nil && !fileInfo.IsDir() {
		configs, err := loadConfigsFromFile(configFilePath)
		if err != nil {
			return nil, configFilePath, err
		}
		return configs, configFilePath, nil
	}

	// 优先级 3: 环境变量 JSON 字符串
	if jsonData == "" {
		logger.Info("未配置KIRO_AUTH_TOKEN，服务将以空Token池启动")
		logger.Info("可通过Web界面添加账号，配置将自动保存到文件",
			logger.String("config_file", configFilePath))
		return []AuthConfig{}, configFilePath, nil
	}

	// 作为JSON字符串处理
	logger.Debug("从环境变量加载JSON配置")
	configs, err := parseJSONConfig(jsonData)
	if err != nil {
		return nil, configFilePath, fmt.Errorf("解析KIRO_AUTH_TOKEN失败: %w\n"+
			"请检查JSON格式是否正确\n"+
			"示例: KIRO_AUTH_TOKEN='[{\"auth\":\"Social\",\"refreshToken\":\"token1\"}]'", err)
	}

	if len(configs) == 0 {
		logger.Info("KIRO_AUTH_TOKEN配置为空数组，服务将以空Token池启动")
		return []AuthConfig{}, configFilePath, nil
	}

	validConfigs := processConfigs(configs)
	if len(validConfigs) == 0 {
		logger.Warn("没有有效的认证配置，服务将以空Token池启动")
		return []AuthConfig{}, configFilePath, nil
	}

	logger.Info("成功加载认证配置",
		logger.Int("总配置数", len(configs)),
		logger.Int("有效配置数", len(validConfigs)))

	return validConfigs, configFilePath, nil
}

// GetConfigs 公开的配置获取函数，供其他包调用
func GetConfigs() ([]AuthConfig, error) {
	return loadConfigs()
}

// parseJSONConfig 解析JSON配置字符串
func parseJSONConfig(jsonData string) ([]AuthConfig, error) {
	var configs []AuthConfig

	// 尝试解析为数组
	if err := json.Unmarshal([]byte(jsonData), &configs); err != nil {
		// 尝试解析为单个对象
		var single AuthConfig
		if err := json.Unmarshal([]byte(jsonData), &single); err != nil {
			return nil, fmt.Errorf("JSON格式无效: %w", err)
		}
		configs = []AuthConfig{single}
	}

	return configs, nil
}

// processConfigs 处理和验证配置
func processConfigs(configs []AuthConfig) []AuthConfig {
	var validConfigs []AuthConfig

	for i, config := range configs {
		// 验证必要字段
		if config.RefreshToken == "" {
			continue
		}

		// 设置默认认证类型
		if config.AuthType == "" {
			config.AuthType = AuthMethodSocial
		}

		// 验证IdC认证的必要字段
		if config.AuthType == AuthMethodIdC {
			if config.ClientID == "" || config.ClientSecret == "" {
				continue
			}
		}

		// 跳过禁用的配置
		if config.Disabled {
			continue
		}

		validConfigs = append(validConfigs, config)
		_ = i // 避免未使用变量警告
	}

	return validConfigs
}

// loadConfigsFromFile 从指定路径加载并验证配置
func loadConfigsFromFile(path string) ([]AuthConfig, error) {
	content, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("读取配置文件失败: %w\n配置文件路径: %s", err, path)
	}

	configs, err := parseJSONConfig(string(content))
	if err != nil {
		return nil, fmt.Errorf("解析配置文件失败: %w\n配置文件路径: %s", err, path)
	}

	if len(configs) == 0 {
		logger.Info("配置文件为空，服务将以空Token池启动",
			logger.String("file_path", path))
		return []AuthConfig{}, nil
	}

	validConfigs := processConfigs(configs)
	if len(validConfigs) == 0 {
		logger.Warn("配置文件中没有有效的认证配置，将以空Token池启动",
			logger.String("file_path", path))
		return []AuthConfig{}, nil
	}

	logger.Info("从文件加载认证配置",
		logger.String("file_path", path),
		logger.Int("total_count", len(configs)),
		logger.Int("valid_count", len(validConfigs)))

	return validConfigs, nil
}

// SaveConfigsToFile 将配置持久化到文件（导出供 AuthService 使用）
func SaveConfigsToFile(path string, configs []AuthConfig) error {
	data, err := json.MarshalIndent(configs, "", "  ")
	if err != nil {
		return fmt.Errorf("序列化认证配置失败: %w", err)
	}

	if err := os.WriteFile(path, data, 0o600); err != nil {
		return fmt.Errorf("写入配置文件失败: %w\n配置文件路径: %s", err, path)
	}

	logger.Info("认证配置已持久化到文件",
		logger.String("file_path", path),
		logger.Int("config_count", len(configs)))

	return nil
}
