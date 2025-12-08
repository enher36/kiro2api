package server

import (
	"net/http"
	"strconv"

	"kiro2api/auth"
	"kiro2api/logger"

	"github.com/gin-gonic/gin"
)

// AddTokenRequest 添加Token的请求结构
type AddTokenRequest struct {
	AuthType     string `json:"auth"`
	RefreshToken string `json:"refreshToken"`
	ClientID     string `json:"clientId,omitempty"`
	ClientSecret string `json:"clientSecret,omitempty"`
}

// TokenAPIResponse 通用API响应结构
type TokenAPIResponse struct {
	Success bool   `json:"success"`
	Message string `json:"message,omitempty"`
	Error   string `json:"error,omitempty"`
	Count   int    `json:"count,omitempty"`
}

// registerTokenManagementRoutes 注册Token管理相关的路由
func registerTokenManagementRoutes(r *gin.Engine, authService *auth.AuthService) {
	// 添加Token
	r.POST("/api/tokens", func(c *gin.Context) {
		handleAddToken(c, authService)
	})

	// 删除Token
	r.DELETE("/api/tokens/:index", func(c *gin.Context) {
		handleDeleteToken(c, authService)
	})
}

// handleAddToken 处理添加Token的请求
func handleAddToken(c *gin.Context, authService *auth.AuthService) {
	var req AddTokenRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		logger.Warn("解析添加Token请求失败", logger.Err(err))
		c.JSON(http.StatusBadRequest, TokenAPIResponse{
			Success: false,
			Error:   "无效的请求格式: " + err.Error(),
		})
		return
	}

	// 验证必填字段
	if req.RefreshToken == "" {
		c.JSON(http.StatusBadRequest, TokenAPIResponse{
			Success: false,
			Error:   "refreshToken不能为空",
		})
		return
	}

	// 创建AuthConfig
	config := auth.AuthConfig{
		AuthType:     req.AuthType,
		RefreshToken: req.RefreshToken,
		ClientID:     req.ClientID,
		ClientSecret: req.ClientSecret,
	}

	// 添加配置
	if err := authService.AddConfig(config); err != nil {
		logger.Error("添加Token配置失败", logger.Err(err))
		c.JSON(http.StatusInternalServerError, TokenAPIResponse{
			Success: false,
			Error:   "添加Token失败: " + err.Error(),
		})
		return
	}

	logger.Info("通过API添加Token成功",
		logger.String("auth_type", config.AuthType),
		logger.Int("total_count", authService.GetConfigCount()))

	c.JSON(http.StatusOK, TokenAPIResponse{
		Success: true,
		Message: "Token添加成功",
		Count:   authService.GetConfigCount(),
	})
}

// handleDeleteToken 处理删除Token的请求
func handleDeleteToken(c *gin.Context, authService *auth.AuthService) {
	indexStr := c.Param("index")
	index, err := strconv.Atoi(indexStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, TokenAPIResponse{
			Success: false,
			Error:   "无效的索引参数",
		})
		return
	}

	// 删除配置
	if err := authService.RemoveConfig(index); err != nil {
		logger.Error("删除Token配置失败",
			logger.Int("index", index),
			logger.Err(err))
		c.JSON(http.StatusBadRequest, TokenAPIResponse{
			Success: false,
			Error:   "删除Token失败: " + err.Error(),
		})
		return
	}

	logger.Info("通过API删除Token成功",
		logger.Int("deleted_index", index),
		logger.Int("remaining_count", authService.GetConfigCount()))

	c.JSON(http.StatusOK, TokenAPIResponse{
		Success: true,
		Message: "Token删除成功",
		Count:   authService.GetConfigCount(),
	})
}
