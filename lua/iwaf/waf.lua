--[[
    iWAF - Intelligent Web Application Firewall for Nginx
    Author: iwaf project
    Version: 1.0.0
    Description: A comprehensive WAF module with security features including
                IP filtering, SQL injection protection, XSS protection,
                rate limiting, and web management interface.
--]]

local _M = {}
_M._VERSION = '1.0.0'

-- Import required modules
local cjson = require "cjson"
local redis = require "resty.redis"
local mysql = require "resty.mysql"

-- Configuration file path
local config_file = "/etc/nginx/iwaf/config.json"

-- Default configuration
local default_config = {
    -- 基本设置
    enabled = true,
    log_level = "info",
    action = "block", -- block, log, redirect
    
    -- IP过滤
    ip_whitelist = {},
    ip_blacklist = {},
    
    -- 速率限制
    rate_limit = {
        enabled = true,
        requests_per_minute = 120,
        burst = 20
    },
    
    -- SQL注入防护
    sql_injection = {
        enabled = true,
        patterns = {
            "union.*select",
            "select.*from",
            "insert.*into",
            "delete.*from",
            "update.*set",
            "drop.*table",
            "'.*or.*'.*=.*'",
            "1.*=.*1",
            "sleep\\(",
            "benchmark\\(",
            "load_file\\(",
            "outfile.*into"
        }
    },
    
    -- XSS防护
    xss_protection = {
        enabled = true,
        patterns = {
            "<script[^>]*>.*?</script>",
            "javascript:",
            "onload=",
            "onerror=",
            "onclick=",
            "onmouseover=",
            "<iframe[^>]*>",
            "eval\\(",
            "expression\\(",
            "vbscript:"
        }
    },
    
    -- 路径遍历防护
    path_traversal = {
        enabled = true,
        patterns = {
            "\\.\\./",
            "\\.\\.\\\\",
            "/etc/passwd",
            "/etc/shadow",
            "\\\\windows\\\\",
            "cmd\\.exe",
            "powershell"
        }
    },
    
    -- User-Agent过滤
    user_agent = {
        enabled = true,
        blocked_agents = {
            "sqlmap",
            "nmap",
            "nikto",
            "w3af",
            "acunetix",
            "nessus",
            "openvas"
        }
    },
    
    -- 请求大小限制
    request_limits = {
        max_body_size = 10485760, -- 10MB
        max_uri_length = 2048,
        max_header_size = 8192
    },
    
    -- 文件类型过滤
    file_extension = {
        enabled = true,
        blocked_extensions = {
            "php", "asp", "aspx", "jsp", "exe", "bat", "cmd", "sh"
        }
    }
}

-- 全局配置变量
local config = default_config

-- 日志函数
local function log_event(level, message, details)
    local log_data = {
        timestamp = ngx.now(),
        level = level,
        message = message,
        details = details or {},
        client_ip = ngx.var.remote_addr,
        request_uri = ngx.var.request_uri,
        user_agent = ngx.var.http_user_agent
    }
    
    if level == "error" or level == "warn" then
        ngx.log(ngx.ERR, cjson.encode(log_data))
    elseif level == "info" then
        ngx.log(ngx.INFO, cjson.encode(log_data))
    else
        ngx.log(ngx.DEBUG, cjson.encode(log_data))
    end
end

-- 加载配置文件
local function load_config()
    local file = io.open(config_file, "r")
    if file then
        local content = file:read("*a")
        file:close()
        
        local ok, loaded_config = pcall(cjson.decode, content)
        if ok and loaded_config then
            -- 合并配置
            for k, v in pairs(loaded_config) do
                config[k] = v
            end
            log_event("info", "Configuration loaded successfully", {file = config_file})
        else
            log_event("warn", "Failed to parse configuration file, using defaults", {file = config_file})
        end
    else
        log_event("info", "Configuration file not found, using defaults", {file = config_file})
    end
end

-- IP检查函数
local function check_ip(client_ip)
    -- 检查白名单
    for _, ip in ipairs(config.ip_whitelist) do
        if client_ip == ip then
            return "allow"
        end
    end
    
    -- 检查黑名单
    for _, ip in ipairs(config.ip_blacklist) do
        if client_ip == ip then
            return "block"
        end
    end
    
    return "pass"
end

-- 速率限制检查
local function check_rate_limit(client_ip)
    if not config.rate_limit.enabled then
        return "pass"
    end
    
    local key = "iwaf:rate:" .. client_ip
    local current_requests = ngx.shared.iwaf_cache:get(key) or 0
    
    if current_requests >= config.rate_limit.requests_per_minute then
        return "block"
    end
    
    local ok, err = ngx.shared.iwaf_cache:incr(key, 1, 0, 60)
    if not ok then
        log_event("error", "Rate limit counter error", {error = err})
    end
    
    return "pass"
end

-- SQL注入检查
local function check_sql_injection(content)
    if not config.sql_injection.enabled then
        return "pass"
    end
    
    local lower_content = string.lower(content)
    
    for _, pattern in ipairs(config.sql_injection.patterns) do
        if string.match(lower_content, pattern) then
            return "block", pattern
        end
    end
    
    return "pass"
end

-- XSS检查
local function check_xss(content)
    if not config.xss_protection.enabled then
        return "pass"
    end
    
    local lower_content = string.lower(content)
    
    for _, pattern in ipairs(config.xss_protection.patterns) do
        if string.match(lower_content, pattern) then
            return "block", pattern
        end
    end
    
    return "pass"
end

-- 路径遍历检查
local function check_path_traversal(uri)
    if not config.path_traversal.enabled then
        return "pass"
    end
    
    local lower_uri = string.lower(uri)
    
    for _, pattern in ipairs(config.path_traversal.patterns) do
        if string.match(lower_uri, pattern) then
            return "block", pattern
        end
    end
    
    return "pass"
end

-- User-Agent检查
local function check_user_agent(user_agent)
    if not config.user_agent.enabled or not user_agent then
        return "pass"
    end
    
    local lower_agent = string.lower(user_agent)
    
    for _, blocked in ipairs(config.user_agent.blocked_agents) do
        if string.match(lower_agent, blocked) then
            return "block", blocked
        end
    end
    
    return "pass"
end

-- 文件扩展名检查
local function check_file_extension(uri)
    if not config.file_extension.enabled then
        return "pass"
    end
    
    local extension = string.match(uri, "%.([^%.]+)$")
    if extension then
        extension = string.lower(extension)
        for _, blocked in ipairs(config.file_extension.blocked_extensions) do
            if extension == blocked then
                return "block", extension
            end
        end
    end
    
    return "pass"
end

-- 执行阻止动作
local function execute_action(reason, details)
    log_event("warn", "Request blocked", {
        reason = reason,
        details = details,
        action = config.action
    })
    
    if config.action == "block" then
        ngx.status = 403
        ngx.say("Access Denied by iWAF")
        ngx.exit(403)
    elseif config.action == "redirect" then
        ngx.redirect("/blocked.html", 302)
    end
    -- 如果是 log 模式，则仅记录日志，不阻止请求
end

-- 主检查函数
function _M.check_request()
    -- 如果WAF未启用，直接通过
    if not config.enabled then
        return
    end
    
    local client_ip = ngx.var.remote_addr
    local request_uri = ngx.var.request_uri
    local user_agent = ngx.var.http_user_agent
    local request_body = ngx.var.request_body
    
    -- IP检查
    local ip_result = check_ip(client_ip)
    if ip_result == "allow" then
        return -- 白名单直接通过
    elseif ip_result == "block" then
        execute_action("IP blocked", {ip = client_ip})
        return
    end
    
    -- 速率限制检查
    local rate_result = check_rate_limit(client_ip)
    if rate_result == "block" then
        execute_action("Rate limit exceeded", {ip = client_ip})
        return
    end
    
    -- 请求大小检查
    local uri_len = string.len(request_uri)
    if uri_len > config.request_limits.max_uri_length then
        execute_action("URI too long", {length = uri_len})
        return
    end
    
    -- User-Agent检查
    local ua_result, ua_pattern = check_user_agent(user_agent)
    if ua_result == "block" then
        execute_action("Malicious User-Agent", {pattern = ua_pattern})
        return
    end
    
    -- 路径遍历检查
    local path_result, path_pattern = check_path_traversal(request_uri)
    if path_result == "block" then
        execute_action("Path traversal attempt", {pattern = path_pattern})
        return
    end
    
    -- 文件扩展名检查
    local ext_result, ext_pattern = check_file_extension(request_uri)
    if ext_result == "block" then
        execute_action("Blocked file extension", {extension = ext_pattern})
        return
    end
    
    -- 组合内容检查（URI + Body）
    local content_to_check = request_uri
    if request_body then
        content_to_check = content_to_check .. " " .. request_body
    end
    
    -- SQL注入检查
    local sql_result, sql_pattern = check_sql_injection(content_to_check)
    if sql_result == "block" then
        execute_action("SQL injection attempt", {pattern = sql_pattern})
        return
    end
    
    -- XSS检查
    local xss_result, xss_pattern = check_xss(content_to_check)
    if xss_result == "block" then
        execute_action("XSS attempt", {pattern = xss_pattern})
        return
    end
    
    -- 如果所有检查都通过，记录正常请求
    log_event("debug", "Request allowed", {})
end

-- 初始化函数
function _M.init()
    -- 创建共享内存字典用于缓存
    if not ngx.shared.iwaf_cache then
        log_event("error", "Shared dictionary 'iwaf_cache' not found")
    end
    
    -- 加载配置
    load_config()
    
    log_event("info", "iWAF initialized successfully", {version = _M._VERSION})
end

-- 获取统计信息
function _M.get_stats()
    local stats = {
        version = _M._VERSION,
        enabled = config.enabled,
        uptime = ngx.now(),
        requests_checked = ngx.shared.iwaf_cache:get("requests_checked") or 0,
        requests_blocked = ngx.shared.iwaf_cache:get("requests_blocked") or 0
    }
    
    return cjson.encode(stats)
end

-- 更新配置
function _M.update_config(new_config)
    config = new_config
    
    -- 保存到文件
    local file = io.open(config_file, "w")
    if file then
        file:write(cjson.encode(config))
        file:close()
        log_event("info", "Configuration updated successfully")
        return true
    else
        log_event("error", "Failed to save configuration")
        return false
    end
end

return _M