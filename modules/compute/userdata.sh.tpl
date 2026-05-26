#!/bin/bash
set -euxo pipefail

# Log user data execution
exec > >(tee /var/log/user-data.log) 2>&1
echo "=== User Data Script Started at $(date) ==="

# Update system
dnf update -y

# -----------------------------------------------------------------------------
# Install Node.js 20 LTS
# -----------------------------------------------------------------------------
dnf install -y nodejs20 npm
node --version
npm --version

# Install PM2 globally
npm install -g pm2

# -----------------------------------------------------------------------------
# Install CloudWatch Agent
# -----------------------------------------------------------------------------
dnf install -y amazon-cloudwatch-agent

# Configure CloudWatch Agent from SSM Parameter
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -s \
  -c ssm:${cw_agent_config_param}

# -----------------------------------------------------------------------------
# Install CodeDeploy Agent
# -----------------------------------------------------------------------------
dnf install -y ruby wget
REGION=$(ec2-metadata --availability-zone | cut -d' ' -f2 | sed 's/.$//')
wget "https://aws-codedeploy-$${REGION}.s3.$${REGION}.amazonaws.com/latest/install" -O /tmp/codedeploy-install
chmod +x /tmp/codedeploy-install
/tmp/codedeploy-install auto

# -----------------------------------------------------------------------------
# Setup Application
# -----------------------------------------------------------------------------
# Create app user
useradd -r -m -s /bin/false appuser || true

# Create app directory
mkdir -p /opt/app/logs
chown -R appuser:appuser /opt/app

# Pull app from S3 if bucket is specified
%{ if app_s3_bucket != "" }
aws s3 cp s3://${app_s3_bucket}/app.tar.gz /tmp/app.tar.gz
tar -xzf /tmp/app.tar.gz -C /opt/app
cd /opt/app && npm install --production
chown -R appuser:appuser /opt/app
%{ else }
# Create a placeholder health check app
cat > /opt/app/server.js << 'APPEOF'
const http = require('http');
const port = process.env.PORT || ${app_port};

const server = http.createServer((req, res) => {
  if (req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'healthy', timestamp: new Date().toISOString() }));
  } else {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ message: 'Node.js API running', version: '1.0.0' }));
  }
});

server.listen(port, () => {
  console.log(`Server running on port $${port}`);
});
APPEOF
chown -R appuser:appuser /opt/app
%{ endif }

# -----------------------------------------------------------------------------
# Create systemd service
# -----------------------------------------------------------------------------
cat > /etc/systemd/system/nodejs-app.service << 'SVCEOF'
[Unit]
Description=Node.js Application
After=network.target

[Service]
Type=simple
User=appuser
WorkingDirectory=/opt/app
ExecStart=/usr/bin/node /opt/app/server.js
Restart=always
RestartSec=10
Environment=NODE_ENV=${node_env}
Environment=PORT=${app_port}
StandardOutput=append:/opt/app/logs/app.log
StandardError=append:/opt/app/logs/error.log

[Install]
WantedBy=multi-user.target
SVCEOF

systemctl daemon-reload
systemctl enable nodejs-app
systemctl start nodejs-app

echo "=== User Data Script Completed at $(date) ==="
