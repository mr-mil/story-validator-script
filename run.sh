#!/bin/bash

# به‌روزرسانی سیستم و نصب پیش‌نیازها
sudo apt update
sudo apt-get update
sudo apt install curl git make jq build-essential gcc unzip wget lz4 aria2 -y

# دانلود و استخراج Story Geth
wget https://story-geth-binaries.s3.us-west-1.amazonaws.com/geth-public/geth-linux-amd64-0.10.0-afaa40a.tar.gz
tar -xzvf geth-linux-amd64-0.10.0-afaa40a.tar.gz
[ ! -d "$HOME/go/bin" ] && mkdir -p $HOME/go/bin
if ! grep -q "$HOME/go/bin" $HOME/.bash_profile; then
  echo "export PATH=$PATH:/usr/local/go/bin:~/go/bin" >> ~/.bash_profile
fi
sudo cp geth-linux-amd64-0.10.0-afaa40a/geth $HOME/go/bin/story-geth

# بارگذاری مجدد Bash Profile
source $HOME/.bash_profile

# دانلود و استخراج Story
wget https://story-geth-binaries.s3.us-west-1.amazonaws.com/story-public/story-linux-amd64-0.12.0-d2e195c.tar.gz
tar -xzvf story-linux-amd64-0.12.0-d2e195c.tar.gz
[ ! -d "$HOME/go/bin" ] && mkdir -p $HOME/go/bin
if ! grep -q "$HOME/go/bin" $HOME/.bash_profile; then
  echo "export PATH=$PATH:/usr/local/go/bin:~/go/bin" >> ~/.bash_profile
fi
cp $HOME/story-linux-amd64-0.12.0-d2e195c/story $HOME/go/bin

# بارگذاری مجدد Bash Profile
source $HOME/.bash_profile

# دریافت نام Moniker از کاربر
read -p "لطفا نام Moniker خود را وارد کنید: " moniker_name

# مقداردهی اولیه Story
story init --network iliad --moniker "$moniker_name"

# ایجاد سرویس story-geth
sudo tee /etc/systemd/system/story-geth.service > /dev/null <<EOF
[Unit]
Description=Story Geth Client
After=network.target

[Service]
User=root
ExecStart=/root/go/bin/story-geth --iliad --syncmode full
Restart=on-failure
RestartSec=3
LimitNOFILE=4096

[Install]
WantedBy=multi-user.target
EOF

# ایجاد سرویس story
sudo tee /etc/systemd/system/story.service > /dev/null <<EOF
[Unit]
Description=Story Consensus Client
After=network.target

[Service]
User=root
ExecStart=/root/go/bin/story run
Restart=on-failure
RestartSec=3
LimitNOFILE=4096

[Install]
WantedBy=multi-user.target
EOF

# پیکربندی peers
PEERS=$(curl -sS https://story-rpc.mandragora.io/net_info | jq -r '.result.peers[] | "\(.node_info.id)@\(.remote_ip):\(.node_info.listen_addr)"' | awk -F ':' '{print $1":"$(NF)}' | paste -sd, -)
sed -i.bak -e "s/^persistent_peers *=.*/persistent_peers = \"$PEERS\"/" $HOME/.story/story/config/config.toml
systemctl restart story

# پیکربندی seeds
SEEDS=b6fb541c80d968931602710342dedfe1f5c577e3@story-seed.mandragora.io:23656,51ff395354c13fab493a03268249a74860b5f9cc@story-testnet-seed.itrocket.net:26656,5d7507dbb0e04150f800297eaba39c5161c034fe@135.125.188.77:26656
sed -i.bak -e "s/^seeds *=.*/seeds = \"$SEEDS\"/" $HOME/.story/story/config/config.toml

# دانلود فایل addrbook
wget -O $HOME/.story/story/config/addrbook.json https://snapshots.mandragora.io/addrbook.json

# راه‌اندازی و فعال‌سازی سرویس‌ها
sudo systemctl daemon-reload && \
sudo systemctl start story-geth && \
sudo systemctl enable story-geth

sudo systemctl daemon-reload && \
sudo systemctl start story && \
sudo systemctl enable story
