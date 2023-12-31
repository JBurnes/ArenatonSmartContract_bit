// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IATON {
    function burned() external view returns (uint256);

    function burnFrom(uint256 _burnAmount) external returns (bool);

    function calculateFactorAton() external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}
