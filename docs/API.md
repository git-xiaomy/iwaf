# API文档

iWAF 提供 RESTful API 接口用于程序化管理和监控。

## 基础信息

- **Base URL**: `http://your-server:8080/api/` (Dashboard API)
- **Content-Type**: `application/json`
- **响应格式**: JSON

## 访问说明

API现在运行在独立的Dashboard端口(8080)上，需要先安装Dashboard：

```bash
cd dashboard
sudo ./setup-dashboard.sh
```

## 认证

目前版本的API不需要认证，但建议通过网络层（如防火墙、VPN）限制访问。

## 端点列表

### 1. 获取统计信息

```http
GET /api/stats
```

**响应示例：**
```json
{
    "version": "1.0.0",
    "enabled": true,
    "uptime": 1695366615.123,
    "requests_checked": 12450,
    "requests_blocked": 89
}
```

### 2. 获取配置

```http
GET /api/config
```

**响应示例：**
```json
{
    "status": "success",
    "config": {
        "enabled": true,
        "log_level": "info",
        "action": "block",
        "ip_whitelist": ["127.0.0.1"],
        "ip_blacklist": [],
        "rate_limit": {
            "enabled": true,
            "requests_per_minute": 120,
            "burst": 20
        }
    }
}
```

### 3. 更新配置

```http
POST /iwaf/api/config
Content-Type: application/json

{
    "enabled": true,
    "log_level": "info",
    "action": "block",
    "rate_limit": {
        "enabled": true,
        "requests_per_minute": 100
    }
}
```

**响应示例：**
```json
{
    "status": "success",
    "message": "Configuration updated successfully"
}
```

### 4. 获取日志

```http
GET /api/logs?level=warn&limit=100
```

**参数：**
- `level` (可选): 日志级别过滤 (debug, info, warn, error)
- `limit` (可选): 返回条目数量限制 (默认: 50, 最大: 1000)
- `since` (可选): 起始时间戳

**响应示例：**
```json
{
    "status": "success",
    "logs": [
        {
            "timestamp": 1695366615.123,
            "level": "warn",
            "message": "SQL injection attempt blocked",
            "client_ip": "192.168.1.100",
            "request_uri": "/test.php?id=1' OR '1'='1"
        }
    ],
    "total": 1
}
```

### 5. 重启WAF

```http
POST /api/restart
```

**响应示例：**
```json
{
    "status": "success",
    "message": "WAF restart initiated"
}
```

## 错误响应

当API请求失败时，返回以下格式：

```json
{
    "status": "error",
    "message": "Error description",
    "code": "ERROR_CODE"
}
```

**常见错误代码：**
- `INVALID_CONFIG`: 配置验证失败
- `PERMISSION_DENIED`: 权限不足
- `INTERNAL_ERROR`: 内部错误
- `INVALID_REQUEST`: 请求格式错误

## 使用示例

### cURL 示例

```bash
# 获取统计信息
curl -X GET http://your-server:8080/api/stats

# 更新配置
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{"enabled": true, "log_level": "debug"}' \
  http://your-server:8080/api/config

# 获取警告级别日志
curl -X GET "http://your-server:8080/api/logs?level=warn&limit=50"
```

### Python 示例

```python
import requests
import json

# API configuration for separate dashboard
base_url = "http://your-server:8080/api"

# 获取统计信息
response = requests.get(f"{base_url}/stats")
stats = response.json()
print(f"Total requests: {stats['requests_checked']}")

# 更新配置
config = {
    "enabled": True,
    "rate_limit": {
        "enabled": True,
        "requests_per_minute": 200
    }
}

response = requests.post(
    f"{base_url}/config",
    headers={"Content-Type": "application/json"},
    data=json.dumps(config)
)

if response.json()["status"] == "success":
    print("Configuration updated successfully")
```

### JavaScript 示例

```javascript
// 获取统计信息
async function getStats() {
    try {
        const response = await fetch('/api/stats');
        const stats = await response.json();
        console.log('WAF Stats:', stats);
    } catch (error) {
        console.error('Error fetching stats:', error);
    }
}

// 更新配置
async function updateConfig(config) {
    try {
        const response = await fetch('/api/config', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(config)
        });
        
        const result = await response.json();
        if (result.status === 'success') {
            console.log('Configuration updated');
        } else {
            console.error('Error:', result.message);
        }
    } catch (error) {
        console.error('Error updating config:', error);
    }
}
```

## 监控集成

### Prometheus 指标

可以通过API获取指标数据并转换为Prometheus格式：

```bash
# 获取指标脚本示例
#!/bin/bash
STATS=$(curl -s http://localhost/iwaf/api/stats)
REQUESTS_CHECKED=$(echo $STATS | jq -r '.requests_checked')
REQUESTS_BLOCKED=$(echo $STATS | jq -r '.requests_blocked')

echo "# HELP iwaf_requests_total Total number of requests checked"
echo "# TYPE iwaf_requests_total counter"
echo "iwaf_requests_total $REQUESTS_CHECKED"

echo "# HELP iwaf_requests_blocked_total Total number of requests blocked"
echo "# TYPE iwaf_requests_blocked_total counter"
echo "iwaf_requests_blocked_total $REQUESTS_BLOCKED"
```

### Grafana Dashboard

使用以下查询在Grafana中创建仪表板：

1. **请求总数**:
   - Metric: `iwaf_requests_total`
   - Visualization: Single Stat

2. **阻止请求数**:
   - Metric: `iwaf_requests_blocked_total`
   - Visualization: Single Stat

3. **阻止率**:
   - Expression: `iwaf_requests_blocked_total / iwaf_requests_total * 100`
   - Visualization: Gauge

## 限制和注意事项

1. **性能**: API调用会消耗一定的系统资源，建议合理控制调用频率
2. **安全**: 生产环境中应限制API访问权限
3. **缓存**: 统计数据可能有轻微延迟（通常<30秒）
4. **并发**: API支持适度的并发访问，但避免过于频繁的请求

## 后续版本计划

- [ ] 添加API认证机制
- [ ] 支持批量操作
- [ ] 增加更多统计维度
- [ ] 提供WebSocket实时数据推送
- [ ] 支持配置导入/导出