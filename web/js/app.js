/**
 * iWAF Web Interface JavaScript
 * Handles all frontend interactions and API communications
 */

// Global variables
let wafConfig = {
    enabled: true,
    ip_whitelist: ['127.0.0.1', '::1'],
    ip_blacklist: ['192.168.1.100'],
    rate_limit: {
        enabled: true,
        requests_per_minute: 120,
        burst: 20
    },
    sql_injection: { enabled: true },
    xss_protection: { enabled: true },
    path_traversal: { enabled: true },
    user_agent: { enabled: true }
};

let stats = {
    total_requests: 1245,
    blocked_requests: 89,
    safe_requests: 1156,
    threat_level: 'low'
};

let logEntries = [
    { timestamp: '2024-09-22 10:30:15', level: 'info', message: 'WAF启动成功' },
    { timestamp: '2024-09-22 10:31:22', level: 'warn', message: '检测到SQL注入尝试', ip: '192.168.1.50' },
    { timestamp: '2024-09-22 10:32:45', level: 'error', message: '阻止恶意请求', ip: '10.0.0.100' },
    { timestamp: '2024-09-22 10:33:12', level: 'info', message: '配置更新成功' },
    { timestamp: '2024-09-22 10:34:33', level: 'debug', message: '处理正常请求', ip: '192.168.1.10' }
];

// DOM elements
const tabContents = document.querySelectorAll('.tab-content');
const navItems = document.querySelectorAll('.nav-item');

// Initialize the application
document.addEventListener('DOMContentLoaded', function() {
    initializeTabs();
    updateDashboard();
    loadConfiguration();
    updateLogs();
    startRealTimeUpdates();
});

// Tab switching functionality
function initializeTabs() {
    navItems.forEach(item => {
        item.addEventListener('click', function() {
            const targetTab = this.getAttribute('data-tab');
            
            // Remove active class from all items
            navItems.forEach(nav => nav.classList.remove('active'));
            tabContents.forEach(content => content.classList.remove('active'));
            
            // Add active class to clicked item and corresponding content
            this.classList.add('active');
            document.getElementById(targetTab).classList.add('active');
        });
    });
}

// Update dashboard statistics
function updateDashboard() {
    document.getElementById('total-requests').textContent = stats.total_requests.toLocaleString();
    document.getElementById('blocked-requests').textContent = stats.blocked_requests.toLocaleString();
    document.getElementById('safe-requests').textContent = stats.safe_requests.toLocaleString();
    document.getElementById('threat-level').textContent = getThreatLevelText(stats.threat_level);
    
    // Update WAF status
    const statusElement = document.getElementById('waf-status');
    if (wafConfig.enabled) {
        statusElement.className = 'status-enabled';
        statusElement.innerHTML = '<i class="fas fa-check-circle"></i> WAF 已启用';
    } else {
        statusElement.className = 'status-disabled';
        statusElement.innerHTML = '<i class="fas fa-times-circle"></i> WAF 已禁用';
    }
    
    // Update charts (simplified version)
    updateRequestChart();
}

function getThreatLevelText(level) {
    const levels = {
        'low': '低',
        'medium': '中',
        'high': '高',
        'critical': '严重'
    };
    return levels[level] || '未知';
}

// Simple chart update (placeholder)
function updateRequestChart() {
    const canvas = document.getElementById('requestChart');
    const ctx = canvas.getContext('2d');
    
    // Clear canvas
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    
    // Draw simple line chart
    ctx.strokeStyle = '#3498db';
    ctx.lineWidth = 2;
    ctx.beginPath();
    
    const data = [20, 35, 25, 45, 30, 55, 40, 65, 50, 70];
    const width = canvas.width;
    const height = canvas.height;
    const stepX = width / (data.length - 1);
    const maxY = Math.max(...data);
    
    data.forEach((value, index) => {
        const x = index * stepX;
        const y = height - (value / maxY) * height * 0.8;
        
        if (index === 0) {
            ctx.moveTo(x, y);
        } else {
            ctx.lineTo(x, y);
        }
    });
    
    ctx.stroke();
    
    // Add points
    ctx.fillStyle = '#3498db';
    data.forEach((value, index) => {
        const x = index * stepX;
        const y = height - (value / maxY) * height * 0.8;
        
        ctx.beginPath();
        ctx.arc(x, y, 3, 0, 2 * Math.PI);
        ctx.fill();
    });
}

// Load and apply configuration
function loadConfiguration() {
    // Security toggles
    document.getElementById('sql-protection').checked = wafConfig.sql_injection.enabled;
    document.getElementById('xss-protection').checked = wafConfig.xss_protection.enabled;
    document.getElementById('path-traversal').checked = wafConfig.path_traversal.enabled;
    document.getElementById('user-agent-filter').checked = wafConfig.user_agent.enabled;
    
    // Rate limiting
    document.getElementById('rate-limit-enabled').checked = wafConfig.rate_limit.enabled;
    document.getElementById('requests-per-minute').value = wafConfig.rate_limit.requests_per_minute;
    document.getElementById('burst-size').value = wafConfig.rate_limit.burst;
    
    // Load IP lists
    updateIPLists();
}

// Update IP filter lists
function updateIPLists() {
    const whitelistContainer = document.getElementById('whitelist-container');
    const blacklistContainer = document.getElementById('blacklist-container');
    
    // Clear containers
    whitelistContainer.innerHTML = '';
    blacklistContainer.innerHTML = '';
    
    // Add whitelist IPs
    wafConfig.ip_whitelist.forEach(ip => {
        const tag = createIPTag(ip, 'whitelist');
        whitelistContainer.appendChild(tag);
    });
    
    // Add blacklist IPs
    wafConfig.ip_blacklist.forEach(ip => {
        const tag = createIPTag(ip, 'blacklist');
        blacklistContainer.appendChild(tag);
    });
}

// Create IP tag element
function createIPTag(ip, type) {
    const tag = document.createElement('div');
    tag.className = `ip-tag ${type}`;
    tag.innerHTML = `
        ${ip}
        <button class="remove-btn" onclick="removeIP('${ip}', '${type}')">
            <i class="fas fa-times"></i>
        </button>
    `;
    return tag;
}

// Add IP to whitelist
function addWhitelistIP() {
    const input = document.getElementById('whitelist-ip');
    const ip = input.value.trim();
    
    if (ip && isValidIP(ip)) {
        if (!wafConfig.ip_whitelist.includes(ip)) {
            wafConfig.ip_whitelist.push(ip);
            updateIPLists();
            input.value = '';
            showNotification('IP已添加到白名单', 'success');
        } else {
            showNotification('IP已存在于白名单中', 'warning');
        }
    } else {
        showNotification('请输入有效的IP地址', 'error');
    }
}

// Add IP to blacklist
function addBlacklistIP() {
    const input = document.getElementById('blacklist-ip');
    const ip = input.value.trim();
    
    if (ip && isValidIP(ip)) {
        if (!wafConfig.ip_blacklist.includes(ip)) {
            wafConfig.ip_blacklist.push(ip);
            updateIPLists();
            input.value = '';
            showNotification('IP已添加到黑名单', 'success');
        } else {
            showNotification('IP已存在于黑名单中', 'warning');
        }
    } else {
        showNotification('请输入有效的IP地址', 'error');
    }
}

// Remove IP from list
function removeIP(ip, type) {
    if (type === 'whitelist') {
        wafConfig.ip_whitelist = wafConfig.ip_whitelist.filter(item => item !== ip);
    } else {
        wafConfig.ip_blacklist = wafConfig.ip_blacklist.filter(item => item !== ip);
    }
    
    updateIPLists();
    showNotification(`IP已从${type === 'whitelist' ? '白' : '黑'}名单中移除`, 'info');
}

// Validate IP address
function isValidIP(ip) {
    const ipv4Regex = /^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/;
    const ipv6Regex = /^(?:[0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}$/;
    return ipv4Regex.test(ip) || ipv6Regex.test(ip) || ip === 'localhost';
}

// Save security configuration
function saveSecurityConfig() {
    wafConfig.sql_injection.enabled = document.getElementById('sql-protection').checked;
    wafConfig.xss_protection.enabled = document.getElementById('xss-protection').checked;
    wafConfig.path_traversal.enabled = document.getElementById('path-traversal').checked;
    wafConfig.user_agent.enabled = document.getElementById('user-agent-filter').checked;
    
    // In a real implementation, this would send data to the server
    showNotification('安全配置已保存', 'success');
    console.log('Security config saved:', wafConfig);
}

// Reset security configuration
function resetSecurityConfig() {
    document.getElementById('sql-protection').checked = true;
    document.getElementById('xss-protection').checked = true;
    document.getElementById('path-traversal').checked = true;
    document.getElementById('user-agent-filter').checked = true;
    
    showNotification('安全配置已重置为默认值', 'info');
}

// Save rate limit configuration
function saveRateLimitConfig() {
    wafConfig.rate_limit.enabled = document.getElementById('rate-limit-enabled').checked;
    wafConfig.rate_limit.requests_per_minute = parseInt(document.getElementById('requests-per-minute').value);
    wafConfig.rate_limit.burst = parseInt(document.getElementById('burst-size').value);
    
    showNotification('速率限制配置已保存', 'success');
    console.log('Rate limit config saved:', wafConfig.rate_limit);
}

// Save system configuration
function saveSystemConfig() {
    const logLevel = document.getElementById('log-level').value;
    const actionMode = document.getElementById('action-mode').value;
    
    // Update configuration
    wafConfig.log_level = logLevel;
    wafConfig.action = actionMode;
    
    showNotification('系统配置已保存', 'success');
    console.log('System config saved:', { log_level: logLevel, action: actionMode });
}

// Restart WAF
function restartWAF() {
    if (confirm('确定要重启WAF吗？这将短暂中断防护功能。')) {
        showNotification('正在重启WAF...', 'info');
        
        // Simulate restart delay
        setTimeout(() => {
            showNotification('WAF重启成功', 'success');
        }, 2000);
    }
}

// Update logs display
function updateLogs() {
    const container = document.getElementById('log-container');
    container.innerHTML = '';
    
    const filterLevel = document.getElementById('log-level-filter')?.value || 'all';
    
    logEntries
        .filter(entry => filterLevel === 'all' || entry.level === filterLevel)
        .forEach(entry => {
            const logElement = document.createElement('div');
            logElement.className = 'log-entry';
            logElement.innerHTML = `
                <span class="log-timestamp">${entry.timestamp}</span>
                <span class="log-level ${entry.level}">${entry.level.toUpperCase()}</span>
                <span class="log-message">${entry.message}</span>
                ${entry.ip ? `<span class="log-ip">[${entry.ip}]</span>` : ''}
            `;
            container.appendChild(logElement);
        });
    
    // Auto-scroll to bottom
    container.scrollTop = container.scrollHeight;
}

// Refresh logs
function refreshLogs() {
    // In a real implementation, this would fetch new logs from server
    const newLogEntry = {
        timestamp: new Date().toLocaleString('zh-CN'),
        level: 'info',
        message: '日志已刷新',
        ip: '192.168.1.1'
    };
    
    logEntries.unshift(newLogEntry);
    
    // Keep only last 100 entries
    if (logEntries.length > 100) {
        logEntries = logEntries.slice(0, 100);
    }
    
    updateLogs();
    showNotification('日志已刷新', 'info');
}

// Clear logs
function clearLogs() {
    if (confirm('确定要清空所有日志吗？')) {
        logEntries.length = 0;
        updateLogs();
        showNotification('日志已清空', 'info');
    }
}

// Show notification
function showNotification(message, type = 'info') {
    // Create notification element
    const notification = document.createElement('div');
    notification.className = `notification notification-${type}`;
    notification.style.cssText = `
        position: fixed;
        top: 20px;
        right: 20px;
        padding: 15px 20px;
        border-radius: 8px;
        color: white;
        font-weight: 500;
        z-index: 1000;
        min-width: 300px;
        box-shadow: 0 4px 12px rgba(0, 0, 0, 0.2);
        animation: slideIn 0.3s ease;
    `;
    
    // Set background color based on type
    const colors = {
        'success': '#27ae60',
        'error': '#e74c3c',
        'warning': '#f39c12',
        'info': '#3498db'
    };
    notification.style.backgroundColor = colors[type] || colors.info;
    
    // Set message
    notification.textContent = message;
    
    // Add to page
    document.body.appendChild(notification);
    
    // Remove after 3 seconds
    setTimeout(() => {
        notification.style.animation = 'slideOut 0.3s ease forwards';
        setTimeout(() => {
            if (notification.parentNode) {
                notification.parentNode.removeChild(notification);
            }
        }, 300);
    }, 3000);
}

// Add CSS animations for notifications
const style = document.createElement('style');
style.textContent = `
    @keyframes slideIn {
        from {
            opacity: 0;
            transform: translateX(100%);
        }
        to {
            opacity: 1;
            transform: translateX(0);
        }
    }
    
    @keyframes slideOut {
        from {
            opacity: 1;
            transform: translateX(0);
        }
        to {
            opacity: 0;
            transform: translateX(100%);
        }
    }
`;
document.head.appendChild(style);

// Start real-time updates
function startRealTimeUpdates() {
    // Update statistics every 30 seconds
    setInterval(() => {
        // Simulate data updates
        stats.total_requests += Math.floor(Math.random() * 10) + 1;
        stats.safe_requests = stats.total_requests - stats.blocked_requests;
        
        // Occasionally add blocked requests
        if (Math.random() < 0.3) {
            stats.blocked_requests += Math.floor(Math.random() * 3) + 1;
            stats.safe_requests = stats.total_requests - stats.blocked_requests;
        }
        
        updateDashboard();
    }, 30000);
    
    // Add new log entries periodically
    setInterval(() => {
        if (Math.random() < 0.4) {
            const logTypes = [
                { level: 'info', message: '正常请求处理' },
                { level: 'warn', message: 'Rate limit达到阈值' },
                { level: 'debug', message: '配置检查完成' }
            ];
            
            const randomLog = logTypes[Math.floor(Math.random() * logTypes.length)];
            const newEntry = {
                timestamp: new Date().toLocaleString('zh-CN'),
                level: randomLog.level,
                message: randomLog.message,
                ip: `192.168.1.${Math.floor(Math.random() * 254) + 1}`
            };
            
            logEntries.unshift(newEntry);
            if (logEntries.length > 100) {
                logEntries.pop();
            }
            
            // Update logs if log tab is active
            const activeTab = document.querySelector('.tab-content.active');
            if (activeTab && activeTab.id === 'logs') {
                updateLogs();
            }
        }
    }, 15000);
}

// Handle log level filter change
document.addEventListener('change', function(e) {
    if (e.target.id === 'log-level-filter') {
        updateLogs();
    }
});

// Add uptime display
function updateUptime() {
    const startTime = new Date().getTime() - (Math.random() * 86400000); // Random uptime up to 24h
    const now = new Date().getTime();
    const uptime = now - startTime;
    
    const hours = Math.floor(uptime / (1000 * 60 * 60));
    const minutes = Math.floor((uptime % (1000 * 60 * 60)) / (1000 * 60));
    
    const uptimeElement = document.getElementById('uptime');
    if (uptimeElement) {
        uptimeElement.textContent = `${hours}小时${minutes}分钟`;
    }
}

// Update uptime every minute
setInterval(updateUptime, 60000);
updateUptime();

// Handle Enter key in IP input fields
document.addEventListener('keypress', function(e) {
    if (e.key === 'Enter') {
        if (e.target.id === 'whitelist-ip') {
            addWhitelistIP();
        } else if (e.target.id === 'blacklist-ip') {
            addBlacklistIP();
        }
    }
});

console.log('iWAF Web Interface initialized successfully');