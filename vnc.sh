#!/bin/bash

# =======================
# Konfigurasi Awal
# =======================
VNC_USER="riyan"
VNC_PASS="saputra"
NGROK_TOKEN="1rhrziKSSbVXG9AqYLBvQFwD1CL_538mPmakKPzrn2jiYHRWX"

# =======================
# Update & Install Paket
# =======================
echo "🛠️ Update dan install paket-paket dasar..."
apt update -y && apt install -y xfce4 xfce4-goodies tightvncserver dbus-x11 wget unzip curl jq sudo lsb-release gnupg2 software-properties-common firefox

# Install Google Chrome
echo "🌍 Install Google Chrome..."
wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list
apt update -y && apt install -y google-chrome-stable

# =======================
# Setup User untuk VNC
# =======================
echo "👤 Membuat user baru untuk VNC..."
id -u $VNC_USER &>/dev/null || useradd -m -G sudo $VNC_USER
echo "$VNC_USER:$VNC_PASS" | chpasswd

# =======================
# Setup VNC Server
# =======================
echo "🔧 Setup konfigurasi VNC Server..."
VNC_DIR="/home/$VNC_USER/.vnc"
mkdir -p $VNC_DIR
cat > $VNC_DIR/xstartup <<EOF
#!/bin/bash
xrdb \$HOME/.Xresources
startxfce4 &
EOF
chmod +x $VNC_DIR/xstartup
chown -R $VNC_USER:$VNC_USER $VNC_DIR

echo "🔑 Set password VNC..."
su - $VNC_USER -c "mkdir -p ~/.vnc && echo $VNC_PASS | vncpasswd -f > ~/.vnc/passwd && chmod 600 ~/.vnc/passwd"

# =======================
# Install Ngrok Resmi
# =======================
echo "🚀 Install Ngrok resmi dari repo..."
curl -sSL https://ngrok-agent.s3.amazonaws.com/ngrok.asc | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | sudo tee /etc/apt/sources.list.d/ngrok.list
apt update -y
apt install -y ngrok

echo "🔑 Login ke Ngrok..."
ngrok config add-authtoken $NGROK_TOKEN

# =======================
# Setup systemd untuk VNC
# =======================
echo "🛠️ Setup systemd untuk VNC Server..."
cat > /etc/systemd/system/vncserver@.service <<EOF
[Unit]
Description=Start TightVNC server at startup for %i
After=syslog.target network.target

[Service]
Type=forking
User=%i
PAMName=login
PIDFile=/home/%i/.vnc/%H:1.pid
ExecStartPre=-/usr/bin/vncserver -kill :1
ExecStart=/usr/bin/vncserver :1 -geometry 1280x720 -depth 24
ExecStop=/usr/bin/vncserver -kill :1

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable vncserver@$VNC_USER
systemctl start vncserver@$VNC_USER

# =======================
# Setup systemd untuk Ngrok
# =======================
echo "🛠️ Setup systemd untuk Ngrok Tunnel..."
cat > /etc/systemd/system/ngrok-vnc.service <<EOF
[Unit]
Description=Ngrok TCP Tunnel for VNC
After=network.target vncserver@$VNC_USER.service

[Service]
ExecStart=/usr/bin/ngrok tcp 5901
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable ngrok-vnc
systemctl start ngrok-vnc

# =======================
# Done!
# =======================
echo ""
echo "✅ Semua selesai!"
echo "============================================"
echo "Username VNC: $VNC_USER"
echo "Password VNC: $VNC_PASS"
echo "Desktop XFCE + Browser Chrome & Firefox tersedia."
echo "Ngrok TCP Tunnel akan aktif otomatis setelah VPS hidup."
echo "Untuk melihat URL Ngrok:"
echo "    curl -s http://127.0.0.1:4040/api/tunnels | jq -r '.tunnels[0].public_url'"
echo "============================================"
