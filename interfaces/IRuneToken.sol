// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IRuneToken {
    function totalSupply(uint256 id) external returns (uint256);

    function balanceOf(address account, uint256 id) external returns (uint256);

    function batchMint(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) external;
}
