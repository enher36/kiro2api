package auth

import (
	"fmt"
	"kiro2api/logger"
	"kiro2api/types"
)

// AuthService 认证服务（推荐使用依赖注入方式）
type AuthService struct {
	tokenManager *TokenManager
	configs      []AuthConfig
}

// NewAuthService 创建新的认证服务（推荐使用此方法而不是全局函数）
func NewAuthService() (*AuthService, error) {
	logger.Info("创建AuthService实例")

	// 加载配置
	configs, err := loadConfigs()
	if err != nil {
		return nil, fmt.Errorf("加载配置失败: %w", err)
	}

	// 允许空配置启动
	if len(configs) == 0 {
		logger.Info("AuthService以空Token池启动，可通过API添加账号")
		return &AuthService{
			tokenManager: NewTokenManager(configs),
			configs:      configs,
		}, nil
	}

	// 创建token管理器
	tokenManager := NewTokenManager(configs)

	// 预热第一个可用token
	_, warmupErr := tokenManager.getBestToken()
	if warmupErr != nil {
		logger.Warn("token预热失败", logger.Err(warmupErr))
	}

	logger.Info("AuthService创建完成", logger.Int("config_count", len(configs)))

	return &AuthService{
		tokenManager: tokenManager,
		configs:      configs,
	}, nil
}

// GetToken 获取可用的token
func (as *AuthService) GetToken() (types.TokenInfo, error) {
	if as.tokenManager == nil {
		return types.TokenInfo{}, fmt.Errorf("token管理器未初始化")
	}
	return as.tokenManager.getBestToken()
}

// GetTokenWithUsage 获取可用的token（包含使用信息）
func (as *AuthService) GetTokenWithUsage() (*types.TokenWithUsage, error) {
	if as.tokenManager == nil {
		return nil, fmt.Errorf("token管理器未初始化")
	}
	return as.tokenManager.GetBestTokenWithUsage()
}

// GetTokenManager 获取底层的TokenManager（用于高级操作）
func (as *AuthService) GetTokenManager() *TokenManager {
	return as.tokenManager
}

// GetConfigs 获取认证配置
func (as *AuthService) GetConfigs() []AuthConfig {
	return as.configs
}

// AddConfig 动态添加认证配置
func (as *AuthService) AddConfig(config AuthConfig) error {
	// 验证配置
	if config.RefreshToken == "" {
		return fmt.Errorf("refreshToken不能为空")
	}

	// 设置默认认证类型
	if config.AuthType == "" {
		config.AuthType = AuthMethodSocial
	}

	// 验证IdC认证的必要字段
	if config.AuthType == AuthMethodIdC {
		if config.ClientID == "" || config.ClientSecret == "" {
			return fmt.Errorf("IdC认证需要clientId和clientSecret")
		}
	}

	// 添加到配置列表
	as.configs = append(as.configs, config)

	// 更新TokenManager
	as.tokenManager.AddConfig(config)

	logger.Info("动态添加认证配置",
		logger.String("auth_type", config.AuthType),
		logger.Int("total_configs", len(as.configs)))

	return nil
}

// RemoveConfig 动态移除认证配置（通过索引）
func (as *AuthService) RemoveConfig(index int) error {
	if index < 0 || index >= len(as.configs) {
		return fmt.Errorf("无效的配置索引: %d", index)
	}

	// 从配置列表中移除
	as.configs = append(as.configs[:index], as.configs[index+1:]...)

	// 重建TokenManager
	as.tokenManager = NewTokenManager(as.configs)

	logger.Info("移除认证配置",
		logger.Int("removed_index", index),
		logger.Int("remaining_configs", len(as.configs)))

	return nil
}

// GetConfigCount 获取配置数量
func (as *AuthService) GetConfigCount() int {
	return len(as.configs)
}

// HasAvailableToken 检查是否有可用的Token
func (as *AuthService) HasAvailableToken() bool {
	return len(as.configs) > 0
}
