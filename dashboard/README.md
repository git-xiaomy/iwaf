# iWAF Dashboard

独立的iWAF管理面板，运行在单独的端口上，与主站点完全分离。

## 概述

这个dashboard提供了一个完全独立的Web管理界面，运行在端口8080上，不会占用主站点的URL路径。用户可以手动创建dashboard站点，实现前后端完全分离。

## 特性

- **独立端口**: 运行在8080端口，不影响主站点
- **前后端分离**: Dashboard与WAF核心功能完全解耦
- **安全隔离**: 可独立配置访问控制和安全策略
- **易于部署**: 提供自动化安装脚本
- **灵活配置**: 支持自定义端口和访问权限

## 目录结构

```
dashboard/
├── web/                    # Dashboard前端文件
│   ├── index.html         # 主界面
│   ├── blocked.html       # 阻止页面
│   ├── css/style.css      # 样式文件
│   └── js/app.js          # JavaScript功能
├── conf/                  # Dashboard配置
│   └── dashboard.conf     # Nginx配置文件
├── setup-dashboard.sh     # 自动安装脚本
└── README.md             # 本文档
```

## 安装方法

### 方法一：自动安装（推荐）

```bash
# 进入dashboard目录
cd iwaf/dashboard

# 运行安装脚本
sudo ./setup-dashboard.sh
```

### 方法二：手动安装

#### 1. 创建目录

```bash
sudo mkdir -p /etc/nginx/iwaf/dashboard/{web,conf}
```

#### 2. 复制文件

```bash
# 复制web文件
sudo cp -r web/* /etc/nginx/iwaf/dashboard/web/

# 复制配置文件
sudo cp conf/dashboard.conf /etc/nginx/sites-available/iwaf-dashboard
# 或者复制到conf.d (根据系统配置)
sudo cp conf/dashboard.conf /etc/nginx/conf.d/iwaf-dashboard.conf
```

#### 3. 设置权限

```bash
sudo chown -R www-data:www-data /etc/nginx/iwaf/dashboard/
sudo chmod -R 755 /etc/nginx/iwaf/dashboard/
```

#### 4. 启用站点（如果使用sites-available/sites-enabled）

```bash
sudo ln -s /etc/nginx/sites-available/iwaf-dashboard /etc/nginx/sites-enabled/
```

#### 5. 测试和重启Nginx

```bash
sudo nginx -t
sudo systemctl restart nginx
```

## 配置说明

### Dashboard配置文件

Dashboard的Nginx配置在 `conf/dashboard.conf` 中，主要配置项：

```nginx
# 监听端口（可修改）
listen 8080;

# 访问控制（建议启用）
# allow 192.168.1.0/24;
# allow 127.0.0.1;
# deny all;

# Dashboard根目录
root /etc/nginx/iwaf/dashboard/web;
```

### 自定义端口

如需更改端口，编辑配置文件：

```bash
sudo nano /etc/nginx/sites-available/iwaf-dashboard
# 或
sudo nano /etc/nginx/conf.d/iwaf-dashboard.conf
```

将 `listen 8080;` 改为所需端口，如：

```nginx
listen 9090;
```

重启Nginx生效：

```bash
sudo systemctl restart nginx
```

### 访问控制

为了安全，强烈建议启用IP访问控制：

```nginx
# 只允许内网访问
allow 192.168.0.0/16;
allow 10.0.0.0/8;
allow 127.0.0.1;
deny all;
```

## 访问Dashboard

安装完成后，通过以下URL访问：

```
http://your-server-ip:8080
```

例如：
- `http://192.168.1.100:8080`
- `http://localhost:8080` (本地访问)

## 功能说明

Dashboard提供以下功能：

1. **实时监控**: 查看请求统计和威胁分析
2. **安全配置**: 管理WAF防护规则
3. **IP管理**: 维护白名单和黑名单
4. **日志查看**: 实时查看WAF日志
5. **系统设置**: 配置WAF基本参数

## 安全建议

1. **访问控制**: 
   ```nginx
   # 限制IP访问
   allow 192.168.1.0/24;
   deny all;
   ```

2. **反向代理认证**: 
   ```nginx
   # 添加基本认证
   auth_basic "iWAF Dashboard";
   auth_basic_user_file /etc/nginx/.htpasswd;
   ```

3. **HTTPS访问**: 
   ```nginx
   listen 8443 ssl;
   ssl_certificate /path/to/cert.pem;
   ssl_certificate_key /path/to/key.pem;
   ```

4. **防火墙配置**:
   ```bash
   # UFW
   sudo ufw allow from 192.168.1.0/24 to any port 8080
   
   # Firewalld
   sudo firewall-cmd --permanent --add-rich-rule="rule family='ipv4' source address='192.168.1.0/24' port protocol='tcp' port='8080' accept"
   ```

## 故障排除

### Dashboard无法访问

1. 检查Nginx状态：
   ```bash
   sudo systemctl status nginx
   ```

2. 检查端口监听：
   ```bash
   sudo netstat -tlnp | grep :8080
   ```

3. 查看错误日志：
   ```bash
   sudo tail -f /var/log/nginx/iwaf_dashboard_error.log
   ```

### API连接失败

1. 检查Lua模块加载：
   ```bash
   nginx -V 2>&1 | grep lua
   ```

2. 检查WAF模块路径：
   ```bash
   ls -la /etc/nginx/iwaf/lua/iwaf/
   ```

### 权限问题

重新设置权限：
```bash
sudo chown -R www-data:www-data /etc/nginx/iwaf/dashboard/
sudo chmod -R 755 /etc/nginx/iwaf/dashboard/
```

## 卸载Dashboard

如需移除Dashboard：

```bash
# 删除配置文件
sudo rm -f /etc/nginx/sites-enabled/iwaf-dashboard
sudo rm -f /etc/nginx/sites-available/iwaf-dashboard
sudo rm -f /etc/nginx/conf.d/iwaf-dashboard.conf

# 删除文件
sudo rm -rf /etc/nginx/iwaf/dashboard/

# 重启Nginx
sudo systemctl restart nginx
```

## 与主WAF的关系

- **独立运行**: Dashboard不依赖主站点运行
- **API通信**: 通过Lua模块与WAF核心通信
- **配置同步**: Dashboard配置会同步到WAF核心
- **日志共享**: 查看同一套WAF日志数据

这种架构确保了主站点的性能不受Dashboard影响，同时提供了灵活的管理界面。