// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
pragma abicoder v2;

struct OwnerWeight {
    address owner;
    uint256 weight;
}

interface ISimpleDAO {
    function initialize(OwnerWeight[10] memory owners, uint256 required, address gov_token) external;
    function execute(address destination, uint256 value, bytes memory data, uint16 length) external;
    function execute_transaction(uint256 tx_id) external;
    function confirm_transaction(uint256 tx_id) external;
    function revoke_confirmation(uint256 tx_id) external;
    function submit_transaction(address destination, uint256 value, bytes memory data, uint16 length) external returns (uint256);
    function add_owner(address owner, uint256 distribute_amount) external;
    function get_owners() external view returns (address[10] memory);
    function get_confirmations(uint256 tx_id) external view returns (address[10] memory);
    function get_weight(address owner) external view returns (uint256);
    function get_total_weight() external view returns (uint256);
    function distribute_governance_token(OwnerWeight[10] memory owners, uint256 required_percentage) external;
    function update_weights() external;
    function change_quorum(uint256 quorum_pct) external;
}


