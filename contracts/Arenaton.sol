// SPDX-License-Identifier: LicenseRef-Proprietary

pragma solidity ^0.8.9;
// import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import './interfaces/IATON.sol';
import './interfaces/IVAULT.sol';
import '@openzeppelin/contracts/access/AccessControl.sol';
import './interfaces/IPVT.sol';
// import '@openzeppelin/contracts/token/ERC721/IERC721.sol';

import './libraries/AStructs.sol';
import './libraries/Tools.sol';
import 'prb-math/contracts/PRBMathSD59x18.sol';
import '@chainlink/contracts/src/v0.8/ConfirmedOwner.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import './libraries/NFTcategories.sol';

// Define the Arenaton contract
contract Arenaton is AccessControl, ReentrancyGuard {
    // Role for authorized oracles
    bytes32 constant ORACLE_ROLE = keccak256('ORACLE_ROLE');

    // Reference to the VAULT contract
    IVAULT internal VAULT;
    IATON internal ATON;

    // Reference to the  NFT Collection contract
    address public PVT;

    // Arrays to store oracle open and close requests
    AStructs.OracleOpenRequest[] public oracleOpenRequests;
    AStructs.OracleCloseRequest[] public oracleCloseRequests;

    // Contract owner's address
    address owner;

    // Represents the premium percentage, set to 2% (2% * 10^8 = 200000 for precision)
    uint256 public constant premium = 200000;
    // Denominator used for percentage calculations to accommodate decimals
    uint256 public constant pct_denom = 10000000;

    // Constructor for the Arenaton contract
    constructor(address _VAULT, address _ATON) {
        VAULT = IVAULT(_VAULT);
        ATON = IATON(_ATON);
        owner = msg.sender;
        // Grant DEFAULT_ADMIN_ROLE to the contract deployer
        _grantRole(DEFAULT_ADMIN_ROLE, owner);
    }

    /**
     * @dev Adds an authorized oracle address with the ORACLE_ROLE.
     * @param authorizedAddress The address to be granted ORACLE_ROLE.
     * Only callable by the contract owner (DEFAULT_ADMIN_ROLE).
     */
    function addAuthorizedOracleAddress(address authorizedAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(ORACLE_ROLE, authorizedAddress);
    }

    /**
     * @dev Removes an authorized oracle address with the ORACLE_ROLE.
     * @param authorizedAddress The address to have ORACLE_ROLE revoked.
     * Only callable by the contract owner (DEFAULT_ADMIN_ROLE).
     */
    function removeAuthorizedAddress(address authorizedAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(ORACLE_ROLE, authorizedAddress);
    }

    /**
     * @dev Retrieves the owner's address.
     * @return The owner's address.
     */
    function getOwner() external view returns (address) {
        return owner;
    }

    /**
     * @dev Retrieves active events for a given sport.
     * @param _sport The sport for which active events are requested.
     * @return An array of EventDTO structs representing active events.
     */
    function getActiveEvents(int8 _sport) external view returns (AStructs.EventDTO[] memory) {
        return VAULT.getActiveEvents(_sport);
    }

    /**
     * @notice Sets the address for the PVT.
     * @dev Allows an administrator to set or update the PVT's address.
     * The caller of this function must have the `DEFAULT_ADMIN_ROLE` role.
     * @param _PVT The Ethereum address representing the new PVT contract.
     */
    function setPVT(address _PVT) external onlyRole(DEFAULT_ADMIN_ROLE) {
        PVT = _PVT;
    }

    // ORACLE SECTION //////////////////////////////////////////////////////////////////////////
    /**
     * @dev Retrieves Oracle open requests along with associated event details.
     * @return An array of OracleOpenRequestDTO structs representing open requests.
     */
    function getOracleOpenRequests() external view returns (AStructs.OracleOpenRequestDTO[] memory) {
        AStructs.OracleOpenRequestDTO[] memory requestsDTO = new AStructs.OracleOpenRequestDTO[](oracleOpenRequests.length);
        for (uint256 i = 0; i < oracleOpenRequests.length; i++) {
            AStructs.EventDTO memory eventDTO = VAULT.getEventDTO(oracleOpenRequests[i].eventIdBytes);

            AStructs.OracleOpenRequestDTO memory request = AStructs.OracleOpenRequestDTO(
                Tools._bytes8ToString(oracleOpenRequests[i].eventIdBytes),
                eventDTO.active,
                eventDTO.startDate,
                oracleOpenRequests[i].time
            );
            requestsDTO[i] = request;
        }
        return requestsDTO;
    }

    /**
     * @dev Retrieves Oracle open requests along with associated event details.
     * @param eventIdBytes The unique identifier of the event.
     * @return true if there are Oracle open requests for the specified event, false otherwise.
     */
    function _hasOracleOpenRequests(bytes8 eventIdBytes) internal view returns (bool) {
        // Iterate through the oracleOpenRequests array
        for (uint256 i = 0; i < oracleOpenRequests.length; i++) {
            // Check if the eventIdBytes matches the current request's eventIdBytes
            if (oracleOpenRequests[i].eventIdBytes == eventIdBytes) {
                return true; // If a match is found, return true
            }
        }
        return false; // If no match is found, return false
    }

    /**
     * @dev Retrieves Oracle close requests along with associated event details.
     * @return An array of OracleOpenRequestDTO structs representing close requests.
     */
    function getOracleCloseRequests() external view returns (AStructs.OracleOpenRequestDTO[] memory) {
        AStructs.OracleOpenRequestDTO[] memory requestsDTO = new AStructs.OracleOpenRequestDTO[](oracleCloseRequests.length);
        for (uint256 i = 0; i < oracleCloseRequests.length; i++) {
            AStructs.EventDTO memory eventDTO = VAULT.getEventDTO(oracleCloseRequests[i].eventIdBytes);

            AStructs.OracleOpenRequestDTO memory request = AStructs.OracleOpenRequestDTO(
                Tools._bytes8ToString(oracleCloseRequests[i].eventIdBytes),
                eventDTO.active,
                eventDTO.startDate,
                oracleCloseRequests[i].time
            );
            requestsDTO[i] = request;
        }
        return requestsDTO;
    }

    /**
     * @dev Retrieves Oracle Close requests along with associated event details.
     * @param eventIdBytes The unique identifier of the event.
     * @return true if there are Oracle Close requests for the specified event, false otherwise.
     */
    function _hasOracleCloseRequests(bytes8 eventIdBytes) internal view returns (bool) {
        // Iterate through the oracleCloseRequests array
        for (uint256 i = 0; i < oracleCloseRequests.length; i++) {
            // Check if the eventIdBytes matches the current request's eventIdBytes
            if (oracleCloseRequests[i].eventIdBytes == eventIdBytes) {
                return true; // If a match is found, return true
            }
        }
        return false; // If no match is found, return false
    }

    /**
     * @dev Adds an Oracle open request for a specific event and stake details.
     * @param _eventId The unique identifier of the event.
     * @param _amountCoinIn The amount of VUND staked from the player's wallet.
     * @param _coinAddress The amount of VUND staked from the player's vault.
     * @param _amountATON The amount of ATON staked from the player's wallet.
     * @param _team The team for which the stake is being made.
     */
    function addOracleOpenRequest(
        string memory _eventId,
        uint256 _amountCoinIn,
        address _coinAddress,
        uint256 _amountATON,
        uint8 _team
    ) external {
        // Ensure the Event has not started yet and is still active
        bytes8 eventIdBytes = Tools._stringToBytes8(_eventId);
        address player = msg.sender;

        (uint256 amountVUND, ) = VAULT.convertCoinToVUND(_coinAddress, _amountCoinIn);

        // Check minimum stake requirement
        require(amountVUND >= 10 ** 18, 'Minimum Stake amount not reached');

        // Check approved VUND and ATON allowances
        require(ERC20(_coinAddress).allowance(msg.sender, address(VAULT)) >= _amountCoinIn, 'Not Enough COIN approved');
        require(ATON.allowance(msg.sender, address(VAULT)) >= _amountATON, 'Not Enough ATON approved');

        // Check wallet balances
        require(ERC20(_coinAddress).balanceOf(msg.sender) >= _amountCoinIn, 'Not Enough COIN Balance in Wallet');
        require(ATON.balanceOf(msg.sender) >= _amountATON, 'Not Enough ATON Balance in Wallet');

        // Check vault balances

        // Create a new OracleOpenRequest struct
        AStructs.OracleOpenRequest memory request = AStructs.OracleOpenRequest(
            eventIdBytes,
            player,
            _amountCoinIn,
            _coinAddress,
            _amountATON,
            _team,
            block.timestamp
        );

        // Loop to find and replace or push the request
        uint256 index = oracleOpenRequests.length;
        for (uint256 i = 0; i < oracleOpenRequests.length; i++) {
            if (oracleOpenRequests[i].eventIdBytes == eventIdBytes) {
                index = i;
                break;
            }
        }

        // If the Event is not found, add the request; otherwise, replace it
        if (index >= oracleOpenRequests.length) {
            oracleOpenRequests.push(request);
        } else {
            oracleOpenRequests[index] = request;
        }
    }

    /**
     * @dev Adds an Oracle close request for a specific event.
     * @param _eventId The unique identifier of the event.
     */
    function addOracleCloseRequest(string memory _eventId) external {
        // Ensure the Event has not started yet and is still active
        bytes8 eventIdBytes = Tools._stringToBytes8(_eventId);
        AStructs.EventDTO memory eventInfo = VAULT.getEventDTO(eventIdBytes);
        // console.log('block.timestamp', block.timestamp);
        require(eventInfo.startDate < block.timestamp, 'Event has not started yet');

        // Check if the event is active and not already closed
        require(eventInfo.active, 'Event already Closed');
        address player = msg.sender;

        // Create a new OracleCloseRequest struct
        AStructs.OracleCloseRequest memory request = AStructs.OracleCloseRequest(eventIdBytes, player, block.timestamp);

        // Check if the request is not already added
        bool isAdded = false;
        for (uint256 i = 0; i < oracleCloseRequests.length; i++) {
            if (oracleCloseRequests[i].eventIdBytes == eventIdBytes) {
                isAdded = true;
                break;
            }
        }
        require(!isAdded, 'Close Request already Added');

        // Add the OracleCloseRequest to the array
        oracleCloseRequests.push(request);
    }

    ///////////////////////////////////////// FULLFILL
    /**
     * @dev Fulfills an Oracle open request by adding an event and processing the stake.
     * @param _eventId The unique identifier of the event.
     * @param _startDate The start date of the event.
     * @param _sport The sport of the event.
     */
    function fullfillOpenRequest(string memory _eventId, uint64 _startDate, uint8 _sport) external onlyRole(ORACLE_ROLE) {
        bytes8 eventIdBytes = Tools._stringToBytes8(_eventId);

        // Find the index of the Oracle open request for the specified event
        uint256 index = oracleOpenRequests.length;
        for (uint256 i = 0; i < oracleOpenRequests.length; i++) {
            if (oracleOpenRequests[i].eventIdBytes == eventIdBytes) {
                index = i;
                break;
            }
        }

        // Check if the Oracle open request exists
        require(index < oracleOpenRequests.length, 'Request for this event doesnt exist');

        // Get the Oracle open request details
        AStructs.OracleOpenRequest memory request = oracleOpenRequests[index];

        // Add the event
        VAULT.addEvent(request.eventIdBytes, _startDate, _sport, request.requester);

        _newStake(request.eventIdBytes, request.amountCoin, request.coinAddress, request.amountATON, request.team, request.requester);
        (uint256 vundAmount, ) = VAULT.convertCoinToVUND(request.coinAddress, request.amountCoin);

        // Calculate and pay rewards
        // OpenEventReward
        uint256 bonusNFT = pct_denom + _BonusNFT(request.requester, _sport);

        uint256 rewardsATON = _getVUNDtoATON((vundAmount * 2000000 * bonusNFT) / (pct_denom * pct_denom));
        // console.log('requester ', request.requester);
        VAULT.addEarningsToPlayer(request.requester, 0, rewardsATON, eventIdBytes, AStructs.OpenEventReward);

        // Swap the Oracle open request to remove with the last request in the array and then pop (remove) the last element
        oracleOpenRequests[index] = oracleOpenRequests[oracleOpenRequests.length - 1];
        oracleOpenRequests.pop();
    }

    /**
     * @dev Fulfills an Oracle close request by closing an event and processing rewards.
     * @param _eventId The unique identifier of the event.
     * @param _winner The winner of the event.
     * @param _scoreA The score of team A.
     * @param _scoreB The score of team B.
     */
    function fullfillCloseRequest(string memory _eventId, int8 _winner, uint8 _scoreA, uint8 _scoreB) external onlyRole(ORACLE_ROLE) {
        bytes8 eventIdBytes = Tools._stringToBytes8(_eventId);

        // Find the index of the Oracle close request for the specified event
        uint256 index = oracleCloseRequests.length;
        for (uint256 i = 0; i < oracleCloseRequests.length; i++) {
            if (oracleCloseRequests[i].eventIdBytes == eventIdBytes) {
                index = i;
                break;
            }
        }

        // Check if the Oracle close request exists
        require(index < oracleCloseRequests.length, 'Request for this event doesnt exist');

        // Get the Oracle close request details
        AStructs.OracleCloseRequest memory request = oracleCloseRequests[index];

        // Close the event and process rewards
        _closeEvent(_eventId, _winner, _scoreA, _scoreB, request.requester);

        // Calculate and pay rewards 10 VUND in ATON
        uint256 rewardsATON = _getVUNDtoATON(10000000000000000000);
        VAULT.addEarningsToPlayer(request.requester, 0, rewardsATON, eventIdBytes, AStructs.CloseEventReward);

        // Swap the Oracle close request to remove with the last request in the array and then pop (remove) the last element
        oracleCloseRequests[index] = oracleCloseRequests[oracleCloseRequests.length - 1];
        oracleCloseRequests.pop();
    }

    /**
     * @dev Clears the arrays containing open and close oracle requests.
     *
     * Oracle requests are typically used to retrieve data from external sources.
     * This function removes all pending requests, both open and close, by popping
     * each entry from the arrays until they are empty.
     *
     * @return bool Returns `true` once both arrays are cleared.
     */
    function cleanOracleRequests() external onlyRole(DEFAULT_ADMIN_ROLE) returns (bool) {
        uint256 tenMinutesAgo = block.timestamp - 10 minutes;

        // Clear old entries from oracleOpenRequests
        for (uint256 i = 0; i < oracleOpenRequests.length; ) {
            if (oracleOpenRequests[i].time < tenMinutesAgo) {
                if (i != oracleOpenRequests.length - 1) {
                    oracleOpenRequests[i] = oracleOpenRequests[oracleOpenRequests.length - 1];
                }
                oracleOpenRequests.pop();
            } else {
                i++; // Only increment if no element was deleted
            }
        }

        // Clear old entries from oracleCloseRequests
        for (uint256 i = 0; i < oracleCloseRequests.length; ) {
            if (oracleCloseRequests[i].time < tenMinutesAgo) {
                if (i != oracleCloseRequests.length - 1) {
                    oracleCloseRequests[i] = oracleCloseRequests[oracleCloseRequests.length - 1];
                }
                oracleCloseRequests.pop();
            } else {
                i++; // Only increment if no element was deleted
            }
        }

        return true;
    }

    // STAKES SECTION //////////////////////////////////////////////////////////////////////////

    /**
     * @dev Retrieves the stake details for a player in a specific event.
     * @param _eventId The unique identifier of the event.
     * @return AStructs.StakeDTO The stake details for the player.
     */
    function getPlayerStake(string memory _eventId) external view returns (AStructs.StakeDTO memory) {
        bytes8 eventIdBytes = Tools._stringToBytes8(_eventId);

        return VAULT.getPlayerStake(eventIdBytes, msg.sender);
    }

    /**
     * @dev Retrieves the details of an event.
     * @param _eventId The unique identifier of the event.
     * @return AStructs.EventDTO The event details.
     */
    function getEventDTO(string memory _eventId) external view returns (AStructs.EventDTO memory) {
        bytes8 eventIdBytes = Tools._stringToBytes8(_eventId);

        // Retrieve event details from VAULT contract
        AStructs.EventDTO memory eventDTO = VAULT.getEventDTO(eventIdBytes);

        // Calculate Event State
        eventDTO.eventState = _calculateEventState(eventIdBytes, eventDTO);

        return eventDTO;
    }

    /**
     * @dev Retrieves the details of an event and calculates its current state.
     * @param _eventIdBytes The unique identifier of the event.
     * @param _eventDTO The data structure containing event details.
     * @return eventState The calculated state of the event.
     */
    function _calculateEventState(bytes8 _eventIdBytes, AStructs.EventDTO memory _eventDTO) internal view returns (uint8 eventState) {
        // Check if there are pending Oracle Open requests for the specified event
        if (_hasOracleOpenRequests(_eventIdBytes)) {
            return AStructs.OpenRequest; // Event state 1: Oracle Open Request Pending, Awaiting Oracle Transaction
        }

        // Check if there are pending Oracle Close requests for the specified event
        if (_hasOracleCloseRequests(_eventIdBytes)) {
            return AStructs.CloseRequest; // Event state 5: Oracle Close Request Pending, Awaiting Oracle Transaction
        }

        // Check if there are no stakes placed on the event
        if (_eventDTO.totalVUND_A + _eventDTO.totalVUND_B == 0) {
            return AStructs.NotInitialized; // Event state 0: No Stakes, Event hasn't received any stakes yet
        }

        // Check if the event is active and has started
        if (_eventDTO.active && block.timestamp < _eventDTO.startDate) {
            return AStructs.StakingOn; // Event state 2: Active and Started, Stake Period Ongoing
        }

        // Check if the event is active but has not started yet
        if (_eventDTO.active && block.timestamp >= _eventDTO.startDate) {
            return AStructs.Live; // Event state 3: Match Scheduled, Stake Period Not Yet Started
        }

        // Note: The Smart Contract cannot determine when the Sport Match finishes.
        // In the Web App, set eventState = 4 if (STAGE='FINISHED' or STAGE='CANCELLED') and eventState == 3.

        // Check if the player has not yet claimed rewards for the event
        if (!VAULT.isPlayerFinalizedEvent(_eventIdBytes, msg.sender)) {
            if (VAULT.getPlayerStake(_eventIdBytes, msg.sender).stakeVUND > 0) {
                return AStructs.RewardsPending; // Event state 6: Player Rewards Pending, Player can still claim rewards
            }
        }

        // Event state 7: Not Active and Player has already claimed rewards, Event cycle concluded
        return AStructs.Closed;
    }

    /**
     * @dev Retrieves the list of player addresses participating in a specific event.
     * @param _eventId The unique identifier of the event.
     * @return address[] The list of player addresses.
     */
    function EventPlayers(string memory _eventId) external view returns (address[] memory) {
        bytes8 eventIdBytes = Tools._stringToBytes8(_eventId);

        return VAULT.getEventPlayers(eventIdBytes);
    }

    /**
     * @dev Creates a new stake on an event.
     * @param _eventId The unique identifier of the event.
     * @param _amountCoinIn Amount of VUND staked.
     * @param _coinAddress Address of the coin being staked.
     * @param _amountATON Amount of ATON staked from the player's wallet.
     * @param _team Chosen team for the stake (0 = Team A, 1 = Team B).
     * @param _team The chosen team for the stake (0 for Team A, 1 for Team B).
     */
    function newStake(string memory _eventId, uint256 _amountCoinIn, address _coinAddress, uint256 _amountATON, uint8 _team) external {
        bytes8 eventIdBytes = Tools._stringToBytes8(_eventId);

        _newStake(eventIdBytes, _amountCoinIn, _coinAddress, _amountATON, _team, msg.sender);
    }

    /**
     * @dev Internal function to create a new stake for an event.
     * @param _eventIdBytes Unique identifier of the event in bytes8 format.
     * @param _amountCoinIn Amount of VUND staked.
     * @param _coinAddress Address of the coin being staked.
     * @param _amountATON Amount of ATON staked from the player's wallet.
     * @param _team Chosen team for the stake (0 = Team A, 1 = Team B).
     * @param _player Address of the player placing the stake.
     */
    function _newStake(
        bytes8 _eventIdBytes,
        uint256 _amountCoinIn,
        address _coinAddress,
        uint256 _amountATON,
        uint8 _team,
        address _player
    ) internal {
        // Validate the event's status and starting time.
        AStructs.EventDTO memory eventInfo = VAULT.getEventDTO(_eventIdBytes);
        require(eventInfo.active, 'Event is not active');
        require(eventInfo.startDate > block.timestamp, 'Event already started');

        // Ensure valid team selection.
        require(_team == 0 || _team == 1, 'Invalid team');

        // Convert the staked coin amount to VUND equivalent.
        (uint256 vundAmount, uint256 adjustedCoinAmountIn) = VAULT.convertCoinToVUND(_coinAddress, _amountCoinIn);

        // Ensure the value of ATON being staked doesn't exceed that of the VUND equivalent.

        if (vundAmount >= _getATONtoVUND(_amountATON)) {
            _amountATON = _getVUNDtoATON(vundAmount);
        }
        // require(vundAmount >= _getATONtoVUND(_amountATON), "Can't stake ATON with a higher USD value than VUND");

        // Transfer the equivalent VUND value from the player to this contract.
        VAULT.retrieveCoin(_player, adjustedCoinAmountIn, _coinAddress, 0);

        // If any ATON is staked, burn a portion of it.
        uint256 burnPctATON = 1000000; // Assuming 10% burn rate based on the scaling of pct_denom.
        if (_amountATON > 0) {
            VAULT.retrieveCoin(_player, _amountATON, address(ATON), (_amountATON * burnPctATON) / pct_denom);
        }

        // If VUND is being staked, provide a bonus based on NFT holdings and potential leverage.
        if (_coinAddress == address(VAULT)) {
            // Ensure this is comparing to VUND's address.
            uint256 bonusAmount = _getVUNDtoATON(vundAmount * 500000 + _BonusNFT(_player, NFTcategories.VUNDrocket) / pct_denom);
            _amountATON += bonusAmount;
        }

        // Ensure the player's stake doesn't surpass the event's maximum stake limit.
        _checkMaxStakeVUND(_eventIdBytes, _player, vundAmount, eventInfo.maxStakeVUND, eventInfo.sport);

        // Register the stake in the VAULT contract
        VAULT.addStake(_eventIdBytes, _coinAddress, _amountCoinIn, _amountATON, _team, _player);
    }

    /**
     * @dev Internal function to check and handle the maximum VUND stake limit.
     * @param _eventIdBytes The unique identifier of the event in bytes8 format.
     * @param _player The address of the player creating the stake.
     * @param _amountVUND The total amount of VUND being staked.
     * @param _maxStakeVUND The maximum VUND stake allowed for the event.
     */
    function _checkMaxStakeVUND(
        bytes8 _eventIdBytes,
        address _player,
        uint256 _amountVUND,
        uint256 _maxStakeVUND,
        uint8 _sportId
    ) internal {
        if (_amountVUND > _maxStakeVUND) {
            uint256 rewardsATON = _getVUNDtoATON((_amountVUND) * 2000000 * (pct_denom + _BonusNFT(_player, _sportId))) /
                (pct_denom * pct_denom); // 20%*(bonus) ATON
            VAULT.addEarningsToPlayer(_player, 0, rewardsATON, _eventIdBytes, AStructs.MaxVUNDStake); // 7 Max VUND stake
        }
    }

    /**
     * @dev Cancels a player's stake on a specific event, refunding a percentage of the staked amount.
     * @param _eventId The unique identifier of the event.
     */
    function cancelPlayerStake(string memory _eventId) external {
        uint256 _cancelationPctCost = 2000000; // 20%
        bytes8 eventIdBytes = Tools._stringToBytes8(_eventId);
        VAULT.cancelPlayerStake(eventIdBytes, msg.sender, _cancelationPctCost);
    }

    /**
     * @dev Calculates the bonus multiplier based on NFT rarity and Atovix count.
     * @param _player Address of the player whose bonus is being determined.
     * @param _category Category identifier for the staking mechanics.
     * @return mult The calculated bonus multiplier.
     */
    function _BonusNFT(address _player, uint8 _category) internal view returns (uint256 mult) {
        // If PVT contract is not set, return 0 as there is no multiplier.
        if (PVT == address(0)) return 0;

        // Retrieve the NFT rarity (quality) for the player in the specified category.
        uint8 quality = IPVT(PVT).getBonus(_player, _category);
        // Retrieve the Atovix count for the player.
        uint256 atovixCount = IPVT(PVT).getAtovixCount(_player);

        // Start with the base percentage denominator as the bonus.
        uint256 atovixBonus = pct_denom;

        // Calculate Atovix bonus based on count with different logic after 10.
        if (atovixCount > 0) {
            if (atovixCount <= 10) {
                // Apply quadratic scaling for counts up to 10.
                atovixBonus += atovixCount * (atovixCount - 1) * 100000;
            } else {
                // For counts above 10, apply linear scaling.
                atovixBonus += 10 * 9 * 100000 + (atovixCount - 10) * 100000;
            }
        }

        // Check for the special category 'VUNDrocket' which has its own calculation.
        if (_category == uint8(NFTcategories.VUNDrocket)) {
            // Multiplier for 'VUNDrocket' is based on a fixed value multiplied by quality.
            mult = 200000 * quality;
            if (atovixCount > 0) {
                // Apply Atovix bonus if any Atovix tokens are present.
                mult = (mult * atovixBonus) / pct_denom;
            }
            return mult;
        }

        // Return 0 if neither quality nor Atovix count is present.
        if (quality == 0 && atovixCount == 0) return 0;

        // Define a base multiplier which is a factor of NFT quality.
        uint256 baseMultiplier = quality == 0 ? 100000 : 2 ** quality * 100000;

        // Adjust the base multiplier by the Atovix bonus.
        mult = (baseMultiplier * atovixBonus) / pct_denom;

        return mult;
    }

    function BonusNFT(address _player, uint8 _category) external view returns (uint256 mult) {
        return _BonusNFT(_player, _category);
    }

    /**
     * @dev Closes an event by updating its final result and distributing the earnings to all participating players.
     * @param _eventId The unique ID of the event.
     * @param _winner The winner of the event (-1 for Tie, 0 for Team A, 1 for Team B).
     * @param _scoreA The final score of Team A.
     * @param _scoreB The final score of Team B.
     * @param _player The address of the player who triggered the event closure.
     */
    function _closeEvent(string memory _eventId, int8 _winner, uint8 _scoreA, uint8 _scoreB, address _player) internal {
        bytes8 eventIdBytes = Tools._stringToBytes8(_eventId);

        VAULT.closeEvent(eventIdBytes, _winner, _scoreA, _scoreB, _player);
    }

    /**
     * @dev Finalizes the player's participation in all active events.
     * This function checks active events for the player, calculates the vault fee and updates the player's earnings.
     */
    function finalizePlayerEvent(string memory eventId) external {
        // Fetch details of these active events.
        bytes8 _eventIdBytes = Tools._stringToBytes8(eventId);
        AStructs.EventDTO memory eventDTO = VAULT.getEventDTO(_eventIdBytes);
        // Initialize the total vault fee to zero.
        uint256 vaultFee = 0;

        // Check if the event is not active, has a winner, and the player hasn't finalized their stake for this event.
        if (!eventDTO.active && eventDTO.winner != -1 && !VAULT.isPlayerFinalizedEvent(_eventIdBytes, msg.sender)) {
            // If all conditions are met, finalize this event for the player and accumulate the vault fee.
            vaultFee += _finalizePlayerEvent(_eventIdBytes, eventDTO, msg.sender);
        }

        // If there's a vault fee accumulated, add earnings for the VAULT.
        if (vaultFee > 0) {
            VAULT.addEarningsToPlayer(address(VAULT), vaultFee, 0, _eventIdBytes, AStructs.VaultFee);
        }
    }

    /**
     * @dev Finalizes a specific event for a player.
     * It calculates the player's earnings for a specific event, updates the player's finalized status and adds earnings to the player.
     *
     * @param _eventIdBytes The unique ID of the event.
     * @param _eventDTO The data structure containing the event's details.
     * @param _player The address of the player.
     *
     * @return vaultFee The fee that goes to the vault.
     */
    function _finalizePlayerEvent(
        bytes8 _eventIdBytes,
        AStructs.EventDTO memory _eventDTO,
        address _player
    ) internal returns (uint256 vaultFee) {
        // Fetch the premium and percentage denominator from the VAULT.

        // Calculate earnings for the player based on the event's outcome.
        (uint256 earningsVUND, uint256 earningsATON, uint8 earningCategory, bool isVaultFee) = _calculateEarnings(
            _eventIdBytes,
            _eventDTO.winner,
            _player,
            premium
        );

        // Check if a vault fee is applicable.
        if (isVaultFee) {
            // Calculate and pay referral bonuses for the player's referrals.

            // Calculate the vault fee from earnings.
            vaultFee = (premium * earningsVUND) / pct_denom;
            // Deduct vault fee from the player's earnings.
            earningsVUND -= vaultFee;
            // Deduct referral bonuses from the vault fee.
        }

        // Mark this event as finalized for the player.
        VAULT.setPlayerFinalizedEvent(_eventIdBytes, _player);
        // Add the player's earnings for this event.
        // console.log('addEarningsToPlayer', earningsVUND, earningsATON);
        VAULT.addEarningsToPlayer(_player, earningsVUND, earningsATON, _eventIdBytes, earningCategory);
        // console.log('addEarningsToPlayer finished');
    }

    /**
     * @dev Retrieves the list of active event IDs that the player is currently participating in.
     * @return An array of strings representing the active event IDs.
     */
    function getPlayerActiveEvents() external view returns (string[] memory) {
        // Retrieve active event IDs from VAULT
        bytes8[] memory activeEvents = VAULT.getPlayerActiveEvents(msg.sender);

        // Convert bytes8 event IDs to string format
        string[] memory activeEventsStr = new string[](activeEvents.length);
        for (uint256 i = 0; i < activeEvents.length; i++) {
            activeEventsStr[i] = Tools._bytes8ToString(activeEvents[i]);
        }

        return activeEventsStr;
    }

    /**
     * @dev Retrieves the list of closed event IDs that the player has participated in.
     * @return An array of strings representing the closed event IDs.
     */
    function getPlayerClosedEvents() external view returns (string[] memory) {
        // Retrieve closed event IDs from VAULT
        bytes8[] memory closedEvents = VAULT.getPlayerClosedEvents(msg.sender);

        // Convert bytes8 event IDs to string format
        string[] memory closedEventsStr = new string[](closedEvents.length);
        for (uint256 i = 0; i < closedEvents.length; i++) {
            closedEventsStr[i] = Tools._bytes8ToString(closedEvents[i]);
        }

        return closedEventsStr;
    }

    /**
     * @dev Calculates a player's earnings based on the Event winner, team selection, and stake details.
     * @param _eventId The unique ID of the Event.
     * @param _winner The final winner of the Event (-2 for a tie, 0 for Team A winning, 1 for Team B winning).
     * @param _player The address of the player whose earnings are being calculated.
     * @return earningsVUND The calculated earnings in VUND.
     * @return earningsATON The calculated earnings in ATON.
     * @return vaultFee The calculated vault fee.
     * @return earningCategory The earning category (0 for Loss, 1 for Win, 2 for Tie, 3 for Cancelled, 4 for Open Event Reward, 5 for Close Event Reward, 6 for Referral, 7 for Vault Fee).
     */
    function calculateEarnings(
        string memory _eventId,
        int8 _winner,
        address _player
    ) external view returns (uint256 earningsVUND, uint256 earningsATON, uint256 vaultFee, uint256 earningCategory) {
        bytes8 eventIdBytes = Tools._stringToBytes8(_eventId);
        bool isVaultFee;
        (earningsVUND, earningsATON, earningCategory, isVaultFee) = _calculateEarnings(eventIdBytes, _winner, _player, premium);

        // In case of cancellation or singular stake there is no Fee charged to the player
        if (isVaultFee) {
            vaultFee = (premium * earningsVUND) / pct_denom;
            earningsVUND = earningsVUND - vaultFee;
        }

        return (earningsVUND, earningsATON, vaultFee, earningCategory);
    }

    /**
     * @dev Calculates a player's earnings based on the Event outcome, team selection, and stake details.
     * @param _eventIdBytes - The unique ID of the Event.
     * @param _winner - The final winner of the Event (-2 for a tie, -3 for cancelled, 0 for Team A winning, 1 for Team B winning).
     * @param _player - The address of the player whose earnings are being calculated.
     * @param _premium - Vault fee percentage numerator.
     * @return earningsVUND - The calculated earnings in VUND.
     * @return earningsATON - The calculated earnings in ATON.
     * @return earningCategory - The earning category.
     * @return isVaultFee - Boolean indicating if a vault fee is applicable.
     */
    function _calculateEarnings(
        bytes8 _eventIdBytes,
        int8 _winner,
        address _player,
        uint256 _premium
    ) internal view returns (uint256 earningsVUND, uint256 earningsATON, uint8 earningCategory, bool isVaultFee) {
        uint256 playerSharePercentage;
        isVaultFee = true;

        AStructs.StakeDTO memory stakeDTO = VAULT.getPlayerStake(_eventIdBytes, _player);
        uint8 sport = VAULT.getSport(_eventIdBytes);

        if ((stakeDTO.stakeVUND) == 0) {
            return (0, 0, 0, false);
        }
        uint256 bonusNFT = pct_denom + _BonusNFT(_player, sport);
        // Singular stake: Only one player participated in the event.
        if (VAULT.getEventPlayerCount(_eventIdBytes) == 1) {
            earningsVUND = stakeDTO.stakeVUND;
            earningsATON = stakeDTO.stakeATON + ((_getVUNDtoATON(stakeDTO.stakeVUND) * 2000000 * bonusNFT) / (pct_denom * pct_denom));

            earningCategory = AStructs.SingularStake;
            isVaultFee = false;

            // Event was cancelled.
        } else if (_winner == -3) {
            earningsVUND = stakeDTO.stakeVUND;
            earningsATON = stakeDTO.stakeATON;
            earningCategory = AStructs.CancelledEvent;
            isVaultFee = false;

            // The event ended in a tie.
        } else if (_winner == -2) {
            earningCategory = AStructs.TieStake;
            playerSharePercentage =
                (stakeDTO.efectivePlayerVUND * pct_denom) /
                VAULT.getEventStakedVUND(_eventIdBytes, AStructs.WholeEffectiveVUND);
            earningsVUND = (playerSharePercentage * VAULT.getEventStakedVUND(_eventIdBytes, AStructs.WholeRawVUND)) / pct_denom;
            earningsATON = ((_getVUNDtoATON(stakeDTO.stakeVUND) * 300000 * bonusNFT)) / (pct_denom * pct_denom);

            // The player's team won.
        } else if (stakeDTO.team == uint256(int(_winner))) {
            earningCategory = AStructs.WonStake;
            playerSharePercentage =
                (stakeDTO.efectivePlayerVUND * pct_denom) /
                VAULT.getEventStakedVUND(_eventIdBytes, AStructs.getContex(stakeDTO.team, AStructs.Effective));
            earningsVUND = (playerSharePercentage * VAULT.getEventStakedVUND(_eventIdBytes, AStructs.WholeRawVUND)) / pct_denom;
            earningsATON = ((_getVUNDtoATON(stakeDTO.stakeVUND) * 100000 * bonusNFT)) / (pct_denom * pct_denom);

            // Vault fee is waived if earnings minus the potential fee is still greater than the original stake.
            if (stakeDTO.stakeVUND > earningsVUND - (_premium * earningsVUND) / pct_denom) {
                isVaultFee = false;
            }

            // The player's team lost.
        } else {
            earningCategory = AStructs.LossStake;
            earningsVUND = 0;
            earningsATON = ((_getVUNDtoATON(stakeDTO.stakeVUND) * 500000 * bonusNFT)) / (pct_denom * pct_denom);
        }

        return (earningsVUND, earningsATON, earningCategory, isVaultFee);
    }

    /**
     * @dev Function to calculate the VUND equivalent of a given ATON amount.
     * @param _amountATON The amount of ATON to be converted to VUND.
     * @return The equivalent amount of VUND.
     */
    function _getATONtoVUND(uint256 _amountATON) internal view returns (uint256) {
        // console.log('ATON: ', address(ATON));
        uint256 factorATON = IATON(ATON).calculateFactorAton();
        // console.log('factorATON: ', factorATON);

        uint256 amountVUND = (_amountATON * factorATON) / pct_denom;

        return amountVUND;
    }

    /**
     * @dev Convert a VUND amount to its ATON equivalent based on the current conversion rate.
     * @param _amountVUND Amount of VUND to be converted.
     * @return The ATON equivalent of the input VUND.
     */
    function _getVUNDtoATON(uint256 _amountVUND) internal view returns (uint256) {
        uint256 factorATON = IATON(ATON).calculateFactorAton();
        uint256 amountATON = (_amountVUND * pct_denom) / factorATON;
        return amountATON;
    }

    function getCoinsData(address _player) external view returns (AStructs.Coin[] memory) {
        AStructs.Coin[] memory coinsFromVault = VAULT.getCoinList();

        // Create a new memory array that's bigger by 1
        AStructs.Coin[] memory coins = new AStructs.Coin[](coinsFromVault.length + 1);

        // Set the first coin as ATON
        coins[0].token = address(ATON);
        coins[0].decimals = 0; // Initialized to 0 but will be updated below.
        coins[0].active = true;

        // Copy elements from coinsFromVault to coins starting from the second position
        for (uint256 i = 0; i < coinsFromVault.length; i++) {
            coins[i + 1] = coinsFromVault[i];
        }

        // Update details for each coin, including ATON
        for (uint8 i = 0; i < coins.length; i++) {
            coins[i].decimals = ERC20(coins[i].token).decimals();
            if (_player != address(VAULT)) {
                coins[i].allowance = IERC20(coins[i].token).allowance(_player, address(VAULT));
            } else {
                coins[i].allowance = 0;
            }
            coins[i].balance = IERC20(coins[i].token).balanceOf(_player);
            coins[i].symbol = ERC20(coins[i].token).symbol();
        }

        return coins;
    }
}
// All rights reserved. This software and associated documentation files (the "Software"),
// cannot be used, copied, modified, merged, published, distributed, sublicensed, and/or
// sold without the express and written permission of the owner.
