# iWAF 宝塔面板配置示例 (Baota Panel Configuration Example)

## 针对宝塔面板用户的完整配置示例

### 1. nginx.conf 配置

在宝塔面板的 Nginx 主配置文件（通常在 `/www/server/nginx/conf/nginx.conf`）中添加：

```nginx
# 在 http 块的开始位置添加以下配置
http {
    # ... 其他配置 ...
    
    # iWAF 共享内存配置 - 必须添加，否则会报错
    lua_shared_dict iwaf_cache 10m;
    
    # iWAF Lua 模块搜索路径 - 根据您的实际安装路径调整
    lua_package_path "/www/server/nginx/iwaf/lua/?.lua;/www/server/nginx/iwaf/lua/iwaf/?.lua;;";
    
    # iWAF 初始化 - 在 Nginx 启动时执行
    init_by_lua_block {
        local iwaf = require "waf"  -- 使用标准模块路径
        iwaf.init()
    }
    
    # ... 其他配置 ...
}
```

### 2. 站点配置示例

在您的站点配置文件中添加：

```nginx
server {
    listen 80;
    server_name test_iwaf_web.ishell.cc;  # 替换为您的域名
    root /www/wwwroot/your_site;          # 替换为您的站点根目录
    index index.php index.html;
    
    # iWAF 请求检查 - 在访问阶段执行
    access_by_lua_block {
        local iwaf = require "waf"
        iwaf.check_request()
    }
    
    # 启用请求体读取（用于 POST 数据分析）
    lua_need_request_body on;
    
    # 设置最大请求体大小
    client_max_body_size 10m;
    
    # 其他 PHP 或静态文件配置
    location ~ \.php$ {
        fastcgi_pass 127.0.0.1:9000;  # 或 unix socket
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }
    
    # 静态文件处理
    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }
    
    # 自定义错误页面
    error_page 403 /blocked.html;
    location = /blocked.html {
        root /www/server/nginx/iwaf/dashboard/web;
        internal;
    }
    
    # 日志配置
    access_log /www/wwwlogs/iwaf_access.log combined;
    error_log /www/wwwlogs/iwaf_error.log warn;
}
```

### 3. 安装步骤

#### 步骤 1: 安装 Lua 模块（如果未安装）

```bash
# CentOS/RHEL
yum install -y nginx-module-lua lua-cjson

# Ubuntu/Debian  
apt-get install -y nginx-module-lua lua-cjson
```

#### 步骤 2: 下载和安装 iWAF

```bash
# 创建目录
mkdir -p /www/server/nginx/iwaf

# 下载 iWAF
cd /tmp
git clone https://github.com/git-xiaomy/iwaf.git
cd iwaf

# 复制文件
cp -r lua/ /www/server/nginx/iwaf/
cp -r dashboard/ /www/server/nginx/iwaf/
cp conf/config.json /www/server/nginx/iwaf/

# 设置权限
chown -R www:www /www/server/nginx/iwaf/
chmod -R 755 /www/server/nginx/iwaf/
```

#### 步骤 3: 测试配置

```bash
# 测试 Nginx 配置
nginx -t

# 如果测试通过，重启 Nginx
systemctl restart nginx

# 查看错误日志确认启动成功
tail -f /www/wwwlogs/iwaf_error.log
```

### 4. 常见问题解决

#### 问题 1: "attempt to index field 'iwaf_cache'"

**解决**: 确保在 `nginx.conf` 中添加了 `lua_shared_dict iwaf_cache 10m;`

#### 问题 2: "module 'iwaf.waf' not found"

**解决**: 检查模块路径是否正确，确保文件存在于 `/www/server/nginx/iwaf/lua/iwaf/waf.lua`

#### 问题 3: "no request found"

**解决**: 这已在最新版本中修复，确保使用最新版本的 iWAF

### 5. 验证安装

访问您的网站，检查以下内容：

1. 网站正常访问（说明 WAF 没有误判）
2. 查看错误日志无相关错误信息
3. 尝试访问可疑路径（如 `/admin/`），应该被阻止

### 6. 性能优化

对于高流量网站，建议调整配置：

```nginx
# 增加共享内存
lua_shared_dict iwaf_cache 50m;

# 调整工作进程数量
worker_processes auto;
```

### 7. 日志监控

监控 iWAF 日志：

```bash
# 实时查看 WAF 日志
tail -f /www/wwwlogs/iwaf_error.log

# 查看被阻止的请求
grep -i "blocked" /www/wwwlogs/iwaf_error.log
```