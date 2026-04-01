package main

import (
	"fmt"
	"math/rand"
	"net/http"
	"os"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
	// 请求计数器
	httpRequestsTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "http_requests_total",
			Help: "Total number of HTTP requests",
		},
		[]string{"method", "endpoint", "status"},
	)

	// 请求延迟直方图
	httpRequestDuration = prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "http_request_duration_seconds",
			Help:    "HTTP request duration in seconds",
			Buckets: prometheus.DefBuckets,
		},
		[]string{"method", "endpoint"},
	)

	// 自定义业务指标
	ordersProcessed = prometheus.NewCounter(
		prometheus.CounterOpts{
			Name: "orders_processed_total",
			Help: "Total number of orders processed",
		},
	)

	activeConnections = prometheus.NewGauge(
		prometheus.GaugeOpts{
			Name: "active_connections",
			Help: "Number of active connections",
		},
	)
)

func init() {
	// 注册 Prometheus 指标
	prometheus.MustRegister(httpRequestsTotal)
	prometheus.MustRegister(httpRequestDuration)
	prometheus.MustRegister(ordersProcessed)
	prometheus.MustRegister(activeConnections)
}

func main() {
	// 设置 Gin 模式
	gin.SetMode(gin.ReleaseMode)

	// 创建 Gin 路由
	r := gin.New()

	// 添加中间件：指标收集
	r.Use(metricsMiddleware())

	// 健康检查端点
	r.GET("/health", healthHandler)

	// Prometheus 指标端点
	r.GET("/metrics", gin.WrapH(promhttp.Handler()))

	// 示例接口
	r.GET("/hello", helloHandler)
	r.GET("/hello/:name", helloNameHandler)

	// 业务接口示例
	r.POST("/order", orderHandler)

	// 获取端口，默认 8081
	port := os.Getenv("PORT")
	if port == "" {
		port = "8081"
	}

	fmt.Printf("🚀 Example App 启动中，监听端口: %s\n", port)
	fmt.Printf("📊 指标端点: http://localhost:%s/metrics\n", port)
	fmt.Printf("❤️  健康检查: http://localhost:%s/health\n", port)
	fmt.Printf("👋 问候接口: http://localhost:%s/hello\n", port)

	// 启动服务器
	server := &http.Server{
		Addr:         ":" + port,
		Handler:      r,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 10 * time.Second,
	}

	if err := server.ListenAndServe(); err != nil {
		fmt.Printf("❌ 服务器启动失败: %v\n", err)
		os.Exit(1)
	}
}

// metricsMiddleware 收集 HTTP 请求指标
func metricsMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		path := c.FullPath()
		if path == "" {
			path = "unknown"
		}

		// 处理请求
		c.Next()

		// 记录指标
		duration := time.Since(start).Seconds()
		status := fmt.Sprintf("%d", c.Writer.Status())
		httpRequestsTotal.WithLabelValues(c.Request.Method, path, status).Inc()
		httpRequestDuration.WithLabelValues(c.Request.Method, path).Observe(duration)
	}
}

// healthHandler 健康检查
func healthHandler(c *gin.Context) {
	// 模拟偶尔的健康检查波动
	healthy := rand.Float32() > 0.05 // 95% 概率健康

	if healthy {
		c.JSON(http.StatusOK, gin.H{
			"status":    "healthy",
			"timestamp": time.Now().Format(time.RFC3339),
			"version":   "1.0.0",
			"service":   "example-app",
		})
	} else {
		c.JSON(http.StatusServiceUnavailable, gin.H{
			"status":    "unhealthy",
			"timestamp": time.Now().Format(time.RFC3339),
			"reason":    "service degradation",
		})
	}
}

// helloHandler 简单问候
func helloHandler(c *gin.Context) {
	activeConnections.Inc()
	defer activeConnections.Dec()

	c.JSON(http.StatusOK, gin.H{
		"message":   "Hello, CloudNative Pipeline!",
		"timestamp":  time.Now().Format(time.RFC3339),
		"connection": activeConnections.Value(),
	})
}

// helloNameHandler 带名字的问候
func helloNameHandler(c *gin.Context) {
	name := c.Param("name")
	activeConnections.Inc()
	defer activeConnections.Dec()

	c.JSON(http.StatusOK, gin.H{
		"message":   fmt.Sprintf("Hello, %s!", name),
		"timestamp": time.Now().Format(time.RFC3339),
		"connection": activeConnections.Value(),
	})
}

// orderHandler 订单处理示例
func orderHandler(c *gin.Context) {
	var order struct {
		OrderID   string  `json:"order_id"`
		ProductID string  `json:"product_id"`
		Quantity  int     `json:"quantity"`
		Price     float64 `json:"price"`
	}

	if err := c.ShouldBindJSON(&order); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error":   "invalid request",
			"details": err.Error(),
		})
		return
	}

	// 模拟订单处理
	ordersProcessed.Inc()

	c.JSON(http.StatusOK, gin.H{
		"status":      "processed",
		"order_id":    order.OrderID,
		"total_price": float64(order.Quantity) * order.Price,
		"timestamp":   time.Now().Format(time.RFC3339),
	})
}
