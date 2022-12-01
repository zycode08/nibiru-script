#!/bin/bash

PS3='Select an action: '
options=(
"Install Node"
"Synchronization via StateSync"
"Update peer"
"Backup"
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
#PEERS="34c50ae477d645d385b3198a21fa68d91dccc7df@34.164.150.25:26656,bab80bd8f12dd728e80dce145f52d1e52c5d6b9c@104.155.185.53:26656,37713248f21c37a2f022fbbb7228f02862224190@35.243.130.198:26656,ff59bff2d8b8fb6114191af7063e92a9dd637bd9@35.185.114.96:26656,cb431d789fe4c3f94873b0769cb4fce5143daf97@35.227.113.63:26656,968472e8769e0470fadad79febe51637dd208445@65.108.6.45:60656"
seeds=""
peers="b32bb87364a52df3efcbe9eacc178c96b35c823a@nibiru-testnet.nodejumper.io:26656,968472e8769e0470fadad79febe51637dd208445@65.108.6.45:60656,ff597c3eea5fe832825586cce4ed00cb7798d4b5@rpc.nibiru.ppnv.space:10656,37713248f21c37a2f022fbbb7228f02862224190@35.243.130.198:26656,ff59bff2d8b8fb6114191af7063e92a9dd637bd9@35.185.114.96:26656,cb431d789fe4c3f94873b0769cb4fce5143daf97@35.227.113.63:26656"
sed -i.bak -e "s/^persistent_peers *=.*/persistent_peers = \"$peers\"/" $HOME/.nibid/config/config.toml
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
sudo systemctl stop nibiru

cp $HOME/.nibid/data/priv_validator_state.json $HOME/.nibid/priv_validator_state.json.backup
nibid tendermint unsafe-reset-all --home $HOME/.nibid --keep-addr-book

SNAP_RPC="https://nibiru-testnet.nodejumper.io:443"

LATEST_HEIGHT=$(curl -s $SNAP_RPC/block | jq -r .result.block.header.height); \
BLOCK_HEIGHT=$((LATEST_HEIGHT - 2000)); \
TRUST_HASH=$(curl -s "$SNAP_RPC/block?height=$BLOCK_HEIGHT" | jq -r .result.block_id.hash)

echo $LATEST_HEIGHT $BLOCK_HEIGHT $TRUST_HASH

peers="b32bb87364a52df3efcbe9eacc178c96b35c823a@nibiru-testnet.nodejumper.io:27656"
sed -i 's|^persistent_peers *=.*|persistent_peers = "'$peers'"|' $HOME/.nibid/config/config.toml

sed -i -E "s|^(enable[[:space:]]+=[[:space:]]+).*$|\1true| ; \
s|^(rpc_servers[[:space:]]+=[[:space:]]+).*$|\1\"$SNAP_RPC,$SNAP_RPC\"| ; \
s|^(trust_height[[:space:]]+=[[:space:]]+).*$|\1$BLOCK_HEIGHT| ; \
s|^(trust_hash[[:space:]]+=[[:space:]]+).*$|\1\"$TRUST_HASH\"|" $HOME/.nibid/config/config.toml

mv $HOME/.nibid/priv_validator_state.json.backup $HOME/.nibid/data/priv_validator_state.json

sudo systemctl restart nibiru
sudo journalctl -u nibiru -f --no-hostname -o cat
#peers="39243aace8e3bed2ca081963e7fc709126c62f92@34.82.218.172:26656,1a307de6dff410984fe6ae23f2fc6427519ed4aa@34.84.28.232:26656,37713248f21c37a2f022fbbb7228f02862224190@35.243.130.198:26656,ff59bff2d8b8fb6114191af7063e92a9dd637bd9@35.185.114.96:26656,cb431d789fe4c3f94873b0769cb4fce5143daf97@35.227.113.63:26656,968472e8769e0470fadad79febe51637dd208445@65.108.6.45:60656"
#sed -i.bak -e "s/^persistent_peers *=.*/persistent_peers = \"$peers\"/" $HOME/.nibid/config/config.toml
#sed -i 's/max_num_inbound_peers *=.*/max_num_inbound_peers = 100/g' $HOME/.nibid/config/config.toml
#sed -i 's/max_num_outbound_peers *=.*/max_num_outbound_peers = 100/g' $HOME/.nibid/config/config.toml
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
#nibid tendermint unsafe-reset-all --home $HOME/.nibid --keep-addr-book
#sudo systemctl restart nibiru && journalctl -u nibiru -f -o cat

break
;;


"Update peer")

peers="b32bb87364a52df3efcbe9eacc178c96b35c823a@nibiru-testnet.nodejumper.io:27656,751f76832ae3aefe9373ee697f4699c4bd0acafc@161.97.136.141:26656,93137cb574b5d6bd6fdb60e6c8164a08c1516081@209.126.8.192:26656,65436a8aba0cd3809a79c3c4c5a53e70eb6d6ba4@128.199.219.116:39656,5be20d8aba9971860e455257508803785679faef@135.181.208.213:26656,ea150128fbfcac82e74821b03212c210ab2192d3@154.53.53.60:26657,6473c6d5fd1e946cd74b844c99bc8a9fd198c853@75.119.151.40:26656,145c04540ea9fad36d97a6c37b66d134e19a5450@38.242.152.235:26656,51625ddeba19faec101fe10423315856f82257ca@51.222.155.224:26656,4b75a189522bd4d5cdfbc5f377e2a78c4010fa66@138.197.164.86:26656,eb65c95ea745d1cb5f66e2fda5d5e1029f4dc43d@5.161.43.109:26656,f30138f9d0c986b511ea476eb199fead17a62ae4@45.67.217.120:46656,4ab083dcc4e96115a2875867d320c0a49f990f63@154.12.225.113:39656,ae357e14309640ca33cde597b37f0a91e63a32bd@144.76.90.130:36656,358a862e6851d8afe4efb7e0a9223b770a745eb0@34.142.140.178:39656,f59c1c43fc3349675e06d04daa55aca91254ef36@67.207.87.157:26656,75df3cedd70ef5db343278eb67e94a41949358b1@45.67.217.225:46656,996dafa0a242781b11770a33bc7348d034bb9b05@212.8.240.13:2486,8d7e283c8cbe8d3a4799b37330d89b498d5024f4@89.117.52.139:39656,7445531c80f47f5469d2244d59276fa4f569515e@161.97.105.100:26656,659030eeffba5cf38c7d5f66bd46447d2048d443@62.171.171.178:26656,3997242f9646ca642932852b7577ddb9976e0396@5.199.130.53:26656,6794490764f688fde88befee0340eaea022cd8d1@161.97.105.44:26656,001f41373472f1a04512e75185d2de68a1f390bd@65.108.105.37:28656,34c50ae477d645d385b3198a21fa68d91dccc7df@34.89.193.160:26656,920a63eac8ddc9ad63b5d5bdb1ff55f0f3dec913@65.21.242.148:26656,d5519e378247dfb61dfe90652d1fe3e2b3005a5b@65.109.68.190:39656,d458fc63d2c49888af3b91e5d13279dc3c96fa92@185.245.183.232:46656,070d8f6373f57092d53b9a5e0062228074469498@65.109.8.96:26656,9288e8ab4f01383ac1864ddcb7f9eccc4c2e8810@83.171.248.175:39656,dda2ad7090a4dcf4847f040633e1adfb8cc06fbb@164.92.79.143:39656,9007f52d9f46c581bf4a0fc6f4a108699caa4676@135.181.83.112:39656,d4cc19cf98ff84863916445a33a6301e1bf32866@80.82.215.211:26656,6ed3b1b345e99bca60f04de930d6d11792923713@95.216.159.99:39656,a0dd9905a3511c174c504b1ea953c7e5f1dbc9ab@65.108.217.146:39656,3b8e8283c3778af3c0e29e406f4aee5eb608e64d@62.171.172.51:26656,1b786fbb3a0db6f2ec99fdd2424d4aacddc10ed4@77.75.230.201:26656,66363f55c128ce60bb4c5ebfbc070ec464bcd532@80.82.215.220:26656,fa4c53154dcc202619aa4b5cb156570f45896f45@5.161.56.143:26656,c687fa90a86bd34161fa67e7945448cac4a18844@46.228.205.196:26656,dee5a6d44b302445d5cf521d2b9c3fd9a3ae21cb@161.97.70.202:26656,f8038bd699a307c75d9e2a5d57518ff05f455836@142.132.182.1:36656,34b70090fcc8e1ebf6be10be6e314e8d66931371@185.239.208.90:26656,600ac00790f11f7c0803dceb42c55a8a8f35dd99@62.141.44.46:26656,ef22e4f853600eaafd00c62e4a058849ace64670@185.244.180.84:26656,f880e569c033251cc90d015d77e25d66da51ed77@185.215.166.85:39656,e2b8b9f3106d669fe6f3b49e0eee0c5de818917e@213.239.217.52:32656,95989bb86344422e5b67c059b474ee432c387f69@38.242.217.12:26656,1038f545b6495d29f1962fd72ba464d2277b85bb@194.5.152.252:26656,01c942713a9b910c4990210459c9360c7e8307bf@161.97.105.134:26656,968472e8769e0470fadad79febe51637dd208445@65.108.6.45:60656"

sed -i.bak -e "s/^persistent_peers *=.*/persistent_peers = \"$peers\"/" $HOME/.nibid/config/config.toml
sudo systemctl restart nibiru && journalctl -u nibiru -f -o cat

break
;;

"Backup")

tar -cvf $HOME/config.tar $HOME/.nibid/config

break
;;

"Exit")
exit

esac
done
