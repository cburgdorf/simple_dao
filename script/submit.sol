// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;
pragma abicoder v2;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import '../src/ISimpleDAO.sol';
import './util.sol';

// Invoke this with ENV vars initialized. Here's an example with local test accounts:
// USER_ADDRESS=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 DAO_ADDRESS=0x9fe46736679d2d9a65f0992f2272de9f3c7fa6e0 TO=<whereever> WEI=1 forge script script/init.sol  --fork-url http://localhost:8545 --broadcast --private-key=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

// Please note that for production we would pass --ledger instead of --private-key.

contract MyScript is Script {
    function run() external {

        bytes memory data = vm.envOr("DATA", bytes(""));
        uint16 data_length = uint16(data.length);
        bytes memory padded_data = pad_to_length(data, DATA_LENGTH);

        if (vm.envOr("DRY", false)) {
            console.log("Dry run, not submitting transaction");
            bytes memory tx_bytes = abi.encodeWithSelector(ISimpleDAO.submit_transaction.selector, vm.envAddress("TO"), vm.envUint("WEI"), padded_data, data_length);
            console.log("Transaction bytes:");
            console.logBytes(tx_bytes);
            console.log("keccak(transaction bytes):");
            console.logBytes32(keccak256(tx_bytes));
            return;
        }

        ISimpleDAO dao = ISimpleDAO(vm.envAddress("DAO_ADDRESS"));
        vm.startBroadcast(vm.envAddress("USER_ADDRESS"));
        uint256 tx_id = dao.submit_transaction(vm.envAddress("TO"), vm.envUint("WEI"), padded_data, data_length);
        vm.stopBroadcast();

        console.log("Submitted transaction with id: %d", tx_id);
    }
}