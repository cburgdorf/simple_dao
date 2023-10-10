// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;
pragma abicoder v2;

uint16 constant DATA_LENGTH = 1024;

function pad_to_length(bytes memory data, uint256 length) pure returns (bytes memory) {
    bytes memory padded_data = new bytes(length);
    for (uint256 i = 0; i < data.length; i++) {
        padded_data[i] = data[i];
    }
    return padded_data;
}