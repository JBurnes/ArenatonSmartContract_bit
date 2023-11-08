// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

// import "@openzeppelin/contracts/access/AccessControl.sol";

contract USDT is ERC20 {
    uint256 private _InitialSupply;

    constructor() ERC20('USDT Token', 'USDT') {
        _InitialSupply = 1000000000 * 10 ** decimals();
        _mint(msg.sender, _InitialSupply); // Initial supply
    }

    function decimals() public view virtual override returns (uint8) {
        return 6;
    }
}
