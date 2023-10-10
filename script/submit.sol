// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;
pragma abicoder v2;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import '../src/ISimpleDAO.sol';
import './util.sol';

// Invoke this with ENV vars initialized. Here's an example with local test accounts:
// PROPOSER_ADDRESS=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 DAO_ADDRESS=0x9fe46736679d2d9a65f0992f2272de9f3c7fa6e0 TO=<whereever> WEI=1 forge script script/init.sol  --fork-url http://localhost:8545 --broadcast --private-key=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

// Please note that for production we would pass --ledger instead of --private-key.

contract MyScript is Script {
    function run() external {
        
        ISimpleDAO dao = ISimpleDAO(vm.envAddress("DAO_ADDRESS"));

        bytes memory data = vm.envOr("DATA", bytes(""));
        uint16 data_length = uint16(data.length);
        bytes memory padded_data = pad_to_length(data, DATA_LENGTH);

        vm.startBroadcast(vm.envAddress("PROPOSER_ADDRESS"));
        uint256 tx_id = dao.submit_transaction(vm.envAddress("TO"), vm.envUint("WEI"), padded_data, data_length);
        vm.stopBroadcast();

        console.log("Submitted transaction with id: %d", tx_id);
    }
}