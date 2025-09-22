# iWAF - 智能Web应用防火墙

![iWAF Logo](web/images/favicon.ico) **v1.0.0**

iWAF 是一个基于 Nginx + Lua 开发的高性能Web应用防火墙，提供全面的安全防护功能和易于使用的Web管理界面。

## 🛡️ 主要功能

### 🔥 核心安全功能
- **SQL注入防护** - 检测和阻止各种SQL注入攻击尝试
- **XSS防护** - 防止跨站脚本攻击
- **路径遍历防护** - 阻止目录遍历攻击
- **速率限制** - 防止暴力破解和DDoS攻击
- **IP过滤** - 支持白名单和黑名单功能
- **User-Agent过滤** - 识别和阻止恶意爬虫和扫描工具
- **文件类型过滤** - 限制危险文件上传
- **请求大小限制** - 防止大文件攻击

### 🎨 Web管理界面 (可选)
- **独立部署** - Dashboard运行在单独端口(8080)，不占用主站点URL
- **前后端分离** - 完全独立的管理界面，用户手动创建
- **响应式设计** - 支持桌面和移动设备
- **实时监控** - 查看请求统计和威胁分析
- **配置管理** - 可视化配置各项安全规则
- **日志查看** - 实时查看WAF日志和事件
- **IP管理** - 便捷的IP白名单/黑名单管理
- **系统状态** - 监控WAF运行状态和性能

### 📊 统计和分析
- 实时请求统计
- 威胁类型分析
- 攻击趋势图表
- 详细的日志记录

## 🚀 快速开始

### 环境要求

- **Nginx** 1.16+ (需要Lua模块支持)
- **OpenResty** 或者 **Nginx + nginx-module-lua**
- **Lua** 5.1/5.2/5.3/LuaJIT
- **lua-cjson** (JSON解析库)

### 一键安装

```bash
# 克隆项目
git clone https://github.com/git-xiaomy/iwaf.git
cd iwaf

# 安装WAF核心功能
sudo ./setup.sh

# 可选：安装独立Dashboard (运行在端口8080)
cd dashboard
sudo ./setup-dashboard.sh
```

### 手动安装

#### 1. 安装依赖包

**Ubuntu/Debian:**
```bash
apt-get update
apt-get install -y nginx nginx-module-lua lua-cjson lua-resty-redis lua-resty-mysql
```

**CentOS/RHEL:**
```bash
yum install -y nginx nginx-module-lua lua-cjson
# 或使用 OpenResty
yum install -y openresty
```

#### 2. 创建目录和复制文件

```bash
# 创建iWAF目录
sudo mkdir -p /etc/nginx/iwaf/{lua/iwaf,web,logs}

# 复制文件
sudo cp -r lua/ /etc/nginx/iwaf/
sudo cp -r web/ /etc/nginx/iwaf/
sudo cp conf/config.json /etc/nginx/iwaf/
sudo cp conf/iwaf.conf /etc/nginx/conf.d/

# 设置权限
sudo chown -R www-data:www-data /etc/nginx/iwaf/
sudo chmod -R 755 /etc/nginx/iwaf/
sudo chmod 644 /etc/nginx/iwaf/config.json
```

#### 3. 配置Nginx

在 `/etc/nginx/nginx.conf` 的 `http` 块中添加：

```nginx
# 加载Lua模块
load_module modules/ngx_http_lua_module.so;

http {
    # 定义共享内存用于WAF缓存
    lua_shared_dict iwaf_cache 10m;
    
    # 设置Lua模块路径
    lua_package_path "/etc/nginx/iwaf/lua/?.lua;/etc/nginx/iwaf/lua/iwaf/?.lua;;";
    
    # 初始化iWAF
    init_by_lua_block {
        local iwaf = require "waf"
        iwaf.init()
    }
    
    # 引入iWAF配置
    include /etc/nginx/conf.d/iwaf.conf;
}
```

#### 4. 测试和重启

```bash
# 测试配置
sudo nginx -t

# 重启Nginx
sudo systemctl restart nginx
```

## 🔧 配置说明

### 基本配置

iWAF的配置文件位于 `/etc/nginx/iwaf/config.json`，包含以下主要配置项：

```json
{
    "enabled": true,                    // 启用WAF
    "log_level": "info",               // 日志级别
    "action": "block",                 // 防护动作: block/log/redirect
    "ip_whitelist": [],                // IP白名单
    "ip_blacklist": [],                // IP黑名单
    "rate_limit": {
        "enabled": true,
        "requests_per_minute": 120,
        "burst": 20
    },
    "sql_injection": {
        "enabled": true,
        "patterns": [...]              // SQL注入检测规则
    },
    "xss_protection": {
        "enabled": true,
        "patterns": [...]              // XSS检测规则
    }
    // ... 更多配置选项
}
```

### Nginx配置

在您的server块中添加WAF保护：

```nginx
server {
    listen 80;
    server_name example.com;
    
    # iWAF访问阶段检查
    access_by_lua_block {
        local iwaf = require "waf"
        iwaf.check_request()
    }
    
    # 启用请求体读取
    lua_need_request_body on;
    
    # 设置最大请求体大小
    client_max_body_size 10m;
    
    location / {
        root /var/www/html;
        index index.html;
    }
    
    # 自定义错误页面
    error_page 403 /blocked.html;
    location = /blocked.html {
        root /etc/nginx/iwaf/web;
        internal;
    }
}
```

## 🎯 使用说明

### 1. WAF核心功能

安装完成后，WAF自动保护您的网站。配置文件位于：`/etc/nginx/iwaf/config.json`

### 2. 可选Dashboard管理界面

Dashboard是完全独立的，运行在端口8080上：

```bash
# 安装Dashboard
cd dashboard
sudo ./setup-dashboard.sh

# 访问Dashboard
http://your-server-ip:8080
```

### 2. 主要功能模块 (Dashboard)

如果安装了Dashboard，可通过Web界面管理：

#### 仪表盘
- 查看实时统计数据
- 监控威胁趋势
- 系统状态概览

#### 安全配置
- 启用/禁用各种防护功能
- 调整安全规则参数
- 设置请求限制

#### IP过滤
- 管理IP白名单和黑名单
- 批量导入IP列表
- IP范围支持

#### 速率限制
- 配置每分钟最大请求数
- 设置突发请求阈值
- 自定义限制策略

#### 日志查看
- 实时查看WAF日志
- 按级别过滤日志
- 搜索特定事件

#### 系统设置
- 调整日志级别
- 配置防护动作
- 系统信息查看

### 3. API接口

iWAF提供RESTful API供程序化管理：

```bash
# 获取统计信息
curl http://your-server/iwaf/api/stats

# 获取配置
curl http://your-server/iwaf/api/config

# 更新配置
curl -X POST -H "Content-Type: application/json" \
     -d '{"enabled": true}' \
     http://your-server/iwaf/api/config
```

## ❓ 常见问题

查看 [FAQ 文档](docs/FAQ.md) 了解：
- 为什么需要安装 lua-redis 和 mysql 依赖？
- 默认仪表盘的8080端口是如何创建的？
- 其他安装和配置相关问题

## 📁 目录结构

```
iwaf/
├── lua/iwaf/           # Lua模块
│   ├── waf.lua        # 主WAF模块
│   └── validator.lua  # 配置验证模块
├── dashboard/         # 独立Dashboard (可选)
│   ├── web/          # Dashboard前端
│   ├── conf/         # Dashboard配置
│   ├── setup-dashboard.sh # Dashboard安装脚本
│   └── README.md     # Dashboard说明
├── conf/             # 配置文件
│   ├── iwaf.conf     # Nginx配置
│   └── config.json   # WAF配置
├── examples/         # 示例配置
├── docs/            # 文档
└── setup.sh         # WAF安装脚本
```

## 🔍 日志格式

iWAF使用JSON格式记录日志，便于分析和处理：

```json
{
    "timestamp": 1695366615.123,
    "level": "warn",
    "message": "SQL injection attempt blocked",
    "details": {
        "pattern": "union.*select",
        "action": "block"
    },
    "client_ip": "192.168.1.100",
    "request_uri": "/index.php?id=1' OR '1'='1",
    "user_agent": "Mozilla/5.0..."
}
```

## 🚨 安全注意事项

### 管理界面安全
- 限制管理界面访问IP
- 使用HTTPS访问
- 定期更新密码

### 配置文件安全
- 设置适当的文件权限
- 定期备份配置
- 监控配置变更

### 性能优化
- 调整共享内存大小
- 优化Lua代码性能
- 监控系统资源使用

## 🛠️ 高级配置

### 自定义规则

您可以添加自定义检测规则：

```json
{
    "custom_rules": {
        "enabled": true,
        "patterns": [
            "your_custom_pattern_here",
            "another_pattern"
        ]
    }
}
```

### 地理位置封锁

```json
{
    "geo_blocking": {
        "enabled": true,
        "blocked_countries": ["CN", "RU"],
        "allowed_countries": ["US", "EU"]
    }
}
```

### 蜜罐功能

```json
{
    "honeypot": {
        "enabled": true,
        "trap_urls": [
            "/admin/",
            "/.env",
            "/wp-admin/"
        ]
    }
}
```

## 📈 性能调优

### Nginx配置优化

```nginx
# 增加worker进程数
worker_processes auto;

# 增加连接数
worker_connections 2048;

# 优化共享内存
lua_shared_dict iwaf_cache 50m;

# 启用Lua代码缓存
lua_code_cache on;
```

### 系统优化

```bash
# 增加文件描述符限制
echo "* soft nofile 65535" >> /etc/security/limits.conf
echo "* hard nofile 65535" >> /etc/security/limits.conf

# 优化内核参数
echo "net.core.somaxconn = 65535" >> /etc/sysctl.conf
echo "net.ipv4.tcp_max_syn_backlog = 65535" >> /etc/sysctl.conf
```

## 🐛 故障排除

### 常见问题

**1. WAF不工作**
- 检查Nginx错误日志：`/var/log/nginx/error.log`
- 确认Lua模块已加载：`nginx -V 2>&1 | grep -o with-http_lua_module`
- 验证配置文件语法：`nginx -t`

**2. 误报问题**
- 检查WAF日志找到触发规则
- 调整规则或添加白名单
- 使用"仅记录"模式测试

**3. 性能问题**
- 增加共享内存大小
- 优化检测规则
- 监控系统资源使用

**4. 管理界面无法访问**
- 检查Nginx配置中的路径设置
- 确认文件权限正确
- 查看访问日志

### 调试模式

启用调试模式获取详细信息：

```json
{
    "log_level": "debug",
    "action": "log"
}
```

## 🤝 贡献指南

我们欢迎社区贡献！请遵循以下步骤：

1. Fork 项目
2. 创建特性分支：`git checkout -b feature/AmazingFeature`
3. 提交更改：`git commit -m 'Add some AmazingFeature'`
4. 推送分支：`git push origin feature/AmazingFeature`
5. 开启Pull Request

### 开发环境设置

```bash
# 克隆项目
git clone https://github.com/git-xiaomy/iwaf.git
cd iwaf

# 安装开发依赖
sudo apt-get install -y nginx-module-lua lua-cjson

# 启动测试环境
sudo nginx -p $(pwd) -c conf/nginx-dev.conf
```

## 📄 许可证

本项目基于 MIT 许可证开源。详情请参见 [LICENSE](LICENSE) 文件。

## 🙏 致谢

感谢以下开源项目的支持：
- [Nginx](http://nginx.org/) - 高性能Web服务器
- [OpenResty](https://openresty.org/) - 基于Nginx的应用服务器平台
- [lua-cjson](https://github.com/mpx/lua-cjson) - Lua JSON库
- [Font Awesome](https://fontawesome.com/) - 图标字体

## 📞 联系我们

- 项目主页：https://github.com/git-xiaomy/iwaf
- 问题反馈：https://github.com/git-xiaomy/iwaf/issues
- 讨论社区：https://github.com/git-xiaomy/iwaf/discussions

## 📝 更新日志

### v1.0.0 (2024-09-22)
- 🎉 首次发布
- ✅ 实现核心WAF功能
- 🎨 完整的Web管理界面
- 📚 详细的文档和示例
- 🚀 一键安装脚本

---

**如果这个项目对您有帮助，请给我们一个⭐星标支持！**
