#!/bin/bash

while true; do
  # Display welcome message and user options
  echo "Welcome to the Story Validator installation script!"
  echo "Please select one of the following options:"
  echo "1) Install and setup validator node"
  echo "2) Display logs"
  echo "3) Update using the latest snapshot"

  read -p "Enter the number of your choice: " user_choice

  case $user_choice in
    1)
      # Update the system and install prerequisites
      sudo apt update
      sudo apt-get update
      sudo apt install curl git make jq build-essential gcc unzip wget lz4 aria2 -y

      # Download and extract Story Geth
      wget https://story-geth-binaries.s3.us-west-1.amazonaws.com/geth-public/geth-linux-amd64-0.10.0-afaa40a.tar.gz
      tar -xzvf geth-linux-amd64-0.10.0-afaa40a.tar.gz
      [ ! -d "$HOME/go/bin" ] && mkdir -p $HOME/go/bin
      if ! grep -q "$HOME/go/bin" $HOME/.bash_profile; then
        echo "export PATH=$PATH:/usr/local/go/bin:~/go/bin" >> ~/.bash_profile
      fi
      sudo cp geth-linux-amd64-0.10.0-afaa40a/geth $HOME/go/bin/story-geth

      # Reload Bash Profile
      source $HOME/.bash_profile

      # Download and extract Story
      wget https://story-geth-binaries.s3.us-west-1.amazonaws.com/story-public/story-linux-amd64-0.12.0-d2e195c.tar.gz
      tar -xzvf story-linux-amd64-0.12.0-d2e195c.tar.gz
      [ ! -d "$HOME/go/bin" ] && mkdir -p $HOME/go/bin
      if ! grep -q "$HOME/go/bin" $HOME/.bash_profile; then
        echo "export PATH=$PATH:/usr/local/go/bin:~/go/bin" >> ~/.bash_profile
      fi
      cp $HOME/story-linux-amd64-0.12.0-d2e195c/story $HOME/go/bin

      # Reload Bash Profile
      source $HOME/.bash_profile

      # Get Moniker name from user
      read -p "Please enter your Moniker name: " moniker_name

      # Initialize Story
      $HOME/go/bin/story init --network iliad --moniker "$moniker_name"

      # Create story-geth service
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

      # Create story service
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

      # Configure peers
      PEERS=$(curl -sS https://story-rpc.mandragora.io/net_info | jq -r '.result.peers[] | "\(.node_info.id)@\(.remote_ip):\(.node_info.listen_addr)"' | awk -F ':' '{print $1":"$(NF)}' | paste -sd, -)
      sed -i.bak -e "s/^persistent_peers *=.*/persistent_peers = \"$PEERS\"/" $HOME/.story/story/config/config.toml
      systemctl restart story

      # Configure seeds
      SEEDS=b6fb541c80d968931602710342dedfe1f5c577e3@story-seed.mandragora.io:23656,51ff395354c13fab493a03268249a74860b5f9cc@story-testnet-seed.itrocket.net:26656,5d7507dbb0e04150f800297eaba39c5161c034fe@135.125.188.77:26656
      sed -i.bak -e "s/^seeds *=.*/seeds = \"$SEEDS\"/" $HOME/.story/story/config/config.toml

      # Download addrbook file
      wget -O $HOME/.story/story/config/addrbook.json https://snapshots.mandragora.io/addrbook.json

      # Start and enable services
      sudo systemctl daemon-reload && \
      sudo systemctl start story-geth && \
      sudo systemctl enable story-geth

      sudo systemctl daemon-reload && \
      sudo systemctl start story && \
      sudo systemctl enable story
      ;;
    2)
      # Display logs
      curl localhost:26657/status | jq
      ;;
    3)
      # Check if installation has been completed
      if [ ! -d "$HOME/.story" ]; then
        echo "The node has not been installed yet. Please run option 1 to install the node first."
        continue
      fi

      # Stop your story-geth and story nodes
      sudo systemctl stop story-geth
      sudo systemctl stop story

      # Back up your validator state
      sudo cp $HOME/.story/story/data/priv_validator_state.json $HOME/.story/priv_validator_state.json.backup

      # Delete previous geth chaindata and story data folders
      sudo rm -rf $HOME/.story/geth/iliad/geth/chaindata
      sudo rm -rf $HOME/.story/story/data

      # Download story-geth and story snapshots
      wget -O geth_snapshot.lz4 https://snapshots.mandragora.io/geth_snapshot.lz4
      wget -O story_snapshot.lz4 https://snapshots.mandragora.io/story_snapshot.lz4

      # Decompress story-geth and story snapshots
      lz4 -c -d geth_snapshot.lz4 | tar -xv -C $HOME/.story/geth/iliad/geth
      lz4 -c -d story_snapshot.lz4 | tar -xv -C $HOME/.story/story

      # Delete downloaded story-geth and story snapshots
      sudo rm -v geth_snapshot.lz4
      sudo rm -v story_snapshot.lz4

      # Restore your validator state
      sudo cp $HOME/.story/priv_validator_state.json.backup $HOME/.story/story/data/priv_validator_state.json

      # Start your story-geth and story nodes
      sudo systemctl start story-geth
      sudo systemctl start story
      ;;
    *)
      echo "Invalid option! Please try again."
      ;;
  esac

done
