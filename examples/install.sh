# iWAF Installation Example for Ubuntu/Debian

# Install required packages
apt-get update
apt-get install -y nginx nginx-module-lua lua-cjson lua-resty-redis lua-resty-mysql

# Create iWAF directories
mkdir -p /etc/nginx/iwaf/{lua/iwaf,web,logs}

# Copy iWAF files
cp -r lua/ /etc/nginx/iwaf/
cp -r web/ /etc/nginx/iwaf/
cp conf/config.json /etc/nginx/iwaf/
cp conf/iwaf.conf /etc/nginx/conf.d/

# Set proper permissions
chown -R www-data:www-data /etc/nginx/iwaf/
chmod -R 755 /etc/nginx/iwaf/
chmod 644 /etc/nginx/iwaf/config.json

# Load Lua module in nginx.conf
echo "load_module modules/ngx_http_lua_module.so;" >> /etc/nginx/nginx.conf

# Test configuration
nginx -t

# Restart Nginx
systemctl restart nginx

# Create log rotation
cat > /etc/logrotate.d/iwaf << EOF
/var/log/nginx/iwaf_*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 www-data www-data
    postrotate
        systemctl reload nginx
    endscript
}
EOF

echo "iWAF installation completed!"
echo "Access the web interface at: http://your-server/iwaf/"