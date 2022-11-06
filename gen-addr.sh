#!/bin/bash

echo -e "\e[1m\e[32m    Enter wallet number:\e[0m"
echo "_|-_|-_|-_|-_|-_|-_|"
read num
echo "_|-_|-_|-_|-_|-_|-_|"


FILE="wallet.txt"
if [[ -f $FILE ]]; then
  echo "wallet file exists. Removing..."
  rm $FILE
fi

for((i=1; i<=$num; i++)); do

echo "----------- Wallet $i ----------" >> $FILE
nibid keys add wallet-$i << EOF &>> $FILE
11111111
EOF
echo -e "\n" >> $FILE

done
