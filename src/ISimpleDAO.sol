// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
pragma abicoder v2;

struct Payout {
    address to;
    uint256 amount;
}

interface ISimpleDAO {
    function execute(address destination, uint256 value, bytes memory data, uint16 length) external;
    function execute_transaction(uint256 tx_id) external;
    function confirm_transaction(uint256 tx_id) external;
    function revoke_confirmation(uint256 tx_id) external;
    function submit_transaction(address destination, uint256 value, bytes memory data, uint16 length) external returns (uint256);
    function add_owner(address owner) external;
    function get_owners() external view returns (address[50] memory);
    function get_confirmations(uint256 tx_id) external view returns (address[50] memory);
    function get_weight(address owner) external view returns (uint256);
    function get_total_weight() external view returns (uint256);
    function set_governance_token(address token) external;
    function distribute_governance_token(Payout[10] memory owners) external;
}


