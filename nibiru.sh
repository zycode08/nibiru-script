#!/bin/bash

PS3='Select an action: '
options=(
"Install Node"
"Synchronization via StateSync"
"Update peer"
"Exit")

select opt in "${options[@]}"
do
case $opt in

"Install Node")

echo -e "\e[1m\e[32m	Enter monkier:\e[0m"
echo "_|-_|-_|-_|-_|-_|-_|"
read moniker
echo "_|-_|-_|-_|-_|-_|-_|"

if [[ -z "$moniker" ]]
then
  echo "monkier is not set";
  exit 1;
fi

# Install Go
echo "================ Install Go ====================="
sudo rm -rf /usr/local/go
curl https://dl.google.com/go/go1.19.3.linux-amd64.tar.gz | sudo tar -C/usr/local -zxvf - >/dev/null 2>&1;
cat <<'EOF' >>$HOME/.profile
export GOROOT=/usr/local/go
export GOPATH=$HOME/go
export GO111MODULE=on
export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin
EOF
source $HOME/.profile

go version

# Install other dependency
echo "================ Install Dependency ====================="
sudo apt-get update -y && sudo apt-get upgrade -y >/dev/null 2>&1;
sudo apt-get install curl build-essential jq git -y >/dev/null 2>&1;

# Install Nibiru
echo "================ Install Nibiru ====================="
cd $HOME
git clone https://github.com/NibiruChain/nibiru
cd nibiru
git checkout v0.15.0
make install >/dev/null 2>&1

nibid version

# Configure
echo "================ Configure ====================="
echo "monkier is $moniker"
nibid init $moniker --chain-id=nibiru-testnet-1
nibid config chain-id nibiru-testnet-1

echo "================ Download Genesis ====================="
curl -s https://rpc.testnet-1.nibiru.fi/genesis | jq -r .result.genesis >  $HOME/.nibid/config/genesis.json

echo "================ Set Peer and Seed ====================="
cp $HOME/.nibid/config/config.toml $HOME/.nibid/config/config.toml.bak
cp $HOME/.nibid/config/app.toml $HOME/.nibid/config/app.toml.bak
PEERS="34c50ae477d645d385b3198a21fa68d91dccc7df@34.164.150.25:26656,bab80bd8f12dd728e80dce145f52d1e52c5d6b9c@104.155.185.53:26656,37713248f21c37a2f022fbbb7228f02862224190@35.243.130.198:26656,ff59bff2d8b8fb6114191af7063e92a9dd637bd9@35.185.114.96:26656,cb431d789fe4c3f94873b0769cb4fce5143daf97@35.227.113.63:26656,968472e8769e0470fadad79febe51637dd208445@65.108.6.45:60656"
seeds=""
sed -i.bak -e "s/^persistent_peers *=.*/persistent_peers = \"$PEERS\"/" $HOME/.nibid/config/config.toml
sed -i.bak -e "s/^seeds *=.*/seeds = \"$seeds\"/" $HOME/.nibid/config/config.toml

echo "================ Set Pruning ====================="
pruning="custom"
pruning_keep_recent="100"
pruning_keep_every="0"
pruning_interval="10"
sed -i -e "s/^pruning *=.*/pruning = \"$pruning\"/" $HOME/.nibid/config/app.toml
sed -i -e "s/^pruning-keep-recent *=.*/pruning-keep-recent = \"$pruning_keep_recent\"/" $HOME/.nibid/config/app.toml
sed -i -e "s/^pruning-keep-every *=.*/pruning-keep-every = \"$pruning_keep_every\"/" $HOME/.nibid/config/app.toml
sed -i -e "s/^pruning-interval *=.*/pruning-interval = \"$pruning_interval\"/" $HOME/.nibid/config/app.toml

#echo "================ Set Fast Sync ====================="
#SNAP_RPC=https://t-nibiru.rpc.utsa.tech:443

#LATEST_HEIGHT=$(curl -s $SNAP_RPC/block | jq -r .result.block.header.height); \
#BLOCK_HEIGHT=$((LATEST_HEIGHT - 2000)); \
#TRUST_HASH=$(curl -s "$SNAP_RPC/block?height=$BLOCK_HEIGHT" | jq -r .result.block_id.hash)

#echo $LATEST_HEIGHT $BLOCK_HEIGHT $TRUST_HASH

#sed -i.bak -E "s|^(enable[[:space:]]+=[[:space:]]+).*$|\1true| ; \
#s|^(rpc_servers[[:space:]]+=[[:space:]]+).*$|\1\"$SNAP_RPC,$SNAP_RPC\"| ; \
#s|^(trust_height[[:space:]]+=[[:space:]]+).*$|\1$BLOCK_HEIGHT| ; \
#s|^(trust_hash[[:space:]]+=[[:space:]]+).*$|\1\"$TRUST_HASH\"| ; \
#s|^(seeds[[:space:]]+=[[:space:]]+).*$|\1\"\"|" $HOME/.nibid/config/config.toml

echo "================ Set Min Gas Price ====================="
sed -i 's/minimum-gas-prices =.*/minimum-gas-prices = "0.025unibi"/g' $HOME/.nibid/config/app.toml

echo "================ Set Block Parameters ====================="
CONFIG_TOML="$HOME/.nibid/config/config.toml"
sed -i 's/timeout_propose =.*/timeout_propose = "100ms"/g' $CONFIG_TOML
sed -i 's/timeout_propose_delta =.*/timeout_propose_delta = "500ms"/g' $CONFIG_TOML
sed -i 's/timeout_prevote =.*/timeout_prevote = "100ms"/g' $CONFIG_TOML
sed -i 's/timeout_prevote_delta =.*/timeout_prevote_delta = "500ms"/g' $CONFIG_TOML
sed -i 's/timeout_precommit =.*/timeout_precommit = "100ms"/g' $CONFIG_TOML
sed -i 's/timeout_precommit_delta =.*/timeout_precommit_delta = "500ms"/g' $CONFIG_TOML
sed -i 's/timeout_commit =.*/timeout_commit = "1s"/g' $CONFIG_TOML
sed -i 's/skip_timeout_commit =.*/skip_timeout_commit = false/g' $CONFIG_TOML

echo "================ Start node ====================="
sudo tee <<EOF >/dev/null /etc/systemd/system/nibiru.service
[Unit]
Description=Nibiru Node
Requires=network-online.target
After=network-online.target

[Service]
Type=exec
User=$USER
ExecStart=$(which nibid) start --home /home/$USER/.nibid
Restart=on-failure
RestartSec=3
ExecReload=/bin/kill -HUP $MAINPID
KillSignal=SIGTERM
PermissionsStartOnly=true
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable nibiru
sudo systemctl start nibiru

break
;;

"Synchronization via StateSync")
peers="39243aace8e3bed2ca081963e7fc709126c62f92@34.82.218.172:26656,1a307de6dff410984fe6ae23f2fc6427519ed4aa@34.84.28.232:26656,37713248f21c37a2f022fbbb7228f02862224190@35.243.130.198:26656,ff59bff2d8b8fb6114191af7063e92a9dd637bd9@35.185.114.96:26656,cb431d789fe4c3f94873b0769cb4fce5143daf97@35.227.113.63:26656,968472e8769e0470fadad79febe51637dd208445@65.108.6.45:60656"
sed -i.bak -e "s/^persistent_peers *=.*/persistent_peers = \"$peers\"/" $HOME/.nibid/config/config.toml
sed -i 's/max_num_inbound_peers *=.*/max_num_inbound_peers = 100/g' $HOME/.nibid/config/config.toml
sed -i 's/max_num_outbound_peers *=.*/max_num_outbound_peers = 100/g' $HOME/.nibid/config/config.toml
SNAP_RPC=https://t-nibiru.rpc.utsa.tech:443
LATEST_HEIGHT=$(curl -s $SNAP_RPC/block | jq -r .result.block.header.height); \
BLOCK_HEIGHT=$((LATEST_HEIGHT - 2000)); \
TRUST_HASH=$(curl -s "$SNAP_RPC/block?height=$BLOCK_HEIGHT" | jq -r .result.block_id.hash)
echo $LATEST_HEIGHT $BLOCK_HEIGHT $TRUST_HASH
sed -i.bak -E "s|^(enable[[:space:]]+=[[:space:]]+).*$|\1true| ; \
s|^(rpc_servers[[:space:]]+=[[:space:]]+).*$|\1\"$SNAP_RPC,$SNAP_RPC\"| ; \
s|^(trust_height[[:space:]]+=[[:space:]]+).*$|\1$BLOCK_HEIGHT| ; \
s|^(trust_hash[[:space:]]+=[[:space:]]+).*$|\1\"$TRUST_HASH\"| ; \
s|^(seeds[[:space:]]+=[[:space:]]+).*$|\1\"\"|" $HOME/.nibid/config/config.toml
nibid tendermint unsafe-reset-all --home $HOME/.nibid --keep-addr-book
sudo systemctl restart nibiru && journalctl -u nibiru -f -o cat

break
;;


"Update peer")

peers="34c50ae477d645d385b3198a21fa68d91dccc7df@34.164.150.25:26656,bab80bd8f12dd728e80dce145f52d1e52c5d6b9c@104.155.185.53:26656,39243aace8e3bed2ca081963e7fc709126c62f92@34.82.218.172:26656,1a307de6dff410984fe6ae23f2fc6427519ed4aa@34.84.28.232:26656,37713248f21c37a2f022fbbb7228f02862224190@35.243.130.198:26656,ff59bff2d8b8fb6114191af7063e92a9dd637bd9@35.185.114.96:26656,cb431d789fe4c3f94873b0769cb4fce5143daf97@35.227.113.63:26656,968472e8769e0470fadad79febe51637dd208445@65.108.6.45:60656"
sed -i.bak -e "s/^persistent_peers *=.*/persistent_peers = \"$peers\"/" $HOME/.nibid/config/config.toml
nibid tendermint unsafe-reset-all --home $HOME/.nibid --keep-addr-book
sudo systemctl restart nibiru && journalctl -u nibiru -f -o cat

break
;;

"Exit")
exit

esac
done
