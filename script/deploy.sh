#!/bin/bash

# This could be so much nicer with a foundry script once this is resolved:
# https://github.com/foundry-rs/foundry/issues/5375#issuecomment-1748715366 

# Invoke with SEND_OPT="--private-key <private-key>" ./script/deploy.sh
# Or for production: SEND_OPT="--ledger" ./script/deploy.sh


dao_deploy_response=$(cast send --json $SEND_OPT --create $(cat output/SimpleDAO/SimpleDAO.bin))

# Parse the JSON response to get the contractAddress value
dao_address=$(echo $dao_deploy_response | jq -r '.contractAddress')

# Now you can use the $dao_address variable
echo "DAO is deployed at: $dao_address"

gov_deploy_resonse=$(cast send --json $SEND_OPT --create $(cat output/SnakeToken/SnakeToken.bin) $(cast abi-encode "__init__(address,uint256)" $dao_address 100000))

gov_address=$(echo $gov_deploy_resonse | jq -r '.contractAddress')

echo "Governance Token is deployed at: $gov_address"

