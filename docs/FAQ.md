# iWAF 常见问题 (FAQ)

本文档回答关于 iWAF 安装和配置的常见问题。

## 🔧 安装和依赖相关

### 1. 为什么需要安装 lua-redis 和 mysql 依赖？

**当前状态**: 在 iWAF v1.0.0 中，`lua-resty-redis` 和 `lua-resty-mysql` 库被导入但**实际上并未使用**。

**详细说明**:
- 在 `lua/iwaf/waf.lua` 的第15-16行，代码导入了这两个库：
  ```lua
  local redis = require "resty.redis"
  local mysql = require "resty.mysql"
  ```
- 但是在整个代码中，这些库并没有被实际调用或使用
- 安装脚本中将它们标记为可选依赖（使用 `|| true` 忽略安装失败）

**为什么会这样**:
1. **预留功能**: 这些依赖是为未来的功能增强预留的：
   - **Redis**: 计划用于分布式缓存、会话管理、速率限制计数器
   - **MySQL**: 计划用于日志存储、配置持久化、统计数据存储

2. **架构考虑**: 设计时考虑了扩展性，预留了数据库和缓存接口

3. **可选安装**: 安装脚本使用 `|| true` 确保即使这些库安装失败，WAF 仍能正常工作

**当前替代方案**:
- **缓存**: 使用 Nginx 共享内存 (`ngx.shared.iwaf_cache`)
- **存储**: 使用本地 JSON 配置文件 (`/etc/nginx/iwaf/config.json`)
- **日志**: 使用 Nginx 日志系统

**建议**:
- **生产环境**: 可以跳过安装这些依赖，不会影响功能
- **开发环境**: 如果计划扩展功能，建议安装以备将来使用

---

## 🌐 Dashboard 相关

### 2. 默认仪表盘的8080端口是通过什么方式创建的？

**回答**: 8080端口是通过 **Nginx 配置文件** 创建的，具体通过以下方式：

#### 📁 配置文件位置
主要配置文件：`dashboard/conf/dashboard.conf`

#### 🔧 端口配置机制

**1. Nginx Server 块配置**
```nginx
server {
    listen 8080;              # IPv4 监听8080端口
    listen [::]:8080;         # IPv6 监听8080端口
    server_name _;            # 接受所有域名
    
    # Dashboard 根目录
    root /etc/nginx/iwaf/dashboard/web;
    index index.html;
}
```

**2. 自动化部署流程**
```bash
# dashboard/setup-dashboard.sh 脚本执行以下步骤：

1. 复制配置文件到 Nginx 配置目录
   cp dashboard/conf/dashboard.conf /etc/nginx/sites-available/iwaf-dashboard
   
2. 创建软链接启用站点  
   ln -s /etc/nginx/sites-available/iwaf-dashboard /etc/nginx/sites-enabled/

3. 测试 Nginx 配置
   nginx -t

4. 重启 Nginx 服务
   systemctl restart nginx
```

**3. 防火墙配置**
脚本还会自动配置防火墙规则：
```bash
# UFW (Ubuntu/Debian)
ufw allow 8080/tcp

# Firewalld (CentOS/RHEL)  
firewall-cmd --permanent --add-port=8080/tcp
firewall-cmd --reload
```

#### 🔐 安全配置

**访问控制** (可选，但推荐):
```nginx
# 限制IP访问
allow 192.168.1.0/24;    # 允许内网
allow 127.0.0.1;         # 允许本地
deny all;                # 拒绝其他
```

**HTTPS 支持**:
```nginx
listen 8443 ssl;
ssl_certificate /path/to/cert.pem;
ssl_certificate_key /path/to/key.pem;
```

#### 🛠️ 自定义端口

如需更改端口，修改配置文件中的 `listen` 指令：

```bash
# 编辑配置文件
sudo nano /etc/nginx/sites-available/iwaf-dashboard

# 修改端口
listen 9090;     # 改为所需端口

# 重启 Nginx
sudo systemctl restart nginx

# 更新防火墙规则
sudo ufw allow 9090/tcp
```

#### 📊 Dashboard 功能

8080端口提供的服务包括：
- **静态文件服务**: HTML、CSS、JS 文件
- **API 接口**: `/api/` 路径下的 RESTful API
- **实时数据**: 通过 Lua 脚本提供 WAF 统计信息
- **配置管理**: 通过 Web 界面修改 WAF 配置

#### 🔍 故障排除

**检查端口监听**:
```bash
sudo netstat -tlnp | grep :8080
sudo ss -tlnp | grep :8080
```

**查看访问日志**:
```bash
tail -f /var/log/nginx/iwaf_dashboard_access.log
```

**查看错误日志**:
```bash
tail -f /var/log/nginx/iwaf_dashboard_error.log
```

**端口冲突解决方案**:
如果8080端口被其他服务占用，有以下几种解决方案：

1. **查看端口占用情况**:
   ```bash
   # 查看哪个进程在使用8080端口
   sudo netstat -tulnp | grep :8080
   sudo ss -tulnp | grep :8080
   
   # 查看nginx配置中使用8080端口的站点
   sudo grep -r "listen.*8080" /etc/nginx/
   ```

2. **修改dashboard端口**:
   ```bash
   # 编辑dashboard配置文件
   sudo nano /etc/nginx/sites-available/iwaf-dashboard
   # 或
   sudo nano /etc/nginx/conf.d/iwaf-dashboard.conf
   
   # 将端口改为其他可用端口
   listen 9080;
   listen [::]:9080;
   
   # 重启nginx
   sudo systemctl restart nginx
   
   # 更新防火墙规则
   sudo ufw allow 9080/tcp
   ```

3. **使用setup脚本的自动检测功能**:
   - 重新运行 `dashboard/setup-dashboard.sh` 脚本
   - 脚本会自动检测端口冲突并提供解决方案选项

---

### 3. 安装脚本是自动检测nginx位置的吗？

**回答**: 是的，iWAF的安装脚本具有**自动nginx位置检测功能**，支持多种nginx安装方式：

#### 🔧 自动检测机制

**主安装脚本** (`setup.sh`) 和 **dashboard安装脚本** (`dashboard/setup-dashboard.sh`) 都包含nginx自动检测功能：

**检测优先级顺序**:
1. **OpenResty**: `/usr/local/openresty/nginx/conf/`
2. **标准Nginx**: `/etc/nginx/`  
3. **自定义安装**: `/usr/local/nginx/conf/`

**检测代码示例**:
```bash
# 自动检测nginx配置目录
if [ -f /usr/local/openresty/nginx/conf/nginx.conf ]; then
    NGINX_CONF_DIR="/usr/local/openresty/nginx/conf"
    WEB_USER="nobody"
elif [ -f /etc/nginx/nginx.conf ]; then
    NGINX_CONF_DIR="/etc/nginx"
    WEB_USER="www-data"
elif [ -f /usr/local/nginx/conf/nginx.conf ]; then
    NGINX_CONF_DIR="/usr/local/nginx/conf"
    WEB_USER="nginx"
fi
```

#### 📁 支持的nginx配置结构

**1. Ubuntu/Debian标准结构**:
```
/etc/nginx/
├── nginx.conf
├── sites-available/
├── sites-enabled/
└── conf.d/
```

**2. CentOS/RHEL结构**:
```
/etc/nginx/
├── nginx.conf
└── conf.d/
```

**3. OpenResty结构**:
```
/usr/local/openresty/nginx/conf/
├── nginx.conf
└── conf.d/
```

#### 🎯 自动配置功能

**用户和权限自动设置**:
- **Ubuntu/Debian**: `www-data:www-data`
- **CentOS/RHEL**: `nginx:nginx`  
- **OpenResty**: `nobody:nobody`

**配置文件自动放置**:
- 支持 `sites-available/sites-enabled` 结构（Ubuntu/Debian）
- 支持 `conf.d/` 结构（CentOS/RHEL）
- 自动创建软链接启用站点

#### 🛠️ 手动指定nginx路径

如果自动检测失败，可以手动修改配置变量：

```bash
# 编辑安装脚本
nano setup.sh

# 修改nginx配置目录
NGINX_CONF_DIR="/your/custom/nginx/path"
WEB_USER="your_web_user"
WEB_GROUP="your_web_group"
```

#### 🔍 检测验证命令

安装前可以使用以下命令验证nginx安装：

```bash
# 检查nginx是否已安装
command -v nginx

# 查看nginx版本和编译选项
nginx -V

# 查看nginx配置文件位置
nginx -t

# 查看nginx进程用户
ps aux | grep nginx
```

---

## 📝 总结

1. **Redis/MySQL 依赖**: 当前版本中这些是可选的预留依赖，实际未使用，可以跳过安装
2. **8080 端口**: 通过 Nginx 配置文件定义，由安装脚本自动部署和配置

这种设计使得 iWAF 具有良好的模块化和可扩展性，同时保持了当前版本的简洁性。