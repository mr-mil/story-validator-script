#!/bin/bash

while true; do
# Display welcome message and user options
  echo -e "\e[1;33m**************************************************\e[0m"
  echo -e "\e[1;36m*                                                *\e[0m"
  echo -e "\e[1;36m*  \e[1;32mWelcome to the Story Validator installation script!\e[1;36m  *\e[0m"
  echo -e "\e[1;36m*                                                *\e[0m"
  echo -e "\e[1;36m**************************************************\e[0m"
  echo "Please select one of the following options:"
  echo "1) Install and setup validator node"
  echo "2) Display Story logs"
  echo "3) Display Geth logs"
  echo "4) Check Sync Node"
  echo "5) Create Validator (After Install and Sync)"
  echo "6) Export All Addresses"
  echo "7) Update using the latest snapshot"
  echo "8) Exit"

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
      mkdir -p $HOME/go/bin
      if ! grep -q "$HOME/go/bin" $HOME/.bash_profile; then
        echo "export PATH=\$PATH:/usr/local/go/bin:\$HOME/go/bin" >> $HOME/.bash_profile
      fi
      cp geth-linux-amd64-0.10.0-afaa40a/geth $HOME/go/bin/story-geth

      # Reload Bash Profile
      source $HOME/.bash_profile

      # Verify if story-geth was copied successfully
      if [ ! -f "$HOME/go/bin/story-geth" ]; then
        echo "Error: story-geth was not found in $HOME/go/bin. Please check the download and extraction steps."
        continue
      fi

      # Download and extract Story
      wget https://story-geth-binaries.s3.us-west-1.amazonaws.com/story-public/story-linux-amd64-0.12.0-d2e195c.tar.gz
      tar -xzvf story-linux-amd64-0.12.0-d2e195c.tar.gz
      mkdir -p $HOME/go/bin
      if ! grep -q "$HOME/go/bin" $HOME/.bash_profile; then
        echo "export PATH=\$PATH:/usr/local/go/bin:\$HOME/go/bin" >> $HOME/.bash_profile
      fi
      cp $HOME/story-linux-amd64-0.12.0-d2e195c/story $HOME/go/bin/story

      # Reload Bash Profile
      source $HOME/.bash_profile

      # Verify if story was copied successfully
      if [ ! -f "$HOME/go/bin/story" ]; then
        echo "Error: story was not found in $HOME/go/bin. Please check the download and extraction steps."
        continue
      fi

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
User=$USER
ExecStart=$HOME/go/bin/story-geth --iliad --syncmode full
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
User=$USER
ExecStart=$HOME/go/bin/story run
Restart=on-failure
RestartSec=3
LimitNOFILE=4096

[Install]
WantedBy=multi-user.target
EOF

      # Start and enable services
      sudo systemctl daemon-reload && \
      sudo systemctl start story-geth && \
      sudo systemctl enable story-geth

      sudo systemctl daemon-reload && \
      sudo systemctl start story && \
      sudo systemctl enable story

      # Configure peers
      PEERS=$(curl -sS https://story-rpc.mandragora.io/net_info | jq -r '.result.peers[] | "\(.node_info.id)@\(.remote_ip):\(.node_info.listen_addr)"' | awk -F ':' '{print $1":"$(NF)}' | paste -sd, -)
      if [ -f "$HOME/.story/story/config/config.toml" ]; then
        sed -i.bak -e "s/^persistent_peers *=.*/persistent_peers = \"$PEERS\"/" $HOME/.story/story/config/config.toml
        sudo systemctl restart story
      else
        echo "Warning: config.toml not found. Skipping peers configuration."
      fi

      # Configure seeds
      SEEDS=b6fb541c80d968931602710342dedfe1f5c577e3@story-seed.mandragora.io:23656,51ff395354c13fab493a03268249a74860b5f9cc@story-testnet-seed.itrocket.net:26656,5d7507dbb0e04150f800297eaba39c5161c034fe@135.125.188.77:26656
      if [ -f "$HOME/.story/story/config/config.toml" ]; then
        sed -i.bak -e "s/^seeds *=.*/seeds = \"$SEEDS\"/" $HOME/.story/story/config/config.toml
        sudo systemctl restart story
        sudo systemctl restart story-geth
      else
        echo "Warning: config.toml not found. Skipping seeds configuration."
      fi

      # Download addrbook file
      wget -O $HOME/.story/story/config/addrbook.json https://snapshots.mandragora.io/addrbook.json
      ;;
    2)
      # Display Story logs
      if [ ! -d "$HOME/.story" ]; then
        echo "The node has not been installed yet. Please run option 1 to install the node first."
        continue
      fi
	  sudo journalctl -u story -f -o cat
      ;;
	3)
      # Display Geth logs
	  if [ ! -d "$HOME/.story" ]; then
        echo "The node has not been installed yet. Please run option 1 to install the node first."
        continue
      fi
      sudo journalctl -u story-geth -f -o cat
      ;;
	4)
      # Checking Sync
	  if [ ! -d "$HOME/.story" ]; then
        echo "The node has not been installed yet. Please run option 1 to install the node first."
        continue
      fi
      curl localhost:26657/status | jq
      ;;
	5)
      # Validator Create
	  if [ ! -d "$HOME/.story" ]; then
        echo "The node has not been installed yet. Please run option 1 to install the node first."
        continue
      fi

	  while true; do
		read -p "Are you sure your node is full sync and get faucet for your address? (yes/no): " confirm
		confirm=$(echo "$confirm" | tr '[:upper:]' '[:lower:]')
		if [[ "$confirm" == "yes" || "$confirm" == "y" ]]; then
		  read -p "OK, Please enter your Private Key: " pvkey
		  story validator create --stake 1000000000000000000 --private-key "$pvkey"
		elif [[ "$confirm" == "no" || "$confirm" == "n" ]]; then
		  echo "Operation cancelled."
		  continue 2
		else
		  echo "Invalid input. Please enter yes or no."
		fi
	  done
      ;;
	6)
      # Export All Addresses
	  if [ ! -d "$HOME/.story" ]; then
        echo "The node has not been installed yet. Please run option 1 to install the node first."
        continue
      fi
	  echo "************** EVM Public Address : ****************"
      story validator export - export-evm-key
	  echo "************** Go to https://story.faucetme.pro or https://docs.story.foundation/docs/faucet and get faucet for public EVM address ****************"
	  echo "************** Private Key : ****************"
	  story validator export --export-evm-key
	  cat /root/.story/story/config/private_key.txt
	  echo "************** Validator Address : ****************"
	  cd ~/.story/story/config
	  cat priv_validator_key.json | grep address
      ;;
    7)
      # Check if installation has been completed
      if [ ! -d "$HOME/.story" ]; then
        echo "The node has not been installed yet. Please run option 1 to install the node first."
        continue
      fi

      # Stop your story-geth and story nodes
      sudo systemctl stop story-geth
      sudo systemctl stop story

      # Back up your validator state
      sudo cp $HOME/.story/data/priv_validator_state.json $HOME/.story/priv_validator_state.json.backup

      # Delete previous geth chaindata and story data folders
      sudo rm -rf $HOME/.story/geth/iliad/geth/chaindata
      sudo rm -rf $HOME/.story/data

      # Download story-geth and story snapshots
      wget -O geth_snapshot.lz4 https://snapshots.mandragora.io/geth_snapshot.lz4
      wget -O story_snapshot.lz4 https://snapshots.mandragora.io/story_snapshot.lz4

      # Decompress story-geth and story snapshots
      lz4 -c -d geth_snapshot.lz4 | tar -xv -C $HOME/.story/geth/iliad/geth
      lz4 -c -d story_snapshot.lz4 | tar -xv -C $HOME/.story

      # Delete downloaded story-geth and story snapshots
      rm -v geth_snapshot.lz4
      rm -v story_snapshot.lz4

      # Restore your validator state
      sudo cp $HOME/.story/priv_validator_state.json.backup $HOME/.story/data/priv_validator_state.json

      # Start your story-geth and story nodes
      sudo systemctl start story-geth
      sudo systemctl start story
      ;;
	8)
	  echo "Exiting the script. Goodbye!"
	  exit 0
	  ;;
    *)
      echo "Invalid option! Please try again."
      ;;
  esac

done
