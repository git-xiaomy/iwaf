-- Configuration validation module for iWAF
local _M = {}

-- Validate IP address format
local function validate_ip(ip)
    if type(ip) ~= "string" then
        return false, "IP must be a string"
    end
    
    -- IPv4 validation
    local ipv4_pattern = "^(%d+)%.(%d+)%.(%d+)%.(%d+)$"
    local a, b, c, d = ip:match(ipv4_pattern)
    if a then
        a, b, c, d = tonumber(a), tonumber(b), tonumber(c), tonumber(d)
        if a and b and c and d and a <= 255 and b <= 255 and c <= 255 and d <= 255 then
            return true
        end
    end
    
    -- IPv6 basic validation (simplified)
    if ip:match("^[0-9a-fA-F:]+$") and ip:find(":") then
        return true
    end
    
    -- Special cases
    if ip == "localhost" or ip == "::1" then
        return true
    end
    
    return false, "Invalid IP address format"
end

-- Validate configuration structure
function _M.validate_config(config)
    if type(config) ~= "table" then
        return false, "Configuration must be a table"
    end
    
    -- Validate basic settings
    if config.enabled ~= nil and type(config.enabled) ~= "boolean" then
        return false, "enabled must be a boolean"
    end
    
    if config.log_level and type(config.log_level) ~= "string" then
        return false, "log_level must be a string"
    end
    
    if config.action and not (config.action == "block" or config.action == "log" or config.action == "redirect") then
        return false, "action must be 'block', 'log', or 'redirect'"
    end
    
    -- Validate IP lists
    if config.ip_whitelist then
        if type(config.ip_whitelist) ~= "table" then
            return false, "ip_whitelist must be an array"
        end
        for i, ip in ipairs(config.ip_whitelist) do
            local valid, err = validate_ip(ip)
            if not valid then
                return false, "Invalid IP in whitelist at position " .. i .. ": " .. (err or "")
            end
        end
    end
    
    if config.ip_blacklist then
        if type(config.ip_blacklist) ~= "table" then
            return false, "ip_blacklist must be an array"
        end
        for i, ip in ipairs(config.ip_blacklist) do
            local valid, err = validate_ip(ip)
            if not valid then
                return false, "Invalid IP in blacklist at position " .. i .. ": " .. (err or "")
            end
        end
    end
    
    -- Validate rate limit settings
    if config.rate_limit then
        if type(config.rate_limit) ~= "table" then
            return false, "rate_limit must be a table"
        end
        
        if config.rate_limit.enabled ~= nil and type(config.rate_limit.enabled) ~= "boolean" then
            return false, "rate_limit.enabled must be a boolean"
        end
        
        if config.rate_limit.requests_per_minute then
            local rpm = config.rate_limit.requests_per_minute
            if type(rpm) ~= "number" or rpm < 1 or rpm > 10000 then
                return false, "rate_limit.requests_per_minute must be between 1 and 10000"
            end
        end
        
        if config.rate_limit.burst then
            local burst = config.rate_limit.burst
            if type(burst) ~= "number" or burst < 1 or burst > 1000 then
                return false, "rate_limit.burst must be between 1 and 1000"
            end
        end
    end
    
    -- Validate request limits
    if config.request_limits then
        local limits = config.request_limits
        if type(limits) ~= "table" then
            return false, "request_limits must be a table"
        end
        
        if limits.max_body_size and (type(limits.max_body_size) ~= "number" or limits.max_body_size < 1) then
            return false, "request_limits.max_body_size must be a positive number"
        end
        
        if limits.max_uri_length and (type(limits.max_uri_length) ~= "number" or limits.max_uri_length < 1) then
            return false, "request_limits.max_uri_length must be a positive number"
        end
        
        if limits.max_header_size and (type(limits.max_header_size) ~= "number" or limits.max_header_size < 1) then
            return false, "request_limits.max_header_size must be a positive number"
        end
    end
    
    -- Validate protection modules
    local protection_modules = {"sql_injection", "xss_protection", "path_traversal", "user_agent", "file_extension"}
    for _, module in ipairs(protection_modules) do
        if config[module] then
            if type(config[module]) ~= "table" then
                return false, module .. " must be a table"
            end
            
            if config[module].enabled ~= nil and type(config[module].enabled) ~= "boolean" then
                return false, module .. ".enabled must be a boolean"
            end
            
            if config[module].patterns and type(config[module].patterns) ~= "table" then
                return false, module .. ".patterns must be an array"
            end
        end
    end
    
    return true
end

-- Sanitize and normalize configuration
function _M.sanitize_config(config)
    local sanitized = {}
    
    -- Copy basic settings with defaults
    sanitized.enabled = config.enabled ~= false
    sanitized.log_level = config.log_level or "info"
    sanitized.action = config.action or "block"
    
    -- Copy and validate IP lists
    sanitized.ip_whitelist = {}
    if config.ip_whitelist and type(config.ip_whitelist) == "table" then
        for _, ip in ipairs(config.ip_whitelist) do
            if validate_ip(ip) then
                table.insert(sanitized.ip_whitelist, ip)
            end
        end
    end
    
    sanitized.ip_blacklist = {}
    if config.ip_blacklist and type(config.ip_blacklist) == "table" then
        for _, ip in ipairs(config.ip_blacklist) do
            if validate_ip(ip) then
                table.insert(sanitized.ip_blacklist, ip)
            end
        end
    end
    
    -- Copy rate limiting settings
    sanitized.rate_limit = {
        enabled = true,
        requests_per_minute = 120,
        burst = 20
    }
    if config.rate_limit and type(config.rate_limit) == "table" then
        if config.rate_limit.enabled ~= nil then
            sanitized.rate_limit.enabled = config.rate_limit.enabled
        end
        if config.rate_limit.requests_per_minute then
            local rpm = tonumber(config.rate_limit.requests_per_minute)
            if rpm and rpm >= 1 and rpm <= 10000 then
                sanitized.rate_limit.requests_per_minute = rpm
            end
        end
        if config.rate_limit.burst then
            local burst = tonumber(config.rate_limit.burst)
            if burst and burst >= 1 and burst <= 1000 then
                sanitized.rate_limit.burst = burst
            end
        end
    end
    
    -- Copy protection modules
    local protection_modules = {"sql_injection", "xss_protection", "path_traversal", "user_agent", "file_extension"}
    for _, module in ipairs(protection_modules) do
        if config[module] and type(config[module]) == "table" then
            sanitized[module] = {
                enabled = config[module].enabled ~= false
            }
            if config[module].patterns and type(config[module].patterns) == "table" then
                sanitized[module].patterns = {}
                for _, pattern in ipairs(config[module].patterns) do
                    if type(pattern) == "string" and #pattern > 0 then
                        table.insert(sanitized[module].patterns, pattern)
                    end
                end
            end
        else
            sanitized[module] = { enabled = true }
        end
    end
    
    -- Copy request limits
    sanitized.request_limits = {
        max_body_size = 10485760,
        max_uri_length = 2048,
        max_header_size = 8192
    }
    if config.request_limits and type(config.request_limits) == "table" then
        local limits = config.request_limits
        if limits.max_body_size and type(limits.max_body_size) == "number" and limits.max_body_size > 0 then
            sanitized.request_limits.max_body_size = limits.max_body_size
        end
        if limits.max_uri_length and type(limits.max_uri_length) == "number" and limits.max_uri_length > 0 then
            sanitized.request_limits.max_uri_length = limits.max_uri_length
        end
        if limits.max_header_size and type(limits.max_header_size) == "number" and limits.max_header_size > 0 then
            sanitized.request_limits.max_header_size = limits.max_header_size
        end
    end
    
    return sanitized
end

return _M