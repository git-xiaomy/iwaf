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
    
    # Copy dashboard configuration
    cp "$SCRIPT_DIR/conf/dashboard.conf" "$NGINX_CONF_DIR/sites-available/iwaf-dashboard" 2>/dev/null || \
    cp "$SCRIPT_DIR/conf/dashboard.conf" "$NGINX_CONF_DIR/conf.d/iwaf-dashboard.conf"
    
    print_success "Dashboard files copied"
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
    read -p "Open firewall for dashboard port 8080? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Configuring firewall for port 8080..."
        
        if command -v ufw > /dev/null; then
            ufw allow 8080/tcp
            print_success "UFW rule added for port 8080"
        elif command -v firewall-cmd > /dev/null; then
            firewall-cmd --permanent --add-port=8080/tcp
            firewall-cmd --reload
            print_success "Firewalld rule added for port 8080"
        else
            print_warning "No firewall management tool found. Please manually open port 8080."
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
    echo -e "Dashboard URL: ${YELLOW}http://$(hostname -I | awk '{print $1}'):8080${NC}"
    echo -e "Dashboard files: ${YELLOW}$DASHBOARD_DIR/web${NC}"
    echo -e "Dashboard config: ${YELLOW}$NGINX_CONF_DIR/sites-available/iwaf-dashboard${NC}"
    echo -e "Dashboard logs: ${YELLOW}/var/log/nginx/iwaf_dashboard_*.log${NC}"
    echo
    echo -e "${BLUE}=== Security Notice ===${NC}"
    echo "Consider restricting access to the dashboard by:"
    echo "1. Uncommenting the IP restrictions in the dashboard configuration"
    echo "2. Using a reverse proxy with authentication"
    echo "3. Setting up VPN access for management"
    echo
    echo -e "${GREEN}Dashboard is now running on port 8080!${NC}"
}

# Main execution
main() {
    echo -e "${BLUE}=== iWAF Dashboard Setup ===${NC}"
    echo
    
    check_root
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