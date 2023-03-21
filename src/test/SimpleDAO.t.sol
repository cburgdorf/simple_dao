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
address constant FIRST_OWNER = 0x627306090abaB3A6e1400e9345bC60c78a8BEf57;
address constant SECOND_OWNER = 0x527306090ABaB3a6e1400e9345BC60C78A8Bef57;
address constant ZERO_ADDRESS = 0x0000000000000000000000000000000000000000;

contract SimpleDAOTest is Test {

    // We have to declare the events that we want add assertions for
    event Confirmation(address indexed owner, uint indexed tx_id);
    event Revocation(address indexed owner, uint indexed tx_id);
    event Submission(uint indexed tx_id);
    event Execution(uint indexed tx_id);
    event ExecutionFailure(uint indexed tx_id);
    event OwnerAddition(address indexed owner);
    event OwnerRemoval(address indexed owner);

    string[] scratchpad;

    ISimpleDAO public multisig;
    IERC20 public gov_token;

    function setUp() public {
        Fe.compileIngot("simpledao");
        address[50] memory owners;
        owners[0] = FIRST_OWNER;
        owners[1] = SECOND_OWNER;
        multisig = ISimpleDAO(Fe.deployContract("SimpleDAO", abi.encode(owners, 2)));
        gov_token = IERC20(Fe.deployContract("SnakeToken", abi.encode(address(multisig), 100_000)));
        // We gave 100_000 $SNAKE to the multisig contract but it is not yet distributed to any owner
        assertEq(gov_token.balanceOf(address(multisig)), 100_000);
    }

    function testCannotCallAddOwner() public {
      vm.expectRevert();
      multisig.add_owner(BINANCE_ACCOUNT);
    }

    function testAddAndRemoveOwner() public {
      bytes memory data = pad_to_length(hex"4a75e74100000000000000000000000028c6c06298d514db089934071355e5743bf21d60", DATA_LENGTH);
      vm.startPrank(FIRST_OWNER);
      address[50] memory existing_owners = multisig.get_owners();
      assertEq(existing_owners[0], FIRST_OWNER);
      assertEq(existing_owners[1], SECOND_OWNER);
      assertEq(existing_owners[2], ZERO_ADDRESS);
      assertEq(multisig.get_weight(FIRST_OWNER), 1);
      assertEq(multisig.get_weight(SECOND_OWNER), 1);
      assertEq(multisig.get_weight(ZERO_ADDRESS), 0);
      assertEq(multisig.get_total_weight(), 2);

      uint256 tx_id = multisig.submit_transaction(address(multisig), 0, data, 36);
      vm.stopPrank();

      vm.expectEmit(true, true, true, true);
      emit OwnerAddition(BINANCE_ACCOUNT);

      vm.startPrank(SECOND_OWNER);
      multisig.confirm_transaction(tx_id);

      address[50] memory new_owners = multisig.get_owners();
      assertEq(new_owners[0], FIRST_OWNER);
      assertEq(new_owners[1], SECOND_OWNER);
      assertEq(new_owners[2], BINANCE_ACCOUNT);
      assertEq(multisig.get_weight(FIRST_OWNER), 1);
      assertEq(multisig.get_weight(SECOND_OWNER), 1);
      assertEq(multisig.get_weight(BINANCE_ACCOUNT), 1);
      assertEq(multisig.get_weight(ZERO_ADDRESS), 0);
      assertEq(multisig.get_total_weight(), 3);

      bytes memory data_removal = pad_to_length(hex"f6b9571a00000000000000000000000028c6c06298d514db089934071355e5743bf21d60", DATA_LENGTH);
      uint256 tx2_id = multisig.submit_transaction(address(multisig), 0, data_removal, 36);
      vm.stopPrank();

      vm.startPrank(FIRST_OWNER);
      vm.expectEmit(true, true, true, true);
      emit OwnerRemoval(BINANCE_ACCOUNT);

      multisig.confirm_transaction(tx2_id);
      assertEq(existing_owners[0], FIRST_OWNER);
      assertEq(existing_owners[1], SECOND_OWNER);
      assertEq(existing_owners[2], ZERO_ADDRESS);
      assertEq(multisig.get_weight(FIRST_OWNER), 1);
      assertEq(multisig.get_weight(SECOND_OWNER), 1);
      assertEq(multisig.get_weight(BINANCE_ACCOUNT), 0);
      assertEq(multisig.get_weight(ZERO_ADDRESS), 0);
      assertEq(multisig.get_total_weight(), 2);
    }

    function testReplaceOwner() public {
      bytes memory data = pad_to_length(hex"f097d1de000000000000000000000000527306090abab3a6e1400e9345bc60c78a8bef5700000000000000000000000028c6c06298d514db089934071355e5743bf21d60", DATA_LENGTH);
      vm.startPrank(FIRST_OWNER);
      address[50] memory existing_owners = multisig.get_owners();
      assertEq(existing_owners[0], FIRST_OWNER);
      assertEq(existing_owners[1], SECOND_OWNER);
      assertEq(existing_owners[2], ZERO_ADDRESS);

      uint256 tx_id = multisig.submit_transaction(address(multisig), 0, data, 68);
      vm.stopPrank();

      vm.expectEmit(true, true, true, true);
      emit OwnerRemoval(SECOND_OWNER);
      emit OwnerAddition(BINANCE_ACCOUNT);

      vm.startPrank(SECOND_OWNER);
      multisig.confirm_transaction(tx_id);

      address[50] memory new_owners = multisig.get_owners();
      assertEq(new_owners[0], FIRST_OWNER);
      assertEq(new_owners[1], BINANCE_ACCOUNT);
      assertEq(new_owners[2], ZERO_ADDRESS);
    }

    function testSubmit() public {
      // Send some DAI to the 0x0 address
      bytes memory data = pad_to_length(hex"a9059cbb00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001", DATA_LENGTH);
      vm.startPrank(FIRST_OWNER);
      vm.expectEmit(true, true, true, true);
      uint256 tx_id = multisig.submit_transaction(DAI, 0, data, 68);
      emit Submission(tx_id);
      assertEq(tx_id, 0);
      vm.expectEmit(true, true, true, true);
      uint256 second_tx_id = multisig.submit_transaction(DAI, 0, data, 68);
      emit Submission(second_tx_id);
      assertEq(second_tx_id, 1);
    }

    function testRevoke() public {
      // Send some DAI to the 0x0 address
      bytes memory data = pad_to_length(hex"a9059cbb00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001", DATA_LENGTH);
      vm.startPrank(FIRST_OWNER);
      uint256 tx_id = multisig.submit_transaction(DAI, 0, data, 68);
      address[50] memory confirmations_1 = multisig.get_confirmations(tx_id);
      assertEq(confirmations_1[0], FIRST_OWNER);
      vm.expectEmit(true, true, true, true);
      multisig.revoke_confirmation(tx_id);
      emit Revocation(FIRST_OWNER, tx_id);
      address[50] memory confirmations_2 = multisig.get_confirmations(tx_id);
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

      address multisig_address = address(multisig);
      vm.startPrank(BINANCE_ACCOUNT);
      IERC20(DAI).transfer(address(multisig), 10000);
      uint256 initial_multisig_balance = IERC20(DAI).balanceOf(multisig_address);

      vm.expectEmit(true, true, true, true);
      emit Confirmation(FIRST_OWNER, 0);
      vm.stopPrank();
      vm.startPrank(FIRST_OWNER);
      uint256 tx_id = multisig.submit_transaction(DAI, 0, data, 68);

      address[50] memory confirmations_1 = multisig.get_confirmations(tx_id);
      assertEq(confirmations_1[0], FIRST_OWNER);
      assertEq(confirmations_1[1], ZERO_ADDRESS);

      vm.expectEmit(true, true, true, true);
      emit Confirmation(SECOND_OWNER, 0);
      vm.expectEmit(true, true, true, true);
      emit Execution(tx_id);
      vm.stopPrank();
      vm.startPrank(SECOND_OWNER);
      multisig.confirm_transaction(tx_id);
      address[50] memory confirmations_2 = multisig.get_confirmations(tx_id);
      assertEq(confirmations_2[0], FIRST_OWNER);
      assertEq(confirmations_2[1], SECOND_OWNER);
      assertEq(confirmations_2[2], ZERO_ADDRESS);

      uint256 second_multisig_balance = IERC20(DAI).balanceOf(multisig_address);
      assertEq(second_multisig_balance, initial_multisig_balance - 1);

    }

    function testExecutionFails() public {
      bytes memory data = pad_to_length(hex"a9059cbb00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001", DATA_LENGTH);

      address multisig_address = address(multisig);
      vm.startPrank(BINANCE_ACCOUNT);
      IERC20(DAI).transfer(address(multisig), 10000);
      uint256 initial_multisig_balance = IERC20(DAI).balanceOf(multisig_address);

      vm.expectEmit(true, true, true, true);
      emit Confirmation(FIRST_OWNER, 0);
      vm.stopPrank();
      vm.startPrank(FIRST_OWNER);
      uint256 tx_id = multisig.submit_transaction(DAI, 0, data, 50); // intentionally use a too small data_length

      address[50] memory confirmations_1 = multisig.get_confirmations(tx_id);
      assertEq(confirmations_1[0], FIRST_OWNER);
      assertEq(confirmations_1[1], ZERO_ADDRESS);

      vm.expectEmit(true, true, true, true);
      emit Confirmation(SECOND_OWNER, 0);
      vm.expectEmit(true, true, true, true);
      emit ExecutionFailure(tx_id);
      vm.stopPrank();
      vm.startPrank(SECOND_OWNER);
      multisig.confirm_transaction(tx_id);
      address[50] memory confirmations_2 = multisig.get_confirmations(tx_id);
      assertEq(confirmations_2[0], FIRST_OWNER);
      assertEq(confirmations_2[1], SECOND_OWNER);
      assertEq(confirmations_2[2], ZERO_ADDRESS);

      uint256 second_multisig_balance = IERC20(DAI).balanceOf(multisig_address);
      assertEq(second_multisig_balance, initial_multisig_balance);
    }

    function testCanNotExecuteUnconfirmedTx() public {
      bytes memory data = pad_to_length(hex"a9059cbb00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001", DATA_LENGTH);

      address multisig_address = address(multisig);
      vm.startPrank(BINANCE_ACCOUNT);
      IERC20(DAI).transfer(address(multisig), 10000);
      uint256 initial_multisig_balance = IERC20(DAI).balanceOf(multisig_address);

      vm.expectEmit(true, true, true, true);
      emit Confirmation(FIRST_OWNER, 0);

      vm.stopPrank();
      vm.startPrank(FIRST_OWNER);
      uint256 tx_id = multisig.submit_transaction(DAI, 0, data, 68);

      multisig.execute_transaction(tx_id);
      uint256 second_multisig_balance = IERC20(DAI).balanceOf(multisig_address);
      // Balance is still the same
      assertEq(second_multisig_balance, initial_multisig_balance);
    }

    function testWeightedExecution() public {
      // Game plan:

      // Give 2 $SNAKE to FIRST_OWNER
      // Give 8 SNAKE to SECOND_OWNER
      // Set treshold to 50 % of the total weight
      // Show that FIRST OWNER can not execute something without SECOND_OWNER
      // Show that SECOND OWNER can execute something without FIRST OWNER
      // Send 3 $SNAKE from SECOND Owner to FIRST OWNER so that both have 5
      // Show that FIRST OWNER can now execute something alone
      // Set treshold to 60 % of the total weight
      // Show that FIRST OWNER can not execute something without SECOND_OWNER
      // Show that SECOND OWNER can not execute something without FIRST OWNER


      scratchpad = ["cast", "calldata", "set_governance_token(address)", Strings.toHexString(address(gov_token))];
      bytes memory set_gov_token_tx = vm.ffi(scratchpad);
      bytes memory padded_tx = pad_to_length(set_gov_token_tx, DATA_LENGTH);

      vm.startPrank(FIRST_OWNER);
      uint256 tx_id = multisig.submit_transaction(address(multisig), 0, padded_tx, uint16(set_gov_token_tx.length));
      
      vm.stopPrank();
      vm.startPrank(SECOND_OWNER);
      multisig.confirm_transaction(tx_id);

      scratchpad = ["cast", "calldata", "distribute_governance_token((address,uint256)[10])", "[(0x627306090abaB3A6e1400e9345bC60c78a8BEf57,2),(0x527306090ABaB3a6e1400e9345BC60C78A8Bef57,8),(0x0000000000000000000000000000000000000000,0),(0x0000000000000000000000000000000000000000,0),(0x0000000000000000000000000000000000000000,0),(0x0000000000000000000000000000000000000000,0),(0x0000000000000000000000000000000000000000,0),(0x0000000000000000000000000000000000000000,0),(0x0000000000000000000000000000000000000000,0),(0x0000000000000000000000000000000000000000,0)]"];
      bytes memory distribute_gov_token_tx = vm.ffi(scratchpad);
      padded_tx = pad_to_length(distribute_gov_token_tx, DATA_LENGTH);
      tx_id = multisig.submit_transaction(address(multisig), 0, padded_tx, uint16(distribute_gov_token_tx.length));
      vm.stopPrank();
      vm.startPrank(FIRST_OWNER);
      multisig.confirm_transaction(tx_id);

//0xFEfC6BAF87cF3684058D62Da40Ff3A795946Ab06::412a30d4(00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000002000000000000000000000000627306090abab3a6e1400e9345bc60c78a8bef570000000000000000000000000000000000000000000000000000000000000002000000000000000000000000527306090abab3a6e1400e9345bc60c78a8bef570000000000000000000000000000000000000000000000000000000000000008)

      // vm.stopPrank();
      // vm.startPrank(address(multisig));
      // Payout[2] memory pay = [Payout(0x627306090abaB3A6e1400e9345bC60c78a8BEf57,2),Payout(0x527306090ABaB3a6e1400e9345BC60C78A8Bef57,8)];
      // multisig.distribute_governance_token(pay);
      // TODO: Distribution doesn't seem to happen.
      assertEq(gov_token.balanceOf(FIRST_OWNER), 2);


      //assertEq(res, hex"e6b83d14000000000000000000000000627306090abab3a6e1400e9345bc60c78a8bef57");
      
      
      //string memory output = abi.decode(res, (string));
      //assertEq(output, "0xe6b83d14000000000000000000000000627306090abab3a6e1400e9345bc60c78a8bef57");



      // Payout[50] memory initial_distribution;
      // initial_distribution[0] = Payout(FIRST_OWNER, 2);
      // initial_distribution[1] = Payout(SECOND_OWNER, 8);
      
      // bytes memory data = pad_to_length(hex"4a75e74100000000000000000000000028c6c06298d514db089934071355e5743bf21d60", DATA_LENGTH);
      // vm.startPrank(FIRST_OWNER);
      // address[50] memory existing_owners = multisig.get_owners();
      // assertEq(existing_owners[0], FIRST_OWNER);
      // assertEq(existing_owners[1], SECOND_OWNER);
      // assertEq(existing_owners[2], ZERO_ADDRESS);
      // assertEq(multisig.get_weight(FIRST_OWNER), 1);
      // assertEq(multisig.get_weight(SECOND_OWNER), 1);
      // assertEq(multisig.get_weight(ZERO_ADDRESS), 0);
      // assertEq(multisig.get_total_weight(), 2);

      // uint256 tx_id = multisig.submit_transaction(address(multisig), 0, data, 36);
      // vm.stopPrank();

      // vm.expectEmit(true, true, true, true);
      // emit OwnerAddition(BINANCE_ACCOUNT);

      // vm.startPrank(SECOND_OWNER);
      // multisig.confirm_transaction(tx_id);

      // address[50] memory new_owners = multisig.get_owners();
      // assertEq(new_owners[0], FIRST_OWNER);
      // assertEq(new_owners[1], SECOND_OWNER);
      // assertEq(new_owners[2], BINANCE_ACCOUNT);
      // assertEq(multisig.get_weight(FIRST_OWNER), 1);
      // assertEq(multisig.get_weight(SECOND_OWNER), 1);
      // assertEq(multisig.get_weight(BINANCE_ACCOUNT), 1);
      // assertEq(multisig.get_weight(ZERO_ADDRESS), 0);
      // assertEq(multisig.get_total_weight(), 3);

      // bytes memory data_removal = pad_to_length(hex"f6b9571a00000000000000000000000028c6c06298d514db089934071355e5743bf21d60", DATA_LENGTH);
      // uint256 tx2_id = multisig.submit_transaction(address(multisig), 0, data_removal, 36);
      // vm.stopPrank();

      // vm.startPrank(FIRST_OWNER);
      // vm.expectEmit(true, true, true, true);
      // emit OwnerRemoval(BINANCE_ACCOUNT);

      // multisig.confirm_transaction(tx2_id);
      // assertEq(existing_owners[0], FIRST_OWNER);
      // assertEq(existing_owners[1], SECOND_OWNER);
      // assertEq(existing_owners[2], ZERO_ADDRESS);
      // assertEq(multisig.get_weight(FIRST_OWNER), 1);
      // assertEq(multisig.get_weight(SECOND_OWNER), 1);
      // assertEq(multisig.get_weight(BINANCE_ACCOUNT), 0);
      // assertEq(multisig.get_weight(ZERO_ADDRESS), 0);
      // assertEq(multisig.get_total_weight(), 2);
    }

}
