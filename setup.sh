#!/bin/bash

# iWAF Setup Script
# This script automates the installation and configuration of iWAF

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
IWAF_DIR="/etc/nginx/iwaf"
NGINX_CONF_DIR="/etc/nginx"
WEB_USER="www-data"
WEB_GROUP="www-data"

# Print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root"
        exit 1
    fi
}

# Detect OS and package manager
detect_os() {
    if [ -f /etc/debian_version ]; then
        OS="debian"
        PKG_MANAGER="apt-get"
    elif [ -f /etc/redhat-release ]; then
        OS="redhat"
        PKG_MANAGER="yum"
    else
        print_error "Unsupported operating system"
        exit 1
    fi
    print_status "Detected OS: $OS"
}

# Detect existing nginx installation and set paths accordingly
detect_nginx_installation() {
    print_status "Detecting existing Nginx installation..."
    
    # Check if nginx is already installed
    if command -v nginx >/dev/null 2>&1; then
        print_status "Found existing Nginx installation"
        
        # Detect nginx configuration directory
        if [ -f /www/server/nginx/conf/nginx.conf ]; then
            NGINX_CONF_DIR="/www/server/nginx/conf"
            IWAF_DIR="/www/server/nginx/iwaf"
            WEB_USER="www"
            WEB_GROUP="www"
            print_status "Detected Baota Panel Nginx installation"
            return 0
        elif [ -f /usr/local/openresty/nginx/conf/nginx.conf ]; then
            NGINX_CONF_DIR="/usr/local/openresty/nginx/conf"
            WEB_USER="nobody"
            WEB_GROUP="nobody"
            print_status "Detected OpenResty installation"
            return 0
        elif [ -f /etc/nginx/nginx.conf ]; then
            NGINX_CONF_DIR="/etc/nginx"
            WEB_USER="www-data"
            WEB_GROUP="www-data"
            print_status "Detected standard Nginx installation"
            return 0
        elif [ -f /usr/local/nginx/conf/nginx.conf ]; then
            NGINX_CONF_DIR="/usr/local/nginx/conf"
            WEB_USER="nginx"
            WEB_GROUP="nginx"
            print_status "Detected custom Nginx installation"
            return 0
        else
            print_warning "Nginx is installed but configuration directory not found"
            print_status "Will proceed with installation and use default paths"
        fi
    else
        print_status "Nginx not detected, will install Nginx"
    fi
    
    # Set default paths for new installation
    if [ "$OS" = "debian" ]; then
        NGINX_CONF_DIR="/etc/nginx"
        WEB_USER="www-data"
        WEB_GROUP="www-data"
    else
        NGINX_CONF_DIR="/etc/nginx"
        WEB_USER="nginx"
        WEB_GROUP="nginx"
    fi
}

# Install required packages
install_packages() {
    print_status "Installing required packages..."
    
    if [ "$OS" = "debian" ]; then
        $PKG_MANAGER update
        $PKG_MANAGER install -y nginx nginx-module-lua lua-cjson
        
        # 尝试安装额外的 Lua 库 (可选，当前版本未使用)
        # Try to install additional Lua libraries (optional, not used in current version)
        print_status "Installing optional Lua libraries (for future features)..."
        $PKG_MANAGER install -y lua-resty-redis lua-resty-mysql || {
            print_warning "Optional libraries installation failed, but this won't affect WAF functionality"
        }
        
    elif [ "$OS" = "redhat" ]; then
        $PKG_MANAGER install -y epel-release
        $PKG_MANAGER install -y nginx nginx-module-lua lua-cjson
        
        # Try to install OpenResty as alternative
        if ! nginx -V 2>&1 | grep -q "lua"; then
            print_warning "Nginx Lua module not found. Consider installing OpenResty."
            read -p "Install OpenResty instead? (y/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                install_openresty
                return
            fi
        fi
    fi
    
    print_success "Packages installed successfully"
}

# Install OpenResty (alternative to Nginx + Lua)
install_openresty() {
    print_status "Installing OpenResty..."
    
    if [ "$OS" = "debian" ]; then
        wget -qO - https://openresty.org/package/pubkey.gpg | apt-key add -
        echo "deb http://openresty.org/package/ubuntu $(lsb_release -sc) main" > /etc/apt/sources.list.d/openresty.list
        apt-get update
        apt-get install -y openresty
        NGINX_CONF_DIR="/usr/local/openresty/nginx/conf"
        WEB_USER="nobody"
        WEB_GROUP="nobody"
    elif [ "$OS" = "redhat" ]; then
        yum install -y yum-utils
        yum-config-manager --add-repo https://openresty.org/package/centos/openresty.repo
        yum install -y openresty
        NGINX_CONF_DIR="/usr/local/openresty/nginx/conf"
        WEB_USER="nobody"
        WEB_GROUP="nobody"
    fi
    
    print_success "OpenResty installed successfully"
}

# Check Nginx Lua support
check_nginx_lua() {
    print_status "Checking Nginx Lua support..."
    
    if nginx -V 2>&1 | grep -q "lua"; then
        print_success "Nginx has Lua support"
    else
        print_error "Nginx does not have Lua support"
        print_status "Please install nginx-module-lua or OpenResty"
        exit 1
    fi
}

# Create directories
create_directories() {
    print_status "Creating iWAF directories..."
    
    mkdir -p "$IWAF_DIR"/{lua/iwaf,web/{css,js,images},logs}
    
    print_success "Directories created successfully"
}

# Copy files
copy_files() {
    print_status "Copying iWAF files..."
    
    # Get script directory
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
    
    # Copy Lua files
    cp -r "$PROJECT_DIR/lua/"* "$IWAF_DIR/lua/"
    
    # Copy blocked page to dashboard web directory (for error pages)
    mkdir -p "$IWAF_DIR/dashboard/web"
    cp "$PROJECT_DIR/web/blocked.html" "$IWAF_DIR/dashboard/web/"
    
    # Copy configuration
    cp "$PROJECT_DIR/conf/config.json" "$IWAF_DIR/"
    cp "$PROJECT_DIR/conf/iwaf.conf" "$NGINX_CONF_DIR/conf.d/"
    
    print_success "Files copied successfully"
    print_warning "Dashboard not installed. Use 'dashboard/setup-dashboard.sh' to install separately."
}

# Set permissions
set_permissions() {
    print_status "Setting file permissions..."
    
    chown -R "$WEB_USER:$WEB_GROUP" "$IWAF_DIR"
    chmod -R 755 "$IWAF_DIR"
    chmod 644 "$IWAF_DIR/config.json"
    chmod 644 "$NGINX_CONF_DIR/conf.d/iwaf.conf"
    
    print_success "Permissions set successfully"
}

# Configure Nginx
configure_nginx() {
    print_status "Configuring Nginx..."
    
    # Backup original nginx.conf
    cp "$NGINX_CONF_DIR/nginx.conf" "$NGINX_CONF_DIR/nginx.conf.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Check if Lua module is already loaded
    if ! grep -q "load_module.*lua" "$NGINX_CONF_DIR/nginx.conf"; then
        # Add Lua module loading
        sed -i '1i load_module modules/ngx_http_lua_module.so;' "$NGINX_CONF_DIR/nginx.conf"
    fi
    
    # Add shared dictionary if not present
    if ! grep -q "lua_shared_dict iwaf_cache" "$NGINX_CONF_DIR/nginx.conf"; then
        sed -i '/http {/a \    lua_shared_dict iwaf_cache 10m;' "$NGINX_CONF_DIR/nginx.conf"
    fi
    
    # Add Lua package path
    if ! grep -q "lua_package_path.*iwaf" "$NGINX_CONF_DIR/nginx.conf"; then
        sed -i "/http {/a \    lua_package_path \"$IWAF_DIR/lua/?.lua;$IWAF_DIR/lua/iwaf/?.lua;;\";" "$NGINX_CONF_DIR/nginx.conf"
    fi
    
    # Add init block
    if ! grep -q "init_by_lua_block" "$NGINX_CONF_DIR/nginx.conf"; then
        cat >> "$NGINX_CONF_DIR/nginx.conf" << EOF

    # iWAF initialization
    init_by_lua_block {
        local iwaf = require "waf"
        iwaf.init()
    }
EOF
    fi
    
    print_success "Nginx configuration updated"
}

# Test Nginx configuration
test_nginx() {
    print_status "Testing Nginx configuration..."
    
    if nginx -t; then
        print_success "Nginx configuration test passed"
    else
        print_error "Nginx configuration test failed"
        print_status "Restoring backup configuration..."
        cp "$NGINX_CONF_DIR/nginx.conf.backup."* "$NGINX_CONF_DIR/nginx.conf"
        exit 1
    fi
}

# Create log rotation
setup_logrotate() {
    print_status "Setting up log rotation..."
    
    cat > /etc/logrotate.d/iwaf << EOF
/var/log/nginx/iwaf_*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 $WEB_USER $WEB_GROUP
    postrotate
        systemctl reload nginx || service nginx reload
    endscript
}
EOF
    
    print_success "Log rotation configured"
}

# Start services
start_services() {
    print_status "Starting/restarting Nginx..."
    
    systemctl enable nginx || chkconfig nginx on
    systemctl restart nginx || service nginx restart
    
    if systemctl is-active --quiet nginx || service nginx status > /dev/null 2>&1; then
        print_success "Nginx started successfully"
    else
        print_error "Failed to start Nginx"
        exit 1
    fi
}

# Create firewall rules (optional)
setup_firewall() {
    read -p "Configure firewall rules? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Configuring firewall..."
        
        if command -v ufw > /dev/null; then
            ufw allow 80/tcp
            ufw allow 443/tcp
            print_success "UFW rules added"
        elif command -v firewall-cmd > /dev/null; then
            firewall-cmd --permanent --add-service=http
            firewall-cmd --permanent --add-service=https
            firewall-cmd --reload
            print_success "Firewalld rules added"
        else
            print_warning "No firewall management tool found"
        fi
    fi
}

# Display final information
show_completion() {
    print_success "iWAF installation completed!"
    echo
    echo -e "${GREEN}=== Installation Summary ===${NC}"
    echo -e "Installation directory: ${YELLOW}$IWAF_DIR${NC}"
    echo -e "Configuration file: ${YELLOW}$IWAF_DIR/config.json${NC}"
    echo -e "Nginx config directory: ${YELLOW}$NGINX_CONF_DIR${NC}"
    echo -e "Nginx config file: ${YELLOW}$NGINX_CONF_DIR/conf.d/iwaf.conf${NC}"
    echo -e "Web user: ${YELLOW}$WEB_USER${NC}"
    echo
    echo -e "${BLUE}=== Dashboard Installation ===${NC}"
    echo -e "Dashboard is NOT installed by default."
    echo -e "To install the dashboard on port 8080, run:"
    echo -e "${YELLOW}cd dashboard && sudo ./setup-dashboard.sh${NC}"
    echo
    echo -e "${BLUE}=== Next Steps ===${NC}"
    echo "1. Install dashboard separately if needed"
    echo "2. Review and customize the configuration file"
    echo "3. Monitor the logs: /var/log/nginx/iwaf_*.log"
    echo "4. Test the WAF functionality"
    echo
    echo -e "${GREEN}Thank you for using iWAF!${NC}"
}

# Main execution
main() {
    echo -e "${BLUE}=== iWAF Installation Script ===${NC}"
    echo
    
    check_root
    detect_os
    detect_nginx_installation
    install_packages
    check_nginx_lua
    create_directories
    copy_files
    set_permissions
    configure_nginx
    test_nginx
    setup_logrotate
    start_services
    setup_firewall
    show_completion
}

# Handle script interruption
trap 'print_error "Installation interrupted"; exit 1' INT TERM

# Run main function
main "$@"