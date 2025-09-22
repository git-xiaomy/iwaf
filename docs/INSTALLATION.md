# iWAF 安装指南

本指南将帮助您在不同的操作系统上安装和配置 iWAF。

## 系统要求

### 最低要求
- **操作系统**: Ubuntu 18.04+, Debian 9+, CentOS 7+, RHEL 7+
- **内存**: 512MB RAM
- **存储**: 100MB 可用空间
- **网络**: HTTP/HTTPS 端口访问权限

### 推荐配置
- **操作系统**: Ubuntu 20.04 LTS, CentOS 8
- **内存**: 2GB+ RAM
- **CPU**: 2+ 核心
- **存储**: 1GB+ 可用空间

### 软件依赖
- **Nginx**: 1.16+ (带 Lua 模块支持)
- **Lua**: 5.1/5.2/5.3/LuaJIT
- **lua-cjson**: JSON 解析库

## 自动安装 (推荐)

### 使用安装脚本

```bash
# 下载项目
git clone https://github.com/git-xiaomy/iwaf.git
cd iwaf

# 运行安装脚本 (需要 root 权限)
sudo ./setup.sh
```

安装脚本将自动：
- 检测操作系统类型
- 安装必要的软件包
- 配置 Nginx
- 设置文件权限
- 启动服务

## 手动安装

### Ubuntu/Debian

#### 1. 更新包列表并安装依赖

```bash
sudo apt-get update
sudo apt-get install -y nginx nginx-module-lua lua-cjson git
```

#### 2. 安装可选的 Lua 库

```bash
sudo apt-get install -y lua-resty-redis lua-resty-mysql
```

#### 3. 启用 Lua 模块

编辑 `/etc/nginx/nginx.conf`，在文件开头添加：

```nginx
load_module modules/ngx_http_lua_module.so;
```

### CentOS/RHEL

#### 1. 安装 EPEL 源

```bash
sudo yum install -y epel-release
```

#### 2. 安装依赖包

```bash
sudo yum install -y nginx nginx-module-lua lua-cjson git
```

#### 3. 或者安装 OpenResty (推荐)

```bash
# 添加 OpenResty 源
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://openresty.org/package/centos/openresty.repo

# 安装 OpenResty
sudo yum install -y openresty
```

### 使用 OpenResty

如果您选择使用 OpenResty 而不是 Nginx + Lua 模块：

#### Ubuntu/Debian

```bash
# 添加 OpenResty 源
wget -qO - https://openresty.org/package/pubkey.gpg | sudo apt-key add -
echo "deb http://openresty.org/package/ubuntu $(lsb_release -sc) main" \
    | sudo tee /etc/apt/sources.list.d/openresty.list

# 更新并安装
sudo apt-get update
sudo apt-get install -y openresty
```

## 配置安装

### 1. 创建目录结构

```bash
sudo mkdir -p /etc/nginx/iwaf/{lua/iwaf,web/{css,js,images},logs}
```

### 2. 下载并复制文件

```bash
# 克隆项目 (如果还没有)
git clone https://github.com/git-xiaomy/iwaf.git
cd iwaf

# 复制 Lua 模块
sudo cp -r lua/* /etc/nginx/iwaf/lua/

# 复制 Web 界面
sudo cp -r web/* /etc/nginx/iwaf/web/

# 复制配置文件
sudo cp conf/config.json /etc/nginx/iwaf/
sudo cp conf/iwaf.conf /etc/nginx/conf.d/
```

### 3. 设置权限

```bash
sudo chown -R www-data:www-data /etc/nginx/iwaf/
sudo chmod -R 755 /etc/nginx/iwaf/
sudo chmod 644 /etc/nginx/iwaf/config.json
```

**注意**: CentOS/RHEL 用户请将 `www-data` 替换为 `nginx`

### 4. 配置 Nginx

编辑 `/etc/nginx/nginx.conf`，在 `http` 块中添加：

```nginx
http {
    # 其他配置...
    
    # 定义共享内存用于 WAF 缓存
    lua_shared_dict iwaf_cache 10m;
    
    # 设置 Lua 模块路径
    lua_package_path "/etc/nginx/iwaf/lua/?.lua;/etc/nginx/iwaf/lua/iwaf/?.lua;;";
    
    # 初始化 iWAF
    init_by_lua_block {
        local iwaf = require "waf"
        iwaf.init()
    }
    
    # 包含其他配置文件
    include /etc/nginx/conf.d/*.conf;
}
```

### 5. 测试配置

```bash
sudo nginx -t
```

如果测试通过，重启 Nginx：

```bash
sudo systemctl restart nginx
```

### 6. 验证安装

访问以下 URL 验证安装：

- **Web 界面**: `http://your-server-ip/iwaf/`
- **API 状态**: `http://your-server-ip/iwaf/api/stats`

## 高级配置

### 内存优化

对于高流量网站，建议增加共享内存：

```nginx
lua_shared_dict iwaf_cache 50m;  # 增加到 50MB
```

### SSL/HTTPS 配置

如果您使用 HTTPS，确保在 SSL 服务器块中也包含 WAF 配置：

```nginx
server {
    listen 443 ssl http2;
    server_name example.com;
    
    # SSL 配置...
    
    # iWAF 配置
    access_by_lua_block {
        local iwaf = require "waf"
        iwaf.check_request()
    }
    
    lua_need_request_body on;
    
    # 其他配置...
}
```

### 日志轮转

创建日志轮转配置：

```bash
sudo tee /etc/logrotate.d/iwaf << EOF
/var/log/nginx/iwaf_*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 www-data www-data
    postrotate
        systemctl reload nginx
    endscript
}
EOF
```

### 防火墙配置

#### UFW (Ubuntu)

```bash
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

#### Firewalld (CentOS/RHEL)

```bash
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload
```

## 故障排除

### 常见问题

#### 1. Nginx 启动失败

**错误**: `nginx: [emerg] unknown directive "lua_shared_dict"`

**解决**: 确保 Lua 模块已正确加载：

```bash
# 检查 Lua 模块
nginx -V 2>&1 | grep -o with-http_lua_module

# Ubuntu/Debian: 安装 Lua 模块
sudo apt-get install nginx-module-lua

# 在 nginx.conf 开头添加
load_module modules/ngx_http_lua_module.so;
```

#### 2. 权限错误

**错误**: `Permission denied` 访问 iWAF 文件

**解决**: 检查文件权限：

```bash
sudo chown -R www-data:www-data /etc/nginx/iwaf/
sudo chmod -R 755 /etc/nginx/iwaf/
```

#### 3. Web 界面无法访问

**错误**: 404 Not Found

**解决**: 检查 Nginx 配置：

```bash
# 检查配置语法
sudo nginx -t

# 查看错误日志
sudo tail -f /var/log/nginx/error.log

# 确保 iwaf.conf 被正确包含
grep -r "iwaf" /etc/nginx/
```

#### 4. Lua 脚本错误

**错误**: `lua entry thread aborted`

**解决**: 检查 Lua 路径和依赖：

```bash
# 检查 lua-cjson 安装
lua -e "print(require('cjson').encode({test=true}))"

# 检查 iWAF 模块路径
ls -la /etc/nginx/iwaf/lua/iwaf/waf.lua
```

### 调试模式

启用调试模式获取更多信息：

1. 修改 `/etc/nginx/iwaf/config.json`:

```json
{
    "log_level": "debug",
    "action": "log"
}
```

2. 重启 Nginx:

```bash
sudo systemctl restart nginx
```

3. 查看调试日志:

```bash
sudo tail -f /var/log/nginx/error.log
```

### 卸载

如需卸载 iWAF：

```bash
# 删除配置文件
sudo rm -f /etc/nginx/conf.d/iwaf.conf

# 删除 iWAF 目录
sudo rm -rf /etc/nginx/iwaf/

# 从 nginx.conf 中移除 iWAF 相关配置

# 重启 Nginx
sudo systemctl restart nginx
```

## 性能调优

### Nginx Worker 优化

```nginx
worker_processes auto;
worker_connections 2048;
worker_rlimit_nofile 65535;
```

### 系统限制优化

```bash
# 增加文件描述符限制
echo "* soft nofile 65535" | sudo tee -a /etc/security/limits.conf
echo "* hard nofile 65535" | sudo tee -a /etc/security/limits.conf

# 优化内核参数
echo "net.core.somaxconn = 65535" | sudo tee -a /etc/sysctl.conf
echo "net.ipv4.tcp_max_syn_backlog = 65535" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

## 下一步

安装完成后，请参考以下文档：

- [配置指南](CONFIGURATION.md) - 详细的配置选项说明
- [API 文档](API.md) - RESTful API 使用指南
- [最佳实践](BEST_PRACTICES.md) - 安全配置建议

如果遇到问题，请查看 [故障排除文档](TROUBLESHOOTING.md) 或在 GitHub 上提交 issue。