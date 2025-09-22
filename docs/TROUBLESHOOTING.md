# iWAF 故障排除指南 (Troubleshooting Guide)

## 常见错误及解决方案 (Common Errors and Solutions)

### 错误 1: "attempt to index field 'iwaf_cache' (a nil value)"

**错误信息:**
```
lua entry thread aborted: runtime error: /www/server/nginx/iwaf/lua/iwaf/waf.lua:194: 
attempt to index field ＇iwaf_cache＇ (a nil value)
```

**原因:** 
Nginx 配置中缺少共享字典定义，或者共享字典名称不匹配。

**解决方案:**

1. 确保在 `nginx.conf` 的 `http` 块中添加以下配置：
```nginx
http {
    # 定义共享内存字典
    lua_shared_dict iwaf_cache 10m;
    
    # 其他配置...
}
```

2. 检查配置文件语法：
```bash
nginx -t
```

3. 重启 Nginx：
```bash
systemctl restart nginx
```

### 错误 2: "no request found" 在初始化阶段

**错误信息:**
```
init_by_lua error: /www/server/nginx/lualib/resty/core/var.lua:71: no request found
```

**原因:** 
在初始化阶段尝试访问请求上下文相关的变量（如 `ngx.var.remote_addr`）。

**解决方案:**
此问题已在最新版本中修复。如果仍然遇到此错误，请更新到最新版本的 iWAF。

### 错误 3: 模块加载失败

**错误信息:**
```
module 'waf' not found
```

**解决方案:**

1. 确保 Lua 模块搜索路径正确：
```nginx
lua_package_path "/www/server/nginx/iwaf/lua/?.lua;/www/server/nginx/iwaf/lua/iwaf/?.lua;;";
```

2. 根据您的安装路径调整路径，常见路径包括：
   - `/etc/nginx/iwaf/lua/`
   - `/www/server/nginx/iwaf/lua/`
   - `/usr/local/nginx/iwaf/lua/`

3. 检查文件权限：
```bash
chown -R nginx:nginx /www/server/nginx/iwaf/
chmod -R 755 /www/server/nginx/iwaf/
```

## 配置验证清单 (Configuration Checklist)

在部署 iWAF 时，请确保以下配置正确：

### 1. 基本配置要求

- [ ] Nginx 已安装 Lua 模块支持
- [ ] 共享字典 `lua_shared_dict iwaf_cache 10m;` 已配置
- [ ] Lua 模块搜索路径已配置
- [ ] iWAF 文件已正确复制到目标目录

### 2. 宝塔面板用户特别注意

如果您使用宝塔面板，请确保：

```nginx
# 在 nginx.conf 的 http 块中添加
http {
    # 共享字典配置
    lua_shared_dict iwaf_cache 10m;
    
    # 模块路径配置（根据实际安装路径调整）
    lua_package_path "/www/server/nginx/iwaf/lua/?.lua;/www/server/nginx/iwaf/lua/iwaf/?.lua;;";
    
    # 初始化配置
    init_by_lua_block {
        local iwaf = require "iwaf.waf"  -- 注意这里的路径
        iwaf.init()
    }
}
```

### 3. 测试配置

1. 测试 Nginx 配置语法：
```bash
nginx -t
```

2. 重载 Nginx 配置：
```bash
nginx -s reload
```

3. 检查错误日志：
```bash
tail -f /var/log/nginx/error.log
```

## 性能优化建议 (Performance Optimization)

### 调整共享内存大小

根据网站流量调整共享内存大小：

```nginx
# 低流量站点 (< 1000 req/min)
lua_shared_dict iwaf_cache 10m;

# 中等流量站点 (1000-10000 req/min)
lua_shared_dict iwaf_cache 50m;

# 高流量站点 (> 10000 req/min)
lua_shared_dict iwaf_cache 100m;
```

### 日志级别调整

在生产环境中，建议调整日志级别：

```json
{
    "log_level": "warn",  // 减少调试信息
    "action": "block"     // 确保阻止恶意请求
}
```

## 技术支持

如果遇到其他问题，请：

1. 查看 Nginx 错误日志获取详细信息
2. 确认所有依赖库已正确安装（lua-cjson 等）
3. 检查文件权限和路径配置
4. 参考项目 GitHub 仓库的 Issues 页面