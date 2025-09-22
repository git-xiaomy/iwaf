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

- **操作系统**: Ubuntu 18.04+, Debian 9+, CentOS 7+, RHEL 7+
- **内存**: 最低 512MB RAM，推荐 2GB+
- **存储**: 至少 100MB 可用空间
- **网络**: HTTP/HTTPS 端口访问权限

### 依赖要求

- **Nginx** 1.16+ (需要Lua模块支持) **或** **OpenResty**
- **Lua** 5.1/5.2/5.3/LuaJIT
- **lua-cjson** (JSON解析库)

## 📦 安装部署

根据您的系统环境，选择对应的安装方式：

> **💡 宝塔面板用户特别说明**: 如果您使用宝塔面板管理服务器，请直接跳转到 [方案四：宝塔面板安装的Nginx系统](#-方案四宝塔面板安装的nginx系统) 查看专门的安装方法。宝塔面板使用特殊的目录结构（`/www/server/nginx/`），需要按照特定步骤进行配置。

### 🔧 方案一：纯净系统安装（未安装Nginx）

适用于全新的服务器环境，将自动安装所需的所有依赖。

#### Ubuntu/Debian 系统

```bash
# 1. 更新系统包
sudo apt-get update

# 2. 克隆iWAF项目
git clone https://github.com/git-xiaomy/iwaf.git
cd iwaf

# 3. 一键安装（推荐）
sudo ./setup.sh
```

**手动安装步骤：**

```bash
# 1. 安装Nginx和Lua模块
sudo apt-get update
sudo apt-get install -y nginx nginx-module-lua lua-cjson git

# 2. 启用Lua模块
echo 'load_module modules/ngx_http_lua_module.so;' | sudo tee -a /etc/nginx/modules-enabled/50-mod-http-lua.conf

# 3. 克隆项目并安装
git clone https://github.com/git-xiaomy/iwaf.git
cd iwaf

# 4. 创建目录结构
sudo mkdir -p /etc/nginx/iwaf/{lua/iwaf,web/{css,js,images},logs}

# 5. 复制文件
sudo cp -r lua/* /etc/nginx/iwaf/lua/
sudo cp -r web/* /etc/nginx/iwaf/web/ 2>/dev/null || echo "Web files not found, will create basic structure"
sudo cp conf/config.json /etc/nginx/iwaf/
sudo cp conf/iwaf.conf /etc/nginx/conf.d/

# 6. 设置权限
sudo chown -R www-data:www-data /etc/nginx/iwaf/
sudo chmod -R 755 /etc/nginx/iwaf/
sudo chmod 644 /etc/nginx/iwaf/config.json
sudo chmod 644 /etc/nginx/conf.d/iwaf.conf

# 7. 配置Nginx主配置文件
sudo cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup
sudo tee -a /etc/nginx/nginx.conf > /dev/null << 'EOF'

# iWAF Configuration
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
}
EOF

# 8. 测试配置并重启
sudo nginx -t
sudo systemctl enable nginx
sudo systemctl restart nginx

# 9. 验证安装
curl -I http://localhost
```

#### CentOS/RHEL 系统

```bash
# 1. 安装EPEL源
sudo yum install -y epel-release

# 2. 克隆iWAF项目  
git clone https://github.com/git-xiaomy/iwaf.git
cd iwaf

# 3. 一键安装（推荐）
sudo ./setup.sh
```

**手动安装步骤：**

```bash
# 1. 安装Nginx和依赖
sudo yum install -y epel-release
sudo yum install -y nginx nginx-module-lua lua-cjson git

# 2. 启用Lua模块
echo 'load_module modules/ngx_http_lua_module.so;' | sudo tee /etc/nginx/modules/iwaf-lua.conf

# 3. 其余步骤与Ubuntu类似，但用户组为nginx
sudo chown -R nginx:nginx /etc/nginx/iwaf/
```

### 🔄 方案二：已安装Nginx系统

适用于已经运行Nginx但未安装Lua模块的环境。

#### 检测当前Nginx是否支持Lua

```bash
# 检测Lua模块支持
nginx -V 2>&1 | grep -o with-http_lua_module
```

如果没有输出，需要安装Lua模块：

**Ubuntu/Debian:**
```bash
# 1. 安装Lua模块
sudo apt-get install -y nginx-module-lua lua-cjson

# 2. 启用模块
echo 'load_module modules/ngx_http_lua_module.so;' | sudo tee /etc/nginx/modules-enabled/50-mod-http-lua.conf

# 3. 克隆并安装iWAF
git clone https://github.com/git-xiaomy/iwaf.git
cd iwaf
sudo ./setup.sh

# 4. 或手动配置（跳过Nginx安装步骤）
sudo mkdir -p /etc/nginx/iwaf/{lua/iwaf,web/{css,js,images},logs}
sudo cp -r lua/* /etc/nginx/iwaf/lua/
sudo cp conf/config.json /etc/nginx/iwaf/
sudo cp conf/iwaf.conf /etc/nginx/conf.d/

# 5. 在现有nginx.conf的http块中添加iWAF配置
sudo cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup.$(date +%Y%m%d_%H%M%S)

# 在http块中添加以下配置（手动编辑或脚本添加）
sudo tee -a /tmp/iwaf-http.conf > /dev/null << 'EOF'
    # iWAF Configuration
    lua_shared_dict iwaf_cache 10m;
    lua_package_path "/etc/nginx/iwaf/lua/?.lua;/etc/nginx/iwaf/lua/iwaf/?.lua;;";
    
    init_by_lua_block {
        local iwaf = require "waf"
        iwaf.init()
    }
EOF

# 6. 设置权限和测试
sudo chown -R www-data:www-data /etc/nginx/iwaf/
sudo chmod -R 755 /etc/nginx/iwaf/
sudo nginx -t
sudo systemctl reload nginx
```

**CentOS/RHEL:**
```bash
# 1. 安装Lua模块
sudo yum install -y nginx-module-lua lua-cjson

# 2. 启用模块和配置（用户组为nginx）
sudo chown -R nginx:nginx /etc/nginx/iwaf/
```

### ⚡ 方案三：已安装OpenResty系统

如果您已经在使用OpenResty，安装过程最为简单：

```bash
# 1. 检测OpenResty安装
/usr/local/openresty/bin/openresty -V

# 2. 克隆iWAF项目
git clone https://github.com/git-xiaomy/iwaf.git
cd iwaf

# 3. 使用安装脚本（自动检测OpenResty）
sudo ./setup.sh

# 4. 或手动配置
sudo mkdir -p /usr/local/openresty/nginx/iwaf/{lua/iwaf,web/{css,js,images},logs}
sudo cp -r lua/* /usr/local/openresty/nginx/iwaf/lua/
sudo cp conf/config.json /usr/local/openresty/nginx/iwaf/
sudo cp conf/iwaf.conf /usr/local/openresty/nginx/conf.d/ || sudo mkdir -p /usr/local/openresty/nginx/conf.d && sudo cp conf/iwaf.conf /usr/local/openresty/nginx/conf.d/

# 5. 在nginx.conf的http块中添加配置
sudo cp /usr/local/openresty/nginx/conf/nginx.conf /usr/local/openresty/nginx/conf/nginx.conf.backup.$(date +%Y%m%d_%H%M%S)

# 添加到http块
sudo tee -a /tmp/iwaf-openresty.conf > /dev/null << 'EOF'
    # iWAF Configuration  
    lua_shared_dict iwaf_cache 10m;
    lua_package_path "/usr/local/openresty/nginx/iwaf/lua/?.lua;/usr/local/openresty/nginx/iwaf/lua/iwaf/?.lua;;";
    
    init_by_lua_block {
        local iwaf = require "waf"
        iwaf.init()
    }
    
    include conf.d/*.conf;
EOF

# 6. 设置权限
sudo chown -R nobody:nobody /usr/local/openresty/nginx/iwaf/
sudo chmod -R 755 /usr/local/openresty/nginx/iwaf/

# 7. 测试并重启
sudo /usr/local/openresty/bin/openresty -t
sudo systemctl restart openresty || sudo /usr/local/openresty/bin/openresty -s reload
```

### 🐮 方案四：宝塔面板安装的Nginx系统

适用于使用宝塔面板管理的服务器环境。宝塔面板通常将Nginx安装在特定目录结构中。

#### 检测宝塔面板Nginx安装

```bash
# 检查宝塔面板是否已安装
ls -la /www/server/nginx/

# 检查Nginx版本和模块支持
/www/server/nginx/sbin/nginx -V

# 检查是否支持Lua模块
/www/server/nginx/sbin/nginx -V 2>&1 | grep -o with-http_lua_module
```

#### 安装步骤

**方法一：使用宝塔面板软件商店（推荐）**

如果您的宝塔面板版本较新，可能支持直接安装OpenResty：

```bash
# 1. 在宝塔面板 > 软件商店 > 搜索 "OpenResty" 并安装
# 2. 或者在命令行安装OpenResty替代标准Nginx

# 备份现有配置
sudo cp -r /www/server/nginx/ /www/server/nginx.backup.$(date +%Y%m%d_%H%M%S)

# 停止当前Nginx
sudo /etc/init.d/nginx stop

# 安装OpenResty
wget https://openresty.org/package/centos/openresty.repo -O /etc/yum.repos.d/openresty.repo
sudo yum install -y openresty

# 迁移配置文件
sudo cp -r /www/server/nginx/conf/* /usr/local/openresty/nginx/conf/
```

**方法二：为宝塔Nginx编译Lua模块（高级用户）**

```bash
# 1. 检查当前Nginx编译参数
/www/server/nginx/sbin/nginx -V > /tmp/nginx-compile-args.txt

# 2. 下载Nginx源码和lua模块
cd /tmp
wget http://nginx.org/download/nginx-1.18.0.tar.gz  # 替换为实际版本
wget https://github.com/openresty/lua-nginx-module/archive/v0.10.19.tar.gz
wget https://github.com/openresty/lua-resty-core/archive/v0.1.21.tar.gz

# 3. 编译带Lua模块的Nginx（需要专业知识）
# 注意：此方法复杂且可能影响宝塔面板功能，不建议普通用户使用
```

**方法三：手动配置iWAF适配宝塔环境（推荐）**

```bash
# 1. 克隆iWAF项目
cd /www/wwwroot  # 宝塔默认网站目录
git clone https://github.com/git-xiaomy/iwaf.git
cd iwaf

# 2. 创建iWAF目录结构（适配宝塔路径）
sudo mkdir -p /www/server/nginx/iwaf/{lua/iwaf,web/{css,js,images},logs}

# 3. 复制文件
sudo cp -r lua/* /www/server/nginx/iwaf/lua/
sudo cp conf/config.json /www/server/nginx/iwaf/

# 4. 创建适配宝塔的配置文件
sudo tee /www/server/nginx/conf/iwaf.conf > /dev/null << 'EOF'
# iWAF Configuration for Baota Panel
# 在每个server块中引入此配置

# 启用请求体读取
lua_need_request_body on;

# 设置最大请求体大小
client_max_body_size 10m;

# iWAF访问阶段检查
access_by_lua_block {
    local iwaf = require "waf"
    iwaf.check_request()
}

# 自定义错误页面（可选）
error_page 403 /iwaf_blocked.html;
location = /iwaf_blocked.html {
    root /www/server/nginx/iwaf/web;
    internal;
}
EOF

# 5. 修改宝塔主配置文件
sudo cp /www/server/nginx/conf/nginx.conf /www/server/nginx/conf/nginx.conf.backup.$(date +%Y%m%d_%H%M%S)

# 在http块中添加iWAF配置
sudo sed -i '/http {/a\
    # iWAF Configuration\
    lua_shared_dict iwaf_cache 10m;\
    lua_package_path "/www/server/nginx/iwaf/lua/?.lua;/www/server/nginx/iwaf/lua/iwaf/?.lua;;";\
    \
    init_by_lua_block {\
        local iwaf = require "waf"\
        iwaf.init()\
    }\
    \
    # 包含iWAF配置\
    include iwaf.conf;' /www/server/nginx/conf/nginx.conf

# 6. 设置权限（宝塔使用www用户）
sudo chown -R www:www /www/server/nginx/iwaf/
sudo chmod -R 755 /www/server/nginx/iwaf/
sudo chmod 644 /www/server/nginx/iwaf/config.json

# 7. 测试配置并重启
sudo /www/server/nginx/sbin/nginx -t
sudo /etc/init.d/nginx restart

# 8. 验证安装
curl -I http://localhost
```

#### 宝塔面板特殊配置

**在宝塔面板中为特定网站启用iWAF：**

1. 登录宝塔面板
2. 进入 "网站" > 选择要保护的网站 > "配置文件"
3. 在server块中添加以下配置：

```nginx
server {
    listen 80;
    server_name your-domain.com;
    
    # 引入iWAF配置
    include /www/server/nginx/conf/iwaf.conf;
    
    # 其他网站配置...
    root /www/wwwroot/your-site;
    index index.html index.php;
    
    # PHP处理等其他配置...
}
```

**宝塔面板环境变量设置：**

由于宝塔面板可能使用不同的用户和路径，需要确保环境配置正确：

```bash
# 检查宝塔Nginx用户
ps aux | grep nginx | head -1

# 如果是www用户，调整权限
sudo chown -R www:www /www/server/nginx/iwaf/

# 如果是nginx用户，调整权限  
sudo chown -R nginx:nginx /www/server/nginx/iwaf/
```

#### 宝塔面板注意事项

⚠️ **重要提醒**：

1. **备份配置**：修改宝塔Nginx配置前，务必先备份
2. **面板兼容性**：某些操作可能会在宝塔面板中显示警告，这是正常现象
3. **更新影响**：宝塔面板更新时可能会重置Nginx配置，需要重新应用iWAF配置
4. **日志路径**：宝塔的Nginx日志通常在`/www/wwwlogs/`目录下

**宝塔面板环境测试：**

```bash
# 1. 功能测试
curl "http://your-domain.com/?id=1' OR '1'='1"  # 应该被阻止

# 2. 查看宝塔日志
sudo tail -f /www/wwwlogs/access.log
sudo tail -f /www/wwwlogs/nginx_error.log

# 3. 检查iWAF工作状态
ps aux | grep nginx
/www/server/nginx/sbin/nginx -t
```

### 🌐 安装Dashboard管理界面（可选）

Dashboard是独立运行在8080端口的管理界面：

```bash
# 确保已安装WAF核心功能后
cd iwaf/dashboard

# 一键安装Dashboard
sudo ./setup-dashboard.sh

# 手动安装Dashboard
sudo mkdir -p /etc/nginx/iwaf/dashboard/{web,conf}
sudo cp -r web/* /etc/nginx/iwaf/dashboard/web/
sudo cp conf/dashboard.conf /etc/nginx/sites-available/iwaf-dashboard 2>/dev/null || sudo cp conf/dashboard.conf /etc/nginx/conf.d/iwaf-dashboard.conf

# 启用站点（适用于Ubuntu/Debian的sites-enabled结构）
sudo ln -s /etc/nginx/sites-available/iwaf-dashboard /etc/nginx/sites-enabled/ 2>/dev/null || echo "Using conf.d configuration"

# 设置权限
sudo chown -R www-data:www-data /etc/nginx/iwaf/dashboard/ || sudo chown -R nginx:nginx /etc/nginx/iwaf/dashboard/
sudo chmod -R 755 /etc/nginx/iwaf/dashboard/

# 配置防火墙（可选）
sudo ufw allow 8080/tcp 2>/dev/null || sudo firewall-cmd --permanent --add-port=8080/tcp && sudo firewall-cmd --reload 2>/dev/null || echo "Please manually open port 8080"

# 测试并重启Nginx
sudo nginx -t
sudo systemctl reload nginx

# 访问Dashboard
echo "Dashboard安装完成，访问地址: http://你的服务器IP:8080"
```

## ✅ 安装验证

### 验证WAF核心功能

安装完成后，请按以下步骤验证iWAF是否正常工作：

#### 1. 检查服务状态

```bash
# 检查Nginx状态
sudo systemctl status nginx

# 检查Nginx配置
sudo nginx -t

# 检查iWAF文件是否存在
ls -la /etc/nginx/iwaf/
ls -la /etc/nginx/iwaf/lua/iwaf/
ls -la /etc/nginx/conf.d/iwaf.conf
```

#### 2. 检查Lua模块加载

```bash
# 检查Nginx是否加载了Lua模块
nginx -V 2>&1 | grep -o "with-http_lua_module\|lua"

# 检查共享内存是否创建成功（在Nginx运行后）
ps aux | grep nginx
```

#### 3. 功能测试

```bash
# 1. 正常访问测试
curl -I http://localhost

# 2. SQL注入测试（应该被阻止）
curl "http://localhost/?id=1' OR '1'='1"

# 3. XSS测试（应该被阻止）  
curl "http://localhost/?name=<script>alert('xss')</script>"

# 4. 路径遍历测试（应该被阻止）
curl "http://localhost/../../../etc/passwd"

# 5. 检查WAF日志
sudo tail -f /var/log/nginx/error.log
sudo tail -f /var/log/nginx/iwaf_access.log 2>/dev/null || echo "WAF access log not created yet"
```

#### 4. 配置验证

```bash
# 检查配置文件内容
cat /etc/nginx/iwaf/config.json | head -20

# 检查WAF是否启用
grep -A 5 -B 5 "enabled" /etc/nginx/iwaf/config.json
```

### 验证Dashboard（如已安装）

```bash
# 1. 检查Dashboard文件
ls -la /etc/nginx/iwaf/dashboard/web/

# 2. 检查Dashboard配置
nginx -T 2>/dev/null | grep -A 10 -B 10 "8080\|dashboard"

# 3. 测试Dashboard访问
curl -I http://localhost:8080

# 4. 在浏览器中访问
echo "请在浏览器中访问: http://$(curl -s ifconfig.me):8080"
```

## 🔧 故障排除

### 常见问题及解决方案

#### 问题1: Nginx启动失败 - "unknown directive lua_shared_dict"

**原因**: Lua模块未正确加载

**解决方案**:
```bash
# Ubuntu/Debian
sudo apt-get install nginx-module-lua
echo 'load_module modules/ngx_http_lua_module.so;' | sudo tee /etc/nginx/modules-enabled/50-mod-http-lua.conf

# CentOS/RHEL
sudo yum install nginx-module-lua
echo 'load_module modules/ngx_http_lua_module.so;' | sudo tee /etc/nginx/conf.d/00-lua.conf

# 重启Nginx
sudo systemctl restart nginx
```

#### 问题2: "lua entry thread aborted" 错误

**原因**: Lua脚本路径或依赖问题

**解决方案**:
```bash
# 1. 检查lua-cjson是否安装
lua -e "print(require('cjson').encode({test=true}))"

# 2. 检查文件路径是否正确
ls -la /etc/nginx/iwaf/lua/iwaf/waf.lua

# 3. 检查文件权限
sudo chown -R www-data:www-data /etc/nginx/iwaf/
sudo chmod -R 755 /etc/nginx/iwaf/

# 4. 检查Nginx配置中的路径
grep -r "lua_package_path" /etc/nginx/
```

#### 问题3: WAF不工作，恶意请求未被阻止

**排查步骤**:
```bash
# 1. 检查WAF是否启用
grep "enabled" /etc/nginx/iwaf/config.json

# 2. 检查server块是否包含WAF配置
nginx -T | grep -A 10 -B 10 "access_by_lua_block"

# 3. 启用调试模式
sudo sed -i 's/"log_level": "info"/"log_level": "debug"/' /etc/nginx/iwaf/config.json
sudo sed -i 's/"action": "block"/"action": "log"/' /etc/nginx/iwaf/config.json
sudo systemctl reload nginx

# 4. 测试并查看日志
curl "http://localhost/?id=1' OR '1'='1"
sudo tail -f /var/log/nginx/error.log
```

#### 问题4: Dashboard无法访问（404错误）

**解决方案**:
```bash
# 1. 检查Dashboard文件是否存在
ls -la /etc/nginx/iwaf/dashboard/web/

# 2. 检查Nginx配置
nginx -T | grep -A 20 "8080\|dashboard"

# 3. 检查端口是否被占用
sudo netstat -tlnp | grep 8080
sudo ss -tlnp | grep 8080

# 4. 重新安装Dashboard
cd iwaf/dashboard
sudo ./setup-dashboard.sh
```

#### 问题5: 权限错误

**解决方案**:
```bash
# 标准Nginx安装
sudo chown -R www-data:www-data /etc/nginx/iwaf/
sudo chmod -R 755 /etc/nginx/iwaf/

# CentOS/RHEL
sudo chown -R nginx:nginx /etc/nginx/iwaf/
sudo chmod -R 755 /etc/nginx/iwaf/

# OpenResty
sudo chown -R nobody:nobody /usr/local/openresty/nginx/iwaf/
sudo chmod -R 755 /usr/local/openresty/nginx/iwaf/

# 宝塔面板
sudo chown -R www:www /www/server/nginx/iwaf/
sudo chmod -R 755 /www/server/nginx/iwaf/
```

#### 问题6: 宝塔面板特有问题

**问题**: 宝塔面板更新后iWAF配置丢失

**解决方案**:
```bash
# 1. 重新应用iWAF配置
sudo cp /www/server/nginx/conf/nginx.conf.backup.* /www/server/nginx/conf/nginx.conf

# 2. 或者重新添加配置
sudo sed -i '/http {/a\
    # iWAF Configuration\
    lua_shared_dict iwaf_cache 10m;\
    lua_package_path "/www/server/nginx/iwaf/lua/?.lua;/www/server/nginx/iwaf/lua/iwaf/?.lua;;";\
    \
    init_by_lua_block {\
        local iwaf = require "waf"\
        iwaf.init()\
    }\
    \
    # 包含iWAF配置\
    include iwaf.conf;' /www/server/nginx/conf/nginx.conf

# 3. 重启Nginx
sudo /etc/init.d/nginx restart
```

**问题**: 宝塔面板中显示Nginx配置错误

**解决方案**:
```bash
# 1. 检查配置语法
sudo /www/server/nginx/sbin/nginx -t

# 2. 检查Lua模块是否已加载
sudo /www/server/nginx/sbin/nginx -V 2>&1 | grep lua

# 3. 如果Lua模块不支持，可以尝试安装OpenResty
# 在宝塔面板 > 软件商店 > 搜索并安装 "OpenResty"
```

#### 问题7: 内存或性能问题

**优化方案**:
```bash
# 1. 增加共享内存
sudo sed -i 's/lua_shared_dict iwaf_cache 10m;/lua_shared_dict iwaf_cache 50m;/' /etc/nginx/nginx.conf

# 2. 优化worker进程
sudo sed -i 's/worker_processes auto;/worker_processes auto;\nworker_connections 2048;/' /etc/nginx/nginx.conf

# 3. 启用Lua代码缓存
echo 'lua_code_cache on;' | sudo tee -a /etc/nginx/nginx.conf

# 宝塔面板环境优化
# 宝塔面板配置文件位置：/www/server/nginx/conf/nginx.conf
sudo sed -i 's/lua_shared_dict iwaf_cache 10m;/lua_shared_dict iwaf_cache 50m;/' /www/server/nginx/conf/nginx.conf
```
```

### 调试模式

启用详细调试信息：

```bash
# 1. 修改配置启用调试
sudo tee /tmp/debug-config.json > /dev/null << 'EOF'
{
    "enabled": true,
    "log_level": "debug", 
    "action": "log",
    "ip_whitelist": ["127.0.0.1", "::1"]
}
EOF

# 2. 备份并替换配置
sudo cp /etc/nginx/iwaf/config.json /etc/nginx/iwaf/config.json.backup
sudo cp /tmp/debug-config.json /etc/nginx/iwaf/config.json

# 3. 重新加载配置
sudo systemctl reload nginx

# 4. 实时查看日志
sudo tail -f /var/log/nginx/error.log

# 5. 在另一个终端进行测试
curl "http://localhost/?test=<script>alert('xss')</script>"
```

### 完全卸载

如需完全删除iWAF：

```bash
# 1. 停止Nginx
sudo systemctl stop nginx

# 2. 备份原始配置
sudo cp /etc/nginx/nginx.conf.backup /etc/nginx/nginx.conf 2>/dev/null || echo "No backup found"

# 3. 删除iWAF文件
sudo rm -rf /etc/nginx/iwaf/
sudo rm -f /etc/nginx/conf.d/iwaf*.conf
sudo rm -f /etc/nginx/sites-enabled/iwaf-dashboard 2>/dev/null
sudo rm -f /etc/nginx/sites-available/iwaf-dashboard 2>/dev/null

# 4. 清理模块配置（如果使用了单独的模块配置文件）
sudo rm -f /etc/nginx/modules-enabled/*lua* 2>/dev/null
sudo rm -f /etc/nginx/conf.d/*lua* 2>/dev/null

# 5. 清理日志轮转
sudo rm -f /etc/logrotate.d/iwaf 2>/dev/null

# 6. 重启Nginx
sudo nginx -t
sudo systemctl start nginx
```

## 📋 安装方式总结

根据您的服务器环境选择合适的安装方式：

| 环境类型 | 推荐方式 | 安装命令 | 特点 |
|---------|---------|----------|------|
| **纯净系统** | 一键安装 | `sudo ./setup.sh` | 全自动安装，适合新服务器 |
| **已有Nginx** | 脚本安装 | `sudo ./setup.sh` | 自动检测现有配置 |
| **已有OpenResty** | 脚本安装 | `sudo ./setup.sh` | 完美兼容，性能最佳 |
| **宝塔面板环境** | 手动安装 | 详细步骤安装 | 适配宝塔路径，保持面板兼容 |
| **生产环境** | 手动安装 | 详细步骤安装 | 可控性强，便于定制 |

### 🎯 快速选择指南

**1. 如果您是第一次部署：**
```bash
git clone https://github.com/git-xiaomy/iwaf.git
cd iwaf
sudo ./setup.sh
```

**2. 如果您已经有网站在运行：**
```bash
# 先备份现有配置
sudo cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup
# 然后运行安装
git clone https://github.com/git-xiaomy/iwaf.git
cd iwaf
sudo ./setup.sh
```

**3. 如果您使用OpenResty：**
```bash
# 直接安装，脚本会自动识别
git clone https://github.com/git-xiaomy/iwaf.git  
cd iwaf
sudo ./setup.sh
```

**4. 如果您使用宝塔面板：**
```bash
# 克隆到宝塔网站目录
cd /www/wwwroot
git clone https://github.com/git-xiaomy/iwaf.git
cd iwaf
# 按照方案四手动配置步骤进行安装
```

**5. 如果您需要Dashboard管理界面：**
```bash
# 安装WAF后再安装Dashboard
cd iwaf/dashboard
sudo ./setup-dashboard.sh
# 访问：http://你的IP:8080
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

### 安装相关

**Q: 我的系统是CentOS 8，应该如何安装？**
A: CentOS 8已停止维护，建议使用AlmaLinux或Rocky Linux。安装方法相同：
```bash
sudo dnf install epel-release
sudo dnf install nginx nginx-module-lua lua-devel
# 然后运行：sudo ./setup.sh
```

**Q: 为什么安装脚本提示找不到nginx-module-lua？**
A: 某些系统可能没有此包，可以选择安装OpenResty：
```bash
# Ubuntu/Debian
wget -qO - https://openresty.org/package/pubkey.gpg | sudo apt-key add -
echo "deb http://openresty.org/package/ubuntu $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/openresty.list
sudo apt-get update && sudo apt-get install -y openresty

# CentOS/RHEL
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://openresty.org/package/centos/openresty.repo
sudo yum install -y openresty
```

**Q: lua-resty-redis 和 lua-resty-mysql 安装失败怎么办？**
A: 这些是可选依赖，当前版本不需要。如果安装失败可以忽略，不影响WAF功能。

**Q: 可以安装在Docker容器中吗？**
A: 可以，但需要注意：
```dockerfile
FROM openresty/openresty:alpine
COPY iwaf/ /etc/nginx/iwaf/
# 配置文件需要适配容器环境
```

### 配置相关

**Q: 如何修改Dashboard端口？**
A: 编辑Dashboard配置文件：
```bash
sudo nano /etc/nginx/conf.d/iwaf-dashboard.conf
# 修改：listen 8080; 为其他端口
# 重启：sudo systemctl reload nginx
```

**Q: 如何添加IP白名单？**
A: 编辑配置文件：
```bash
sudo nano /etc/nginx/iwaf/config.json
# 在ip_whitelist数组中添加IP
# 重启：sudo systemctl reload nginx
```

**Q: WAF误报太多，如何调整？**
A: 建议先设置为监控模式：
```bash
# 修改配置文件中的action为"log"
"action": "log"
# 然后根据日志调整规则
```

**Q: 如何自定义阻挡页面？**
A: 修改阻挡页面：
```bash
sudo nano /etc/nginx/iwaf/web/blocked.html
# 自定义页面内容
```

### 性能相关

**Q: WAF对网站性能影响大吗？**
A: 影响很小，通常增加1-3ms延迟。可以通过以下方式优化：
- 增加共享内存：`lua_shared_dict iwaf_cache 50m;`
- 启用Lua缓存：`lua_code_cache on;`
- 优化检测规则

**Q: 高并发网站如何优化？**
A: 
```bash
# 1. 增加worker进程
worker_processes auto;
worker_connections 2048;

# 2. 增加共享内存
lua_shared_dict iwaf_cache 100m;

# 3. 系统优化
echo 'net.core.somaxconn = 65535' >> /etc/sysctl.conf
```

### 功能相关

**Q: 支持IPv6吗？**
A: 支持。IPv6地址可以直接添加到白名单：
```json
"ip_whitelist": ["::1", "2001:db8::1"]
```

**Q: 支持集群部署吗？**
A: 当前版本使用本地存储。集群部署建议：
- 每个节点独立部署iWAF
- 使用中心化日志收集
- 配置文件保持同步

**Q: 可以和其他WAF产品共存吗？**
A: 可以，但建议只启用一个WAF避免重复检测影响性能。

查看 [FAQ 文档](docs/FAQ.md) 了解更多：
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

### 生产环境部署建议

#### 1. 系统安全

```bash
# 系统更新
sudo apt-get update && sudo apt-get upgrade -y  # Ubuntu/Debian
sudo yum update -y  # CentOS/RHEL

# 配置防火墙
sudo ufw enable  # Ubuntu/Debian
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp  
sudo ufw allow 443/tcp
sudo ufw allow 8080/tcp  # 如果使用Dashboard

# CentOS/RHEL防火墙
sudo firewall-cmd --permanent --add-service=ssh
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --permanent --add-port=8080/tcp  # Dashboard端口
sudo firewall-cmd --reload
```

#### 2. Dashboard安全配置

修改Dashboard配置以限制访问：

```bash
# 编辑Dashboard配置文件
sudo nano /etc/nginx/conf.d/iwaf-dashboard.conf

# 或者如果使用sites-available
sudo nano /etc/nginx/sites-available/iwaf-dashboard
```

**安全配置示例**:
```nginx
server {
    listen 8080;
    server_name _;
    
    # 限制访问IP（重要！）
    allow 192.168.1.0/24;    # 内网IP段
    allow 10.0.0.0/24;       # 内网IP段
    allow YOUR_IP_ADDRESS;   # 你的管理IP
    deny all;
    
    # 基础认证（可选）
    auth_basic "iWAF Dashboard";
    auth_basic_user_file /etc/nginx/.htpasswd;
    
    root /etc/nginx/iwaf/dashboard/web;
    index index.html;
    
    # 安全头
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains";
    
    location / {
        try_files $uri $uri/ =404;
    }
}
```

**创建Dashboard密码认证**:
```bash
# 安装htpasswd工具
sudo apt-get install apache2-utils  # Ubuntu/Debian
sudo yum install httpd-tools         # CentOS/RHEL

# 创建密码文件
sudo htpasswd -c /etc/nginx/.htpasswd admin

# 重启Nginx应用配置
sudo systemctl reload nginx
```

#### 3. HTTPS配置

强烈建议为Dashboard配置HTTPS：

```bash
# 1. 获取SSL证书（Let's Encrypt示例）
sudo apt-get install certbot python3-certbot-nginx  # Ubuntu/Debian
sudo yum install certbot python3-certbot-nginx      # CentOS/RHEL

# 2. 获取证书
sudo certbot --nginx -d your-domain.com

# 3. 或者使用自签名证书（测试环境）
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/private/iwaf.key \
    -out /etc/ssl/certs/iwaf.crt

# 4. 修改Dashboard配置支持HTTPS
sudo tee /etc/nginx/conf.d/iwaf-dashboard-ssl.conf > /dev/null << 'EOF'
server {
    listen 8443 ssl http2;
    server_name _;
    
    ssl_certificate /etc/ssl/certs/iwaf.crt;
    ssl_certificate_key /etc/ssl/private/iwaf.key;
    
    # SSL安全配置
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    
    # 其他配置...
    root /etc/nginx/iwaf/dashboard/web;
    index index.html;
}

# 重定向HTTP到HTTPS
server {
    listen 8080;
    server_name _;
    return 301 https://$server_name:8443$request_uri;
}
EOF

# 开放HTTPS端口
sudo ufw allow 8443/tcp  # Ubuntu/Debian
sudo firewall-cmd --permanent --add-port=8443/tcp && sudo firewall-cmd --reload  # CentOS/RHEL
```

#### 4. 文件权限安全

```bash
# 设置安全的文件权限
sudo chmod 600 /etc/nginx/iwaf/config.json
sudo chmod 644 /etc/nginx/conf.d/iwaf*.conf
sudo chmod -R 755 /etc/nginx/iwaf/lua/
sudo chmod -R 644 /etc/nginx/iwaf/web/

# 防止配置文件被Web访问
sudo tee /etc/nginx/iwaf/web/.htaccess > /dev/null << 'EOF'
<Files "*.json">
    Order allow,deny
    Deny from all
</Files>
EOF
```

#### 5. 日志安全

```bash
# 创建安全的日志目录
sudo mkdir -p /var/log/iwaf
sudo chown root:adm /var/log/iwaf
sudo chmod 750 /var/log/iwaf

# 配置日志轮转
sudo tee /etc/logrotate.d/iwaf > /dev/null << 'EOF'
/var/log/iwaf/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 640 root adm
    postrotate
        systemctl reload nginx
    endscript
}
EOF
```

### 性能优化建议

#### 1. Nginx配置优化

```bash
# 编辑主配置文件
sudo nano /etc/nginx/nginx.conf

# 推荐配置
sudo tee -a /tmp/nginx-optimization.conf > /dev/null << 'EOF'
# Worker进程优化
worker_processes auto;
worker_connections 2048;
worker_rlimit_nofile 65535;

# 事件模型优化
events {
    use epoll;
    multi_accept on;
}

http {
    # 连接优化
    keepalive_timeout 30;
    keepalive_requests 1000;
    client_max_body_size 10m;
    
    # 缓冲区优化
    client_body_buffer_size 128k;
    client_header_buffer_size 1k;
    large_client_header_buffers 4 4k;
    
    # iWAF内存优化
    lua_shared_dict iwaf_cache 50m;
    lua_code_cache on;
    
    # 压缩优化
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/json;
}
EOF
```

#### 2. 系统优化

```bash
# 系统内核参数优化
sudo tee -a /etc/sysctl.conf > /dev/null << 'EOF'
# 网络优化
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.tcp_max_tw_buckets = 5000

# 文件描述符优化  
fs.file-max = 2097152
EOF

# 应用内核参数
sudo sysctl -p

# 用户限制优化
sudo tee -a /etc/security/limits.conf > /dev/null << 'EOF'
* soft nofile 65535
* hard nofile 65535
nginx soft nofile 65535
nginx hard nofile 65535
www-data soft nofile 65535
www-data hard nofile 65535
EOF
```

### 监控和维护

#### 1. 系统监控脚本

```bash
# 创建监控脚本
sudo tee /usr/local/bin/iwaf-monitor.sh > /dev/null << 'EOF'
#!/bin/bash

# iWAF监控脚本
LOG_FILE="/var/log/iwaf/monitor.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

# 检查Nginx状态
if ! systemctl is-active --quiet nginx; then
    echo "[$DATE] ALERT: Nginx is not running!" >> $LOG_FILE
    systemctl restart nginx
fi

# 检查WAF配置
if ! nginx -t 2>/dev/null; then
    echo "[$DATE] ALERT: Nginx configuration error!" >> $LOG_FILE
fi

# 检查内存使用
MEMORY_USAGE=$(free | grep Mem | awk '{printf "%.2f", $3/$2 * 100.0}')
if (( $(echo "$MEMORY_USAGE > 85" | bc -l) )); then
    echo "[$DATE] WARNING: High memory usage: ${MEMORY_USAGE}%" >> $LOG_FILE
fi

# 检查日志文件大小
LOG_SIZE=$(du -sm /var/log/nginx/ | cut -f1)
if [ $LOG_SIZE -gt 1000 ]; then
    echo "[$DATE] WARNING: Nginx logs size: ${LOG_SIZE}MB" >> $LOG_FILE
fi

echo "[$DATE] Monitor check completed" >> $LOG_FILE
EOF

# 设置执行权限
sudo chmod +x /usr/local/bin/iwaf-monitor.sh

# 添加到crontab（每5分钟检查一次）
echo "*/5 * * * * root /usr/local/bin/iwaf-monitor.sh" | sudo tee -a /etc/crontab
```

#### 2. 备份脚本

```bash
# 创建备份脚本
sudo tee /usr/local/bin/iwaf-backup.sh > /dev/null << 'EOF'
#!/bin/bash

BACKUP_DIR="/var/backups/iwaf"
DATE=$(date '+%Y%m%d_%H%M%S')

# 创建备份目录
mkdir -p $BACKUP_DIR

# 备份配置文件
tar -czf "$BACKUP_DIR/iwaf-config-$DATE.tar.gz" \
    /etc/nginx/iwaf/ \
    /etc/nginx/nginx.conf \
    /etc/nginx/conf.d/iwaf*.conf \
    /etc/nginx/sites-available/iwaf* 2>/dev/null

# 清理旧备份（保留7天）
find $BACKUP_DIR -name "iwaf-config-*.tar.gz" -mtime +7 -delete

echo "Backup completed: iwaf-config-$DATE.tar.gz"
EOF

sudo chmod +x /usr/local/bin/iwaf-backup.sh

# 每日备份
echo "0 2 * * * root /usr/local/bin/iwaf-backup.sh" | sudo tee -a /etc/crontab
```

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
