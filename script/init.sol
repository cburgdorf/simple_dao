// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;
pragma abicoder v2;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import '../src/ISimpleDAO.sol';


// Invoke this with ENV vars initialized. Here's an example with local test accounts:
// OWNER_0=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 OWNER_0_WEIGHT=2 PCT=50 GOV_ADDRESS=0xcf7ed3acca5a467e9e704c703e8d87f634fb0fc9 DAO_ADDRESS=0x9fe46736679d2d9a65f0992f2272de9f3c7fa6e0 DEPLOYER_ADDRESS=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266  forge script script/init.sol  --fork-url http://localhost:8545 --broadcast --private-key=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

// Please note that for production we would pass --ledger instead of --private-key.
// That is also why the `startBroadcast` is based on the `DEPLOYER_ADDRESS`, independent of a private key.

contract MyScript is Script {
    function run() external {
        OwnerWeight[10] memory weights;
        weights[0] = OwnerWeight(vm.envOr("OWNER_0", 0x0000000000000000000000000000000000000000), vm.envOr("OWNER_0_WEIGHT", uint256(0)));
        weights[1] = OwnerWeight(vm.envOr("OWNER_1", 0x0000000000000000000000000000000000000000), vm.envOr("OWNER_1_WEIGHT", uint256(0)));
        weights[2] = OwnerWeight(vm.envOr("OWNER_2", 0x0000000000000000000000000000000000000000), vm.envOr("OWNER_2_WEIGHT", uint256(0)));
        weights[3] = OwnerWeight(vm.envOr("OWNER_3", 0x0000000000000000000000000000000000000000), vm.envOr("OWNER_3_WEIGHT", uint256(0)));
        weights[4] = OwnerWeight(vm.envOr("OWNER_4", 0x0000000000000000000000000000000000000000), vm.envOr("OWNER_4_WEIGHT", uint256(0)));
        weights[5] = OwnerWeight(vm.envOr("OWNER_5", 0x0000000000000000000000000000000000000000), vm.envOr("OWNER_5_WEIGHT", uint256(0)));
        weights[6] = OwnerWeight(vm.envOr("OWNER_6", 0x0000000000000000000000000000000000000000), vm.envOr("OWNER_6_WEIGHT", uint256(0)));
        weights[7] = OwnerWeight(vm.envOr("OWNER_7", 0x0000000000000000000000000000000000000000), vm.envOr("OWNER_7_WEIGHT", uint256(0)));
        weights[8] = OwnerWeight(vm.envOr("OWNER_8", 0x0000000000000000000000000000000000000000), vm.envOr("OWNER_8_WEIGHT", uint256(0)));
        weights[9] = OwnerWeight(vm.envOr("OWNER_9", 0x0000000000000000000000000000000000000000), vm.envOr("OWNER_9_WEIGHT", uint256(0)));

        bytes memory initialize_tx_bytes = abi.encodeWithSelector(ISimpleDAO.initialize.selector, weights, vm.envUint("PCT"), vm.envAddress("GOV_ADDRESS"));
        console.logBytes(initialize_tx_bytes);

        ISimpleDAO dao = ISimpleDAO(vm.envAddress("DAO_ADDRESS"));

        vm.startBroadcast(vm.envAddress("DEPLOYER_ADDRESS"));
        dao.initialize(weights, vm.envUint("PCT"), vm.envAddress("GOV_ADDRESS"));
        vm.stopBroadcast();
    }
}