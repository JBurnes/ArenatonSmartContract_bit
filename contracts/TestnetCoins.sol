// SPDX-License-Identifier: LicenseRef-Proprietary

pragma solidity ^0.8.9;
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import './interfaces/IATON.sol';
import './interfaces/IVAULT.sol';
import './libraries/AStructs.sol';
import './libraries/Tools.sol';
import '@openzeppelin/contracts/access/AccessControl.sol';
import 'prb-math/contracts/PRBMathSD59x18.sol';
import '@chainlink/contracts/src/v0.8/ConfirmedOwner.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';

// Define the Arenaton contract
contract TestnetCoins is ReentrancyGuard {
    // Contract owner's address
    address owner;

    // Mapping to track whether a player claimed their free USDC USDT or DAI (TESTNET ONLY)
    mapping(address => bool) private freeUSDC;
    mapping(address => bool) private freeUSDT;
    mapping(address => bool) private freeDAI;

    address private constant USDC = 0x3019248e35D84f63fe992070db66Bb49C56CA67d;
    address private constant USDT = 0x6E40eD8F8d88c09ba6Adc3Fe585CCC2d0800D4e8;
    address private constant DAI = 0x8b4A7e23c39Ef39f2ab1215D6648ce4B93E92D17;

    // Constructor for the Arenaton contract
    constructor() {
        owner = msg.sender;
    }

    /**
     * @notice Allows a user to claim free USDC tokens. This function ensures that the user hasn't already claimed free USDC.
     */
    function getFreeUSDC() external nonReentrant {
        require(!freeUSDC[msg.sender], 'Player already claimed free USDC'); // Ensure the user hasn't claimed USDC yet.
        IERC20(USDC).transfer(msg.sender, 100000000); // Transfer 1 billion USDC to the user.
        freeUSDC[msg.sender] = true; // Mark that the user has claimed their free USDC.
    }

    /**
     * @notice Allows a user to claim free USDT tokens. This function ensures that the user hasn't already claimed free USDT.
     */
    function getFreeUSDT() external nonReentrant {
        require(!freeUSDT[msg.sender], 'Player already claimed free USDT'); // Ensure the user hasn't claimed USDT yet.
        IERC20(USDT).transfer(msg.sender, 100000000); // Transfer 1 billion USDT to the user.
        freeUSDT[msg.sender] = true; // Mark that the user has claimed their free USDT.
    }

    /**
     * @notice Allows a user to claim free DAI tokens. This function ensures that the user hasn't already claimed free DAI.
     */
    function getFreeDAI() external nonReentrant {
        require(!freeDAI[msg.sender], 'Player already claimed free DAI'); // Ensure the user hasn't claimed DAI yet.
        IERC20(DAI).transfer(msg.sender, 100000000000000000000); // Transfer 1 billion DAI (18 decimals) to the user.
        freeDAI[msg.sender] = true; // Mark that the user has claimed their free DAI.
    }

    /**
     * @notice Checks if the calling user has already claimed their free USDC.
     * @return True if the user has claimed USDC, otherwise false.
     */
    function isPlayerFreeUSDC() external view returns (bool) {
        return freeUSDC[msg.sender];
    }

    /**
     * @notice Checks if the calling user has already claimed their free USDT.
     * @return True if the user has claimed USDT, otherwise false.
     */
    function isPlayerFreeUSDT() external view returns (bool) {
        return freeUSDT[msg.sender];
    }

    /**
     * @notice Checks if the calling user has already claimed their free DAI.
     * @return True if the user has claimed DAI, otherwise false.
     */
    function isPlayerFreeDAI() external view returns (bool) {
        return freeDAI[msg.sender];
    }

    /**
     * @dev Retrieves the owner's address.
     * @return The owner's address.
     */
    function getOwner() external view returns (address) {
        return owner;
    }
}
