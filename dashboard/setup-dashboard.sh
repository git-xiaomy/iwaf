#!/bin/bash

# iWAF Dashboard Setup Script
# This script sets up the separate dashboard on port 8080

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DASHBOARD_DIR="/etc/nginx/iwaf/dashboard"
NGINX_CONF_DIR="/etc/nginx"
WEB_USER="www-data"
WEB_GROUP="www-data"
DASHBOARD_PORT="8080"

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

# Detect nginx installation and configuration directory
detect_nginx() {
    print_status "Detecting Nginx configuration..."
    
    # Check if nginx is installed
    if ! command -v nginx >/dev/null 2>&1; then
        print_error "Nginx is not installed. Please install Nginx first."
        exit 1
    fi
    
    # Detect nginx configuration directory
    if [ -f /usr/local/openresty/nginx/conf/nginx.conf ]; then
        NGINX_CONF_DIR="/usr/local/openresty/nginx/conf"
        WEB_USER="nobody"
        WEB_GROUP="nobody"
        print_status "Detected OpenResty installation"
    elif [ -f /etc/nginx/nginx.conf ]; then
        NGINX_CONF_DIR="/etc/nginx"
        WEB_USER="www-data"
        WEB_GROUP="www-data"
        print_status "Detected standard Nginx installation"
    elif [ -f /usr/local/nginx/conf/nginx.conf ]; then
        NGINX_CONF_DIR="/usr/local/nginx/conf"
        WEB_USER="nginx"
        WEB_GROUP="nginx"
        print_status "Detected custom Nginx installation"
    else
        print_error "Could not detect Nginx configuration directory"
        print_status "Please specify the correct path manually"
        exit 1
    fi
    
    print_success "Using Nginx config directory: $NGINX_CONF_DIR"
    print_success "Using web user: $WEB_USER"
}

# Check for port conflicts
check_port_conflict() {
    print_status "Checking for port conflicts on port $DASHBOARD_PORT..."
    
    # Check if port is already in use by any process
    if netstat -tuln 2>/dev/null | grep -q ":$DASHBOARD_PORT " || \
       ss -tuln 2>/dev/null | grep -q ":$DASHBOARD_PORT "; then
        print_warning "Port $DASHBOARD_PORT is already in use!"
        
        # Show what's using the port
        print_status "Current processes using port $DASHBOARD_PORT:"
        netstat -tulnp 2>/dev/null | grep ":$DASHBOARD_PORT " || \
        ss -tulnp 2>/dev/null | grep ":$DASHBOARD_PORT " || \
        print_status "Unable to determine which process is using the port"
        
        # Check for nginx sites using this port
        if [ -d "$NGINX_CONF_DIR/sites-available" ]; then
            local conflicting_sites=$(grep -l "listen.*$DASHBOARD_PORT" "$NGINX_CONF_DIR"/sites-available/* 2>/dev/null || true)
            if [ -n "$conflicting_sites" ]; then
                print_warning "Found Nginx sites using port $DASHBOARD_PORT:"
                echo "$conflicting_sites"
            fi
        fi
        
        if [ -d "$NGINX_CONF_DIR/conf.d" ]; then
            local conflicting_confs=$(grep -l "listen.*$DASHBOARD_PORT" "$NGINX_CONF_DIR"/conf.d/*.conf 2>/dev/null || true)
            if [ -n "$conflicting_confs" ]; then
                print_warning "Found Nginx configurations using port $DASHBOARD_PORT:"
                echo "$conflicting_confs"
            fi
        fi
        
        echo
        echo "Options to resolve port conflict:"
        echo "1. Use a different port for the dashboard"
        echo "2. Disable the conflicting service/site"
        echo "3. Continue anyway (may cause conflicts)"
        echo
        
        read -p "Choose option (1/2/3): " -n 1 -r
        echo
        case $REPLY in
            1)
                read -p "Enter new port for dashboard (e.g., 9080): " NEW_PORT
                if [[ "$NEW_PORT" =~ ^[0-9]+$ ]] && [ "$NEW_PORT" -gt 1000 ] && [ "$NEW_PORT" -lt 65536 ]; then
                    DASHBOARD_PORT="$NEW_PORT"
                    print_success "Using port $DASHBOARD_PORT for dashboard"
                else
                    print_error "Invalid port number"
                    exit 1
                fi
                ;;
            2)
                print_status "Please disable the conflicting service manually and re-run this script"
                exit 1
                ;;
            3)
                print_warning "Continuing with potential port conflict..."
                ;;
            *)
                print_error "Invalid option"
                exit 1
                ;;
        esac
    else
        print_success "Port $DASHBOARD_PORT is available"
    fi
}

# Create dashboard directories
create_dashboard_directories() {
    print_status "Creating dashboard directories..."
    
    mkdir -p "$DASHBOARD_DIR"/{web,conf}
    
    print_success "Dashboard directories created"
}

# Copy dashboard files
copy_dashboard_files() {
    print_status "Copying dashboard files..."
    
    # Get script directory
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # Copy dashboard web files
    cp -r "$SCRIPT_DIR/web/"* "$DASHBOARD_DIR/web/"
    
    # Copy and modify dashboard configuration with the selected port
    cp "$SCRIPT_DIR/conf/dashboard.conf" "/tmp/dashboard.conf.tmp"
    
    # Replace the port in the configuration file
    sed -i "s/listen 8080;/listen $DASHBOARD_PORT;/g" "/tmp/dashboard.conf.tmp"
    sed -i "s/listen \[::\]:8080;/listen [::]:$DASHBOARD_PORT;/g" "/tmp/dashboard.conf.tmp"
    
    # Copy to appropriate location
    if [ -d "$NGINX_CONF_DIR/sites-available" ]; then
        cp "/tmp/dashboard.conf.tmp" "$NGINX_CONF_DIR/sites-available/iwaf-dashboard"
        print_status "Configuration copied to sites-available"
    else
        cp "/tmp/dashboard.conf.tmp" "$NGINX_CONF_DIR/conf.d/iwaf-dashboard.conf"
        print_status "Configuration copied to conf.d"
    fi
    
    # Cleanup temporary file
    rm -f "/tmp/dashboard.conf.tmp"
    
    print_success "Dashboard files copied with port $DASHBOARD_PORT"
}

# Set permissions for dashboard
set_dashboard_permissions() {
    print_status "Setting dashboard permissions..."
    
    chown -R "$WEB_USER:$WEB_GROUP" "$DASHBOARD_DIR"
    chmod -R 755 "$DASHBOARD_DIR"
    
    print_success "Dashboard permissions set"
}

# Enable dashboard site (for systems using sites-available/sites-enabled)
enable_dashboard_site() {
    if [ -d "$NGINX_CONF_DIR/sites-available" ] && [ -d "$NGINX_CONF_DIR/sites-enabled" ]; then
        print_status "Enabling dashboard site..."
        
        if [ ! -L "$NGINX_CONF_DIR/sites-enabled/iwaf-dashboard" ]; then
            ln -s "$NGINX_CONF_DIR/sites-available/iwaf-dashboard" "$NGINX_CONF_DIR/sites-enabled/iwaf-dashboard"
            print_success "Dashboard site enabled"
        else
            print_warning "Dashboard site already enabled"
        fi
    else
        print_status "Using conf.d configuration (no sites-available/sites-enabled)"
    fi
}

# Test Nginx configuration
test_nginx() {
    print_status "Testing Nginx configuration..."
    
    if nginx -t; then
        print_success "Nginx configuration test passed"
    else
        print_error "Nginx configuration test failed"
        exit 1
    fi
}

# Configure firewall for dashboard port
setup_firewall() {
    read -p "Open firewall for dashboard port $DASHBOARD_PORT? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Configuring firewall for port $DASHBOARD_PORT..."
        
        if command -v ufw > /dev/null; then
            ufw allow $DASHBOARD_PORT/tcp
            print_success "UFW rule added for port $DASHBOARD_PORT"
        elif command -v firewall-cmd > /dev/null; then
            firewall-cmd --permanent --add-port=$DASHBOARD_PORT/tcp
            firewall-cmd --reload
            print_success "Firewalld rule added for port $DASHBOARD_PORT"
        else
            print_warning "No firewall management tool found. Please manually open port $DASHBOARD_PORT."
        fi
    fi
}

# Restart Nginx
restart_nginx() {
    print_status "Restarting Nginx..."
    
    systemctl restart nginx || service nginx restart
    
    if systemctl is-active --quiet nginx || service nginx status > /dev/null 2>&1; then
        print_success "Nginx restarted successfully"
    else
        print_error "Failed to restart Nginx"
        exit 1
    fi
}

# Display completion message
show_completion() {
    print_success "iWAF Dashboard setup completed!"
    echo
    echo -e "${GREEN}=== Dashboard Information ===${NC}"
    echo -e "Dashboard URL: ${YELLOW}http://$(hostname -I | awk '{print $1}'):$DASHBOARD_PORT${NC}"
    echo -e "Dashboard files: ${YELLOW}$DASHBOARD_DIR/web${NC}"
    if [ -d "$NGINX_CONF_DIR/sites-available" ]; then
        echo -e "Dashboard config: ${YELLOW}$NGINX_CONF_DIR/sites-available/iwaf-dashboard${NC}"
    else
        echo -e "Dashboard config: ${YELLOW}$NGINX_CONF_DIR/conf.d/iwaf-dashboard.conf${NC}"
    fi
    echo -e "Dashboard logs: ${YELLOW}/var/log/nginx/iwaf_dashboard_*.log${NC}"
    echo
    echo -e "${BLUE}=== Security Notice ===${NC}"
    echo "Consider restricting access to the dashboard by:"
    echo "1. Uncommenting the IP restrictions in the dashboard configuration"
    echo "2. Using a reverse proxy with authentication"
    echo "3. Setting up VPN access for management"
    echo
    echo -e "${GREEN}Dashboard is now running on port $DASHBOARD_PORT!${NC}"
}

# Main execution
main() {
    echo -e "${BLUE}=== iWAF Dashboard Setup ===${NC}"
    echo
    
    check_root
    detect_nginx
    check_port_conflict
    create_dashboard_directories
    copy_dashboard_files
    set_dashboard_permissions
    enable_dashboard_site
    test_nginx
    setup_firewall
    restart_nginx
    show_completion
}

# Handle script interruption
trap 'print_error "Dashboard setup interrupted"; exit 1' INT TERM

# Run main function
main "$@"