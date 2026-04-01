package main

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"runtime"
	"sync/atomic"
	"syscall"
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

	// 应用就绪状态
	appReady atomic.Bool
)

func init() {
	// 注册 Prometheus 指标
	prometheus.MustRegister(httpRequestsTotal)
	prometheus.MustRegister(httpRequestDuration)
	prometheus.MustRegister(ordersProcessed)
	prometheus.MustRegister(activeConnections)

	// 启动时默认就绪
	appReady.Store(true)
}

func main() {
	// 设置 Gin 模式
	gin.SetMode(gin.ReleaseMode)

	// 创建 Gin 路由
	r := gin.New()

	// 添加中间件：指标收集
	r.Use(metricsMiddleware())

	// 健康检查端点 (liveness probe)
	r.GET("/health", healthHandler)

	// 就绪检查端点 (readiness probe)
	r.GET("/ready", readyHandler)

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

	// 创建 HTTP 服务器
	server := &http.Server{
		Addr:         ":" + port,
		Handler:      r,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 10 * time.Second,
	}

	// 启动服务器到后台
	go func() {
		fmt.Printf("🚀 Example App 启动中，监听端口: %s\n", port)
		fmt.Printf("📊 指标端点: http://localhost:%s/metrics\n", port)
		fmt.Printf("❤️  健康检查: http://localhost:%s/health\n", port)
		fmt.Printf("✅  就绪检查: http://localhost:%s/ready\n", port)
		fmt.Printf("👋  问候接口: http://localhost:%s/hello\n", port)

		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			fmt.Printf("❌ 服务器启动失败: %v\n", err)
			os.Exit(1)
		}
	}()

	// 等待中断信号进行优雅关闭
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	fmt.Println("\n🛑 收到关闭信号，开始优雅关闭...")

	// 标记应用为不就绪，停止接收新流量
	appReady.Store(false)

	// 创建带超时的上下文
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	// 优雅关闭服务器
	if err := server.Shutdown(ctx); err != nil {
		fmt.Printf("❌ 服务器关闭失败: %v\n", err)
		os.Exit(1)
	}

	fmt.Println("✅ 服务器已优雅关闭")
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

// healthHandler 健康检查 (liveness probe)
// 检查应用本身是否存活，不检查外部依赖
func healthHandler(c *gin.Context) {
	// 检查基本健康指标
	var m runtime.MemStats
	runtime.ReadMemStats(&m)

	// 获取当前 goroutine 数量
	numGoroutine := runtime.NumGoroutine()

	// 简单的健康检查：goroutine 数量异常（超过 10000）视为不健康
	// 这种情况通常表示存在 goroutine 泄漏
	healthy := numGoroutine < 10000

	if !healthy {
		c.JSON(http.StatusServiceUnavailable, gin.H{
			"status":    "unhealthy",
			"timestamp": time.Now().Format(time.RFC3339),
			"reason":    "too many goroutines",
			"goroutines": numGoroutine,
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"status":     "healthy",
		"timestamp":  time.Now().Format(time.RFC3339),
		"version":    "1.0.0",
		"service":    "example-app",
		"goroutines": numGoroutine,
		"memory": gin.H{
			"alloc":      m.Alloc / 1024 / 1024, // MB
			"total_alloc": m.TotalAlloc / 1024 / 1024,
			"sys":        m.Sys / 1024 / 1024,
		},
	})
}

// readyHandler 就绪检查 (readiness probe)
// 检查应用是否准备好接收流量，包括依赖服务
func readyHandler(c *gin.Context) {
	// 检查应用是否已标记为就绪
	if !appReady.Load() {
		c.JSON(http.StatusServiceUnavailable, gin.H{
			"status":    "not ready",
			"timestamp": time.Now().Format(time.RFC3339),
			"reason":    "app is shutting down",
		})
		return
	}

	// 检查基本健康指标
	var m runtime.MemStats
	runtime.ReadMemStats(&m)

	// 检查内存使用是否过高（超过 500MB）
	if m.Alloc > 500*1024*1024 {
		c.JSON(http.StatusServiceUnavailable, gin.H{
			"status":    "not ready",
			"timestamp": time.Now().Format(time.RFC3339),
			"reason":    "memory usage too high",
			"memory": gin.H{
				"alloc": m.Alloc / 1024 / 1024,
			},
		})
		return
	}

	// 在实际应用中，这里应该检查依赖服务（如数据库、缓存等）
	// 例如：检查数据库连接是否正常
	// if !checkDatabaseConnection() {
	//     c.JSON(http.StatusServiceUnavailable, ...)
	//     return
	// }

	// 模拟依赖检查（实际生产中应替换为真实检查）
	dependenciesReady := true

	if !dependenciesReady {
		c.JSON(http.StatusServiceUnavailable, gin.H{
			"status":    "not ready",
			"timestamp": time.Now().Format(time.RFC3339),
			"reason":    "dependencies not ready",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"status":       "ready",
		"timestamp":    time.Now().Format(time.RFC3339),
		"version":      "1.0.0",
		"service":      "example-app",
		"dependencies": "ok",
	})
}

// helloHandler 简单问候
func helloHandler(c *gin.Context) {
	activeConnections.Inc()
	defer activeConnections.Dec()

	c.JSON(http.StatusOK, gin.H{
		"message":    "Hello, CloudNative Pipeline!",
		"timestamp": time.Now().Format(time.RFC3339),
		"connection": activeConnections.Value(),
	})
}

// helloNameHandler 带名字的问候
func helloNameHandler(c *gin.Context) {
	name := c.Param("name")
	activeConnections.Inc()
	defer activeConnections.Dec()

	c.JSON(http.StatusOK, gin.H{
		"message":    fmt.Sprintf("Hello, %s!", name),
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
