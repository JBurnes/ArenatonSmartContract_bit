// SPDX-License-Identifier: LicenseRef-Proprietary

pragma solidity ^0.8.9;

library AStructs {
    // Structure for requesting to open an oracle (event) for betting
    struct OracleOpenRequest {
        bytes8 eventIdBytes; // Unique identifier for the event
        address requester; // Player who makes the request to open or close the event
        uint256 amountCoin; // Amount of VUND in player's wallet
        address coinAddress; // Amount of VUND in player's vault
        uint256 amountATON; // Amount of ATON in player's wallet
        uint8 team; // 0 = A team, 1 = B team
        uint256 time; // Time of the request
    }

    // Structure for requesting to close an oracle (event)
    struct OracleCloseRequest {
        bytes8 eventIdBytes; // Unique identifier for the event
        address requester; // Player who makes the request to open or close the event
        uint256 time; // Time of the request
    }

    // Data transfer object for OracleOpenRequest
    struct OracleOpenRequestDTO {
        string eventId; // Unique identifier for the event
        bool active; // Is the event active?
        uint64 startDate; // Start date of the event
        uint256 time; // Time of the request
    }
    // Data transfer object for OracleCloseRequest
    struct OracleCloseRequestDTO {
        string eventId; // Unique identifier for the event
        bool active; // Is the event active?
        uint64 startDate; // Start date of the event
        uint256 time; // Time of the request
    }
    // Structure representing a player's stake in an event
    struct Stake {
        uint256 amountVUND; // Amount of VUND staked
        uint256 amountATON; // Amount of ATON staked
        uint8 team; // 0 = A team, 1 = B team
    }

    struct PixelDTO {
        uint128 x; // Amount of VUND staked
        uint128 y; // Amount of ATON staked
        uint8 color; // 0 = A team, 1 = B team
        uint256 tokenId; //
        address painter;
    }

    // Data transfer object for a player's stake
    struct StakeDTO {
        uint256 stakeVUND; // Amount of VUND staked
        uint256 stakeATON; // Amount of ATON staked
        uint8 team; // 0 = A team, 1 = B team
        uint256 efectivePlayerVUND; // Effective amount of ATON
    }

    // Structure representing an event for betting
    struct Event {
        bytes8 eventIdBytes; // Unique identifier for the event
        uint64 startDate; // Start date of the event
        mapping(address => Stake) stakes; // Stakes made by players (keyed by player address)
        mapping(address => bool) stakeFinalized; // Whether player has closed and cashed out earnings
        address[] players; // List of players
        uint256 stakeCount; // Total number of stakes for this event
        uint256 maxStakeVUND; // Maximum stake in VUND from any player
        uint256[2] totalVUND; // Total stakes in VUND (index 0 for team A, index 1 for team B)
        uint256[2] totalATON; // Total stakes in ATON (index 0 for team A, index 1 for team B)
        uint256[2] canceledVUND; // Total stakes in VUND where players cancelled
        bool active; // Is the event active?
        uint256 factorATON; // Factor calculated using the parameterized SQRT function of ATON supply
        uint8 scoreA; // Team A's score
        uint8 scoreB; // Team B's score
        int8 winner; // 0 = Team A won, 1 = Team B won, -2 = Tie, -1 = No result yet, -3 = Event Canceled
        uint8 sport; // ID: 1 (assumed for a specific sport)
    }

    // Data transfer object for an event
    struct EventDTO {
        string eventId; // Unique identifier for the event
        uint64 startDate; // Start date of the event
        uint8 sport; // ID of the sport
        uint256 totalVUND_A; // Total stakes in VUND for team A
        uint256 totalVUND_B; // Total stakes in VUND for team B
        uint256 totalATON_A; // Total stakes in ATON for team A
        uint256 totalATON_B; // Total stakes in ATON for team B
        uint256 canceledVUND_A; // Total stakes in VUND for team A
        uint256 canceledVUND_B; // Total stakes in VUND for team B
        uint256 maxStakeVUND; // Maximum stake in VUND
        bool active; // Is the event scheduled or finished?
        uint8 scoreA; // Team A's score
        uint8 scoreB; // Team B's score
        int8 winner; // 0 = Team A won, 1 = Team B won, -2 = Tie, -1 = No result yet, 3 = Event Canceled
        uint256 factorATON; // Factor calculated using the parameterized SQRT function of ATON supply
        uint8 eventState; // 0 ,1,2,3,4,5,6,7
    }

    // Structure representing a player's data
    struct Player {
        bytes8[] activeEvents; // List of active event IDs for the player
        bytes8[] closedEvents; // List of closed event IDs for the player
        uint256 level; // Player level
        mapping(uint8 => uint256) eventCounter; // eventCounter, counts by Category each event where player participated
    }

    // Structure representing a player's data
    struct Coin {
        address token; // Referral group code
        uint8 decimals; // Amount of ATON held by the player
        uint256 balance; // List of closed event IDs for the player
        uint256 balanceVUND; // List of closed event IDs for the player
        bool active; // List of active event IDs for the player
        string symbol; // Amount of VUND held by the player
        uint256 allowance; // List of closed event IDs for the player
    }

    // Define an enum for clarity in code. This makes the code more readable and avoids magic numbers.
    // Categories for Earnings
    uint8 public constant LossStake = 0;
    uint8 public constant WonStake = 1;
    uint8 public constant TieStake = 2;
    uint8 public constant CancelledEvent = 3;
    uint8 public constant OpenEventReward = 4;
    uint8 public constant CloseEventReward = 5;
    uint8 public constant Comission = 6;
    uint8 public constant MaxVUNDStake = 7;
    uint8 public constant SingularStake = 8;
    uint8 public constant AtonTicket = 9;
    uint8 public constant VaultFee = 10;
    uint8 public constant PixelPaint = 11;
    uint8 public constant CanvasSize = 12;
    uint8 public constant ComissionPower = 13;
    uint256 public constant pct_denom = 10000000;

    // Define an enum for clarity in code. This makes the code more readable and avoids magic numbers.
    // Categories for EventStates
    uint8 public constant NotInitialized = 0;
    uint8 public constant OpenRequest = 1;
    uint8 public constant StakingOn = 2;
    uint8 public constant Live = 3;
    uint8 public constant Ended = 4;
    uint8 public constant CloseRequest = 5;
    uint8 public constant RewardsPending = 6;
    uint8 public constant Closed = 7;

    bool public constant Raw = true;
    bool public constant Effective = false;
    uint8 public constant WholeRawVUND = 0;
    uint8 public constant TeamARawVUND = 1;
    uint8 public constant TeamBRawVUND = 2;
    uint8 public constant WholeEffectiveVUND = 3;
    uint8 public constant TeamAEffectiveVUND = 4;
    uint8 public constant TeamBEffectiveVUND = 5;

    uint8 public constant TEAM_A = 0;
    uint8 public constant TEAM_B = 1;

    function getContex(uint8 team, bool raw) internal pure returns (uint8) {
        if (raw) {
            if (team == TEAM_A) {
                return TeamARawVUND;
            } else {
                return TeamBRawVUND;
            }
        } else {
            if (team == TEAM_A) {
                return TeamAEffectiveVUND;
            } else {
                return TeamBEffectiveVUND;
            }
        }
    }

    function populateEvent(Event storage e, bytes8 _eventIdBytes, uint64 _startDate, uint8 _sport) internal {
        e.eventIdBytes = _eventIdBytes;
        e.startDate = _startDate;
        e.stakeCount = 0;
        e.active = true;
        e.winner = -1;
        e.sport = _sport;
        e.factorATON = 0;
    }

    struct traitsShort {
        uint8 category; // 0 1 2 3 4 2 13 100
        uint16 quality; //1 2 3 4 5  6
        // uint16 maxQuality;
    }

    struct traitsUpload {
        uint8 category; // 0 1 2 3 4 2 13 100
        uint16 quality; //1 2 3 4 5  6
        string uri;
        bool staked; //true false
        bool charged; //true false
    }

    struct traitsFull {
        uint8 category; // 0 1 2 3 4 2 13 100
        uint16 quality; //1 2 3 4 5  6
        bool staked; //true false
        bool charged; //true false
        string uri;
        uint8 color; // 0 1 2 3 4 2 13 100
        uint16 maxQuality;
        uint128 x;
        uint128 y;
    }

    struct summary {
        uint256 tokenCounter; // 0 1 2 3 4 2 13 100
        uint256 chestCount; //true false
        uint256 chestPrice; //true false
        uint256 regularNFTprice; //true false
        // pixel
        uint256 canvasSize; //1 2 3 4 5  6
        uint256 canvasPot; //true false
        uint256 currentPaintedPixels;
        // Power
        uint256 playerPower;
        uint256 totalPowerSupply;
        uint256 unclaimedCommissionVUND;
        uint256 unclaimedCommissionATON; // 0 1 2 3 4 2 13 100
    }

    struct nftData {
        uint256 tokenId;
        traitsFull trait; // 0 1 2 3 4 2 13 100
    }

    function encodeTrait(uint8 category, uint16 quality, bool staked, bool powered) internal pure returns (uint32) {
        // Check to ensure category and quality values are in valid range
        require(category <= 0xFF, 'Category value is too large');
        require(quality <= 0xFFFF, 'Quality value is too large'); // Now allowing full 16 bits

        uint32 stakedBit = staked ? 1 << 31 : 0; // Setting the most significant bit if staked is true
        uint32 poweredBit = powered ? 1 << 16 : 0; // Setting bit 17 if powered is true

        return stakedBit | poweredBit | (uint32(category) << 16) | uint32(quality);
    }

    function encodeCoordinates(uint128 x, uint128 y) internal pure returns (uint256) {
        return (uint256(x) << 128) | uint256(y);
    }

    function decodeCoordinates(uint256 encoded) internal pure returns (uint128 x, uint128 y) {
        x = uint128(encoded >> 128); // Shift right by 128 bits to retrieve x
        y = uint128(encoded); // Cast to uint128 to retrieve y (lower 128 bits)
    }

    // mapping(uint16 => string) private uriCode;

    // string uriBase = 'ipfs://bafybeibnsoufr2renqzsh347nrx54wcubt5lgkeivez63xvivplfwhtpym/';
    // //  tokenUri = uriBase + uriCode
    //   function setUri(uint8 category, uint8 quality, string memory code) external {
    //     uriCode[AStructs.encodeTrait(category, quality)] = code;
    // }

    // function setUris(uint8[] memory categories, uint8[] memory qualities, string[] memory codes) external onlyRole(DEFAULT_ADMIN_ROLE) {
    //     require(categories.length == qualities.length);
    //     for (uint8 i; i < categories.length; i++) {
    //         uriCode[AStructs.encodeTrait(categories[i], qualities[i])] = codes[i];
    //     }
    // }

    // function setUris2(AStructs.traits[] memory traits) external onlyRole(DEFAULT_ADMIN_ROLE) {
    //     for (uint8 i; i < traits.length; i++) {
    //         uriCode[AStructs.encodeTrait(traits[i].category, traits[i].quality)] = traits[i].code;
    //     }
    // }
}
// All rights reserved. This software and associated documentation files (the "Software"),
// cannot be used, copied, modified, merged, published, distributed, sublicensed, and/or
// sold without the express and written permission of the owner.
