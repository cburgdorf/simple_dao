// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;
pragma abicoder v2;

import '../../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '../../node_modules/@openzeppelin/contracts/utils/Strings.sol';
import 'forge-std/Test.sol';
import '../../lib/utils/Fe.sol';
import '../ISimpleDAO.sol';

address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
// Binance wallet with DAI
address constant BINANCE_ACCOUNT = 0x28C6c06298d514Db089934071355E5743bf21d60;

function pad_to_length(bytes memory data, uint256 length) pure returns (bytes memory) {
    bytes memory padded_data = new bytes(length);
    for (uint256 i = 0; i < data.length; i++) {
        padded_data[i] = data[i];
    }
    return padded_data;
}

uint16 constant DATA_LENGTH = 1024;
address constant ALICE = 0x627306090abaB3A6e1400e9345bC60c78a8BEf57;
address constant BOB = 0x527306090ABaB3a6e1400e9345BC60C78A8Bef57;
address constant ZERO_ADDRESS = 0x0000000000000000000000000000000000000000;
uint256 constant INITIAL_MULTISIG_DAI_BALANCE = 10000;


contract SimpleDAOTest is Test {

    // We have to declare the events that we want add assertions for
    event Confirmation(address indexed owner, uint indexed tx_id);
    event Revocation(address indexed owner, uint indexed tx_id);
    event Submission(uint indexed tx_id);
    event Execution(uint indexed tx_id);
    event ExecutionFailure(uint indexed tx_id);
    event OwnerAddition(address indexed owner);
    event OwnerRemoval(address indexed owner);

    ISimpleDAO public multisig;
    IERC20 public gov_token;

    function setUp() public {
        Fe.compileIngot("simpledao");

        OwnerWeight[10] memory weights;
        weights[0] = OwnerWeight(address(ALICE), 2);
        weights[1] = OwnerWeight(address(BOB), 8);
        
        // TODO: WE NEED TO MOVE THIS INTO AN INITIALIZE CALL BECAUSE WE CAN'T DISTRIBUTE TOKENS
        // BEFOE gov_token_initialize IS CALLED
        multisig = ISimpleDAO(Fe.deployContract("SimpleDAO"));
        gov_token = IERC20(Fe.deployContract("SnakeToken", abi.encode(address(multisig), 100_000)));
        multisig.initialize(weights, 50, address(gov_token));
        // We gave 100_000 $SNAKE to the multisig contract and distributed 10 to Alice and Bob
        //assertEq(gov_token.balanceOf(address(multisig)), 100_000 - 10);

        // Give the multisig some DAI so that we can use it in tests
        address multisig_address = address(multisig);
        vm.startPrank(BINANCE_ACCOUNT);
        IERC20(DAI).transfer(address(multisig), INITIAL_MULTISIG_DAI_BALANCE);
        assertEq(IERC20(DAI).balanceOf(multisig_address), INITIAL_MULTISIG_DAI_BALANCE);
        vm.stopPrank();
    }

    function testCannotCallAddOwner() public {
      vm.expectRevert();
      multisig.add_owner(BINANCE_ACCOUNT, 0);
    }

    function testAddAndRemoveOwner() public {
      //bytes memory data = pad_to_length(hex"4a75e74100000000000000000000000028c6c06298d514db089934071355e5743bf21d60", DATA_LENGTH);
      address[10] memory existing_owners = multisig.get_owners();
      assertEq(existing_owners[0], ALICE);
      assertEq(existing_owners[1], BOB);
      assertEq(existing_owners[2], ZERO_ADDRESS);
      assertEq(multisig.get_weight(ALICE), 2);
      assertEq(multisig.get_weight(BOB), 8);
      assertEq(multisig.get_weight(ZERO_ADDRESS), 0);
      assertEq(multisig.get_total_weight(), 10);

      vm.startPrank(ALICE);
      bytes memory add_owner = abi.encodeWithSelector(multisig.add_owner.selector, BINANCE_ACCOUNT, 1);
      bytes memory padded_tx = pad_to_length(add_owner, DATA_LENGTH);
      uint256 tx_id = multisig.submit_transaction(address(multisig), 0, padded_tx, uint16(add_owner.length));
      vm.stopPrank();

      vm.startPrank(BOB);
      vm.expectEmit(true, true, true, true);
      emit OwnerAddition(BINANCE_ACCOUNT);

      multisig.confirm_transaction(tx_id);

      address[10] memory new_owners = multisig.get_owners();
      assertEq(new_owners[0], ALICE);
      assertEq(new_owners[1], BOB);
      assertEq(new_owners[2], BINANCE_ACCOUNT);
      assertEq(multisig.get_weight(ALICE), 2);
      assertEq(multisig.get_weight(BOB), 8);
      assertEq(multisig.get_weight(BINANCE_ACCOUNT), 1);
      assertEq(multisig.get_weight(ZERO_ADDRESS), 0);
      assertEq(multisig.get_total_weight(), 11);

      bytes memory data_removal = pad_to_length(hex"f6b9571a00000000000000000000000028c6c06298d514db089934071355e5743bf21d60", DATA_LENGTH);
      vm.expectEmit(true, true, true, true);
      emit OwnerRemoval(BINANCE_ACCOUNT);
      // Bob can pull that off because he has 80% voting power
      multisig.submit_transaction(address(multisig), 0, data_removal, 36);
      vm.stopPrank();

      assertEq(existing_owners[0], ALICE);
      assertEq(existing_owners[1], BOB);
      assertEq(existing_owners[2], ZERO_ADDRESS);
      assertEq(multisig.get_weight(ALICE), 2);
      assertEq(multisig.get_weight(BOB), 8);
      assertEq(multisig.get_weight(BINANCE_ACCOUNT), 0);
      assertEq(multisig.get_weight(ZERO_ADDRESS), 0);
      assertEq(multisig.get_total_weight(), 10);
    }

    function testReplaceOwner() public {
      bytes memory data = pad_to_length(hex"f097d1de000000000000000000000000527306090abab3a6e1400e9345bc60c78a8bef5700000000000000000000000028c6c06298d514db089934071355e5743bf21d60", DATA_LENGTH);
      vm.startPrank(ALICE);
      address[10] memory existing_owners = multisig.get_owners();
      assertEq(existing_owners[0], ALICE);
      assertEq(existing_owners[1], BOB);
      assertEq(existing_owners[2], ZERO_ADDRESS);

      uint256 tx_id = multisig.submit_transaction(address(multisig), 0, data, 68);
      vm.stopPrank();

      vm.expectEmit(true, true, true, true);
      emit OwnerRemoval(BOB);
      emit OwnerAddition(BINANCE_ACCOUNT);

      vm.startPrank(BOB);
      multisig.confirm_transaction(tx_id);

      address[10] memory new_owners = multisig.get_owners();
      assertEq(new_owners[0], ALICE);
      assertEq(new_owners[1], BINANCE_ACCOUNT);
      assertEq(new_owners[2], ZERO_ADDRESS);
    }

    function testSubmit() public {
      // Send some DAI to the 0x0 address
      bytes memory data = pad_to_length(hex"a9059cbb00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001", DATA_LENGTH);
      vm.startPrank(ALICE);
      vm.expectEmit(true, true, true, true);
      emit Submission(0);
      uint256 tx_id = multisig.submit_transaction(DAI, 0, data, 68);
      assertEq(tx_id, 0);
      vm.expectEmit(true, true, true, true);
      emit Submission(1);
      uint256 second_tx_id = multisig.submit_transaction(DAI, 0, data, 68);
      assertEq(second_tx_id, 1);
    }

    function testRevoke() public {
      // Send some DAI to the 0x0 address
      bytes memory data = pad_to_length(hex"a9059cbb00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001", DATA_LENGTH);
      vm.startPrank(ALICE);
      uint256 tx_id = multisig.submit_transaction(DAI, 0, data, 68);
      address[10] memory confirmations_1 = multisig.get_confirmations(tx_id);
      assertEq(confirmations_1[0], ALICE);
      vm.expectEmit(true, true, true, true);
      emit Revocation(ALICE, tx_id);
      multisig.revoke_confirmation(tx_id);
      address[10] memory confirmations_2 = multisig.get_confirmations(tx_id);
      assertEq(confirmations_2[0], ZERO_ADDRESS);
    }

    function testStrangersCannotSubmit() public {
      // Send some DAI to the 0x0 address
      bytes memory data = pad_to_length(hex"a9059cbb00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001", DATA_LENGTH);
      vm.expectRevert();
      multisig.submit_transaction(DAI, 0, data, 68);
    }

    function testExecuteTx() public {
      bytes memory data = pad_to_length(hex"a9059cbb00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001", DATA_LENGTH);

      vm.startPrank(ALICE);
      vm.expectEmit(true, true, true, true);
      emit Confirmation(ALICE, 0);
      uint256 tx_id = multisig.submit_transaction(DAI, 0, data, 68);

      address[10] memory confirmations_1 = multisig.get_confirmations(tx_id);
      assertEq(confirmations_1[0], ALICE);
      assertEq(confirmations_1[1], ZERO_ADDRESS);

      vm.stopPrank();
      vm.startPrank(BOB);
      vm.expectEmit(true, true, true, true);
      emit Confirmation(BOB, 0);
      vm.expectEmit(true, true, true, true);
      emit Execution(tx_id);
      multisig.confirm_transaction(tx_id);
      address[10] memory confirmations_2 = multisig.get_confirmations(tx_id);
      assertEq(confirmations_2[0], ALICE);
      assertEq(confirmations_2[1], BOB);
      assertEq(confirmations_2[2], ZERO_ADDRESS);

      uint256 second_multisig_balance = IERC20(DAI).balanceOf(address(multisig));
      assertEq(second_multisig_balance, INITIAL_MULTISIG_DAI_BALANCE - 1);

    }

    function testExecutionFails() public {
      bytes memory data = pad_to_length(hex"a9059cbb00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001", DATA_LENGTH);

      vm.startPrank(ALICE);
      vm.expectEmit(true, true, true, true);
      emit Confirmation(ALICE, 0);
      uint256 tx_id = multisig.submit_transaction(DAI, 0, data, 50); // intentionally use a too small data_length

      address[10] memory confirmations_1 = multisig.get_confirmations(tx_id);
      assertEq(confirmations_1[0], ALICE);
      assertEq(confirmations_1[1], ZERO_ADDRESS);

      vm.stopPrank();
      vm.startPrank(BOB);
      vm.expectEmit(true, true, true, true);
      emit Confirmation(BOB, 0);
      vm.expectEmit(true, true, true, true);
      emit ExecutionFailure(tx_id);
      multisig.confirm_transaction(tx_id);
      address[10] memory confirmations_2 = multisig.get_confirmations(tx_id);
      assertEq(confirmations_2[0], ALICE);
      assertEq(confirmations_2[1], BOB);
      assertEq(confirmations_2[2], ZERO_ADDRESS);

      uint256 second_multisig_balance = IERC20(DAI).balanceOf(address(multisig));
      assertEq(second_multisig_balance, INITIAL_MULTISIG_DAI_BALANCE);
    }

    function testCanNotExecuteUnconfirmedTx() public {
      bytes memory data = pad_to_length(hex"a9059cbb00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001", DATA_LENGTH);
      vm.startPrank(ALICE);
      vm.expectEmit(true, true, true, true);
      emit Confirmation(ALICE, 0);

      uint256 tx_id = multisig.submit_transaction(DAI, 0, data, 68);

      multisig.execute_transaction(tx_id);
      uint256 second_multisig_balance = IERC20(DAI).balanceOf(address(multisig));
      // Balance is still the same
      assertEq(second_multisig_balance, INITIAL_MULTISIG_DAI_BALANCE);
    }

    function testWeightedExecution() public {
      // Game plan:

      // Give 2 $SNAKE to ALICE
      // Give 8 SNAKE to BOB
      // Set treshold to 50 % of the total weight
      // Show that ALICE can not execute something without BOB
      // Show that BOB can execute something without ALICE
      // Send 3 $SNAKE from BOB to ALICE so that both have 5
      // Show that ALICE can now execute something alone
      // Set treshold to 60 % of the total weight
      // Show that ALICE can not execute something without BOB
      // Show that BOB can not execute something without ALICE


      // Both owners have some $SNAKE now and the treshold is 50 % of the total weight
      assertEq(gov_token.balanceOf(ALICE), 2);
      assertEq(gov_token.balanceOf(BOB), 8);

      bytes memory data = pad_to_length(hex"a9059cbb00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001", DATA_LENGTH);
      vm.startPrank(ALICE);
      uint256 tx_id = multisig.submit_transaction(DAI, 0, data, 68);
      vm.stopPrank();
      // We did not send any DAI because ALICE can not execute txs without BOBS approval
      assertEq(IERC20(DAI).balanceOf(address(multisig)), INITIAL_MULTISIG_DAI_BALANCE);
      
      vm.startPrank(BOB);
      multisig.confirm_transaction(tx_id);
      // Now we executed the tx because BOB gave his approval
      assertEq(IERC20(DAI).balanceOf(address(multisig)), 9999);
      // Now BOB will try to send some DAI without ALICES approval
      tx_id = multisig.submit_transaction(DAI, 0, data, 68);
      // The tx was executed without ALICES approval because BOB controls 80 % of the voting power
      assertEq(IERC20(DAI).balanceOf(address(multisig)), 9998);
      // Now BOB will send 3 $SNAKE to ALICE so that both have 5
      gov_token.transfer(ALICE, 3);
      assertEq(gov_token.balanceOf(ALICE), 5);
      assertEq(gov_token.balanceOf(BOB), 5);

      // We still need to update the weights in the wallet to reflect the new balances.
      // BOB can still pull that off alone since the wallet still sees him as having 80 % of the voting power
      bytes memory update_weights = abi.encodeWithSelector(multisig.update_weights.selector);
      bytes memory padded_tx = pad_to_length(update_weights, DATA_LENGTH);
      tx_id = multisig.submit_transaction(address(multisig), 0, padded_tx, uint16(update_weights.length));
      vm.stopPrank();
      vm.startPrank(ALICE);
      // Now Alice tries again to send some DAI without Bobs approval
      tx_id = multisig.submit_transaction(DAI, 0, data, 68);
      // This time the tx did go through because both have 50 % of the voting power and can execute txs alone
      assertEq(IERC20(DAI).balanceOf(address(multisig)), 9997);

      // Now we will set the treshold to 60 % of the total weight. Alice can do that alone.
      bytes memory change_quorum = abi.encodeWithSelector(multisig.change_quorum.selector, 51);
      padded_tx = pad_to_length(change_quorum, DATA_LENGTH);
      tx_id = multisig.submit_transaction(address(multisig), 0, padded_tx, uint16(change_quorum.length));

      // Now Alice tries again to send some DAI without Bobs approval
      tx_id = multisig.submit_transaction(DAI, 0, data, 68);
      // This time the tx did NOT go through because the quorum is at 60 %
      assertEq(IERC20(DAI).balanceOf(address(multisig)), 9997);
      vm.stopPrank();
      vm.startPrank(BOB);
      // Now Bob confirms the tx and it goes through
      multisig.confirm_transaction(tx_id);
      assertEq(IERC20(DAI).balanceOf(address(multisig)), 9996);
    }

}
