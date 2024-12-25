#!/bin/bash

# 设置脚本文件路径和服务文件路径
SCRIPT_PATH="/root/servertraffic.py"
SERVICE_PATH="/etc/systemd/system/servertraffic.service"
PORT=7122

echo "=== 自动化配置开始 ==="

# 更新系统
echo ">>> 更新系统..."
apt update && apt upgrade -y

# 安装 Python3 和 pip3
echo ">>> 安装 Python3 和 pip3..."
apt install -y python3 python3-pip

# 安装 psutil
echo ">>> 安装 psutil..."
pip3 install psutil --break-system-packages

# 编写 Python 监控脚本
echo ">>> 编写 Python 监控脚本..."
cat > $SCRIPT_PATH << EOF
#!/usr/bin/env python3
import http.server
import socketserver
import json
import time
import psutil

port = $PORT

class RequestHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()

        time.sleep(1)

        cpu_usage = psutil.cpu_percent()
        mem_usage = psutil.virtual_memory().percent
        bytes_sent = psutil.net_io_counters().bytes_sent
        bytes_recv = psutil.net_io_counters().bytes_recv
        bytes_total = bytes_sent + bytes_recv

        utc_timestamp = int(time.time())
        uptime = int(time.time() - psutil.boot_time())
        last_time = time.strftime("%Y/%m/%d %H:%M:%S", time.localtime())

        response_dict = {
            "utc_timestamp": utc_timestamp,
            "uptime": uptime,
            "cpu_usage": cpu_usage,
            "mem_usage": mem_usage,
            "bytes_sent": str(bytes_sent),
            "bytes_recv": str(bytes_recv),
            "bytes_total": str(bytes_total),
            "last_time": last_time
        }

        response_json = json.dumps(response_dict).encode('utf-8')
        self.wfile.write(response_json)

with socketserver.ThreadingTCPServer(("", port), RequestHandler, bind_and_activate=False) as httpd:
    try:
        print(f"Serving at port {port}")
        httpd.allow_reuse_address = True
        httpd.server_bind()
        httpd.server_activate()
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("KeyboardInterrupt is captured, program exited")
EOF

chmod +x $SCRIPT_PATH
echo ">>> Python 监控脚本已创建: $SCRIPT_PATH"

# 创建 systemd 服务
echo ">>> 创建 systemd 服务..."
cat > $SERVICE_PATH << EOF
[Unit]
Description=Server Traffic Monitor

[Service]
Type=simple
WorkingDirectory=/root/
User=root
ExecStart=/usr/bin/python3 /root/servertraffic.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# 重载 systemd 配置
systemctl daemon-reload
echo ">>> systemd 服务配置已创建: $SERVICE_PATH"

# 启动服务并设置开机启动
echo ">>> 启动服务..."
systemctl start servertraffic.service
systemctl enable servertraffic.service

# 检查服务状态
echo ">>> 检查服务状态..."
systemctl status servertraffic.service

# 检查端口开放
echo ">>> 检查端口开放..."
ufw allow $PORT/tcp || echo "防火墙可能未启用，跳过端口开放步骤"

echo "=== 自动化配置完成！ ==="
echo "访问 http://<你的VPS IP>:$PORT 测试服务。"
