// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

// Importing required modules and interfaces
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./interfaces/IATON.sol";
import "./interfaces/IVAULT.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./libraries/EventsLib.sol";
import "./libraries/NFTcategories.sol";

contract PVT is ERC721URIStorage, VRFConsumerBaseV2, Ownable, ReentrancyGuard {
    // Define constant for percentage denominator, likely used for conversion or normalization
    // uint256 private constant pct_denom = 10000000;

    // References to other contracts/interfaces
    IVAULT internal VAULT; // Reference to the VAULT contract
    IATON internal ATON; // Reference to the ATON contract

    // Chainlink VRF related variables
    VRFCoordinatorV2Interface private immutable vrfCoordinator;
    uint64 private immutable subscriptionId;
    bytes32 private immutable gasLane;
    uint16 private immutable callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    // NFT related variables
    uint256 private tokenCounter;
    uint256 internal constant MAX_CATEGORY_CHANCE = 649;
    uint256 private canvasSize = 1;
    uint256 private canvasPot;

    // Mapping for Chainlink VRF requestId to the requester's address
    mapping(uint256 => address) public requestIdToSender;

    // Mappings for NFT traits and ownership
    mapping(uint32 => string) private uriCode;
    mapping(uint256 => uint8) private category;
    mapping(uint256 => uint16) private quality;
    mapping(address => uint256[]) private stakesArray;
    mapping(uint256 => bool) private charged; // tokenId -> charged?
    mapping(uint256 => uint256) private eventCount; // tokenId -> level
    uint256 private chestCount; // tokenId -> level
    // mapping(uint256 => uint8) private nftCount;

    mapping(uint256 => uint16) private maxQuality; //(Category => Quality)
    mapping(uint256 => bool) private isRequestChest; // requestId -> is Chest??

    mapping(address => mapping(uint8 => uint256)) private stakesHash;
    mapping(address => uint256[]) private stakesAtovix;

    mapping(uint256 => uint256) private pixelsTokenId; // coordenada encoded -> TokenId
    mapping(uint256 => uint256) private tokenIdCoordinates; //TokenId  -> coordenada encoded

    mapping(uint256 => uint8) private pixelsColor; // coordenada -> color??
    mapping(address => uint256) private currentPaintedPixels;
    mapping(uint256 => address) private lastPainter;
    mapping(address => uint256) private playerPower;

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    // Mapping from owner to list of owned tokenIds
    mapping(address => uint256[]) private _ownedTokens;

    // Mapping from tokenId to its index in the owner tokens list
    mapping(uint256 => uint256) private _ownedTokensIndex;

    string public contractURI_;

    //  Commision sharing
    uint256 private totalPowerSupply;

    // Mapping to store the last accumulated commission per token for each player
    mapping(address => uint256)
        private lastAccumulatedCommissionPerTokenForPlayerATON;
    mapping(address => uint256)
        private lastAccumulatedCommissionPerTokenForPlayerVUND;

    uint256 private accumulatedCommissionPerTokenVUND;
    uint256 private accumulatedCommissionPerTokenATON;
    uint256 private totalCommissionVUND;
    uint256 private totalCommissionATON;
    uint256 private atovixTypes;

    constructor(
        address _VAULT,
        address _ATON,
        address _vrfCoordinatorV2,
        uint64 _subscriptionId,
        bytes32 _gasLane,
        uint16 _callbackGasLimit
    )
        VRFConsumerBaseV2(_vrfCoordinatorV2)
        ERC721("Vault Aton NFT Collection", "PVT")
    {
        VAULT = IVAULT(_VAULT);
        ATON = IATON(_ATON);
        vrfCoordinator = VRFCoordinatorV2Interface(_vrfCoordinatorV2);
        gasLane = _gasLane;
        subscriptionId = _subscriptionId;
        callbackGasLimit = _callbackGasLimit;
        tokenCounter = 0;
        _initializeMaxQuality();
    }

    // #region  REC721 tokens Uris
    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721URIStorage) returns (bool) {
        return ERC721URIStorage.supportsInterface(interfaceId);
    }

    function contractURI() public view returns (string memory) {
        return contractURI_;
    }

    function tokenURI(
        uint256 tokenId
    ) public view virtual override returns (string memory) {
        // Ensure the token has been minted.
        _requireMinted(tokenId);

        // Determine if the token is staked based on its owner being the current contract.
        bool staked = (ownerOf(tokenId) == address(this));

        // Fetch the URI using the token's traits.
        string memory uri = uriCode[
            AStructs.encodeTrait(
                category[tokenId],
                quality[tokenId],
                staked,
                charged[tokenId]
            )
        ];

        // If the URI is non-empty, return it. Otherwise, return an empty string.
        return bytes(uri).length > 0 ? uri : "";
    }

    function addUris(AStructs.traitsUpload[] memory traits) external onlyOwner {
        for (uint8 i = 0; i < traits.length; i++) {
            uriCode[
                AStructs.encodeTrait(
                    traits[i].category,
                    traits[i].quality,
                    traits[i].staked,
                    traits[i].charged
                )
            ] = traits[i].uri;
            if (
                traits[i].category == NFTcategories.Atovix &&
                traits[i].quality + 1 > atovixTypes
            ) {
                atovixTypes = traits[i].quality + 1;
            }
        }
    }

    function setContractURI(string memory _newUri) external onlyOwner {
        contractURI_ = _newUri;
    }

    // #endregion  REC721 tokens Uris

    // #region Mint + ChainLink +(Stake)

    function mintAtovix(uint16 _atovixIndex) external onlyOwner {
        AStructs.traitsShort memory trait = AStructs.traitsShort({
            category: NFTcategories.Atovix,
            quality: _atovixIndex
        });
        _mintNFT(msg.sender, trait);
    }

    function _mintTreasureChest() internal {
        chestCount++;

        // Define the traits for the Treasure Chest NFT
        AStructs.traitsShort memory traits = AStructs.traitsShort({
            category: NFTcategories.TreasureChest, // Set NFT category as 'TreasureChest'
            quality: 1 // Quality level set to 1
        });
        // Invoke the internal mint function to create the NFT with the defined traits
        _mintNFT(msg.sender, traits);
    }

    function _mintRegularNft() internal returns (uint256 requestId) {
        // Request a random number from Chainlink VRF.
        requestId = vrfCoordinator.requestRandomWords(
            gasLane,
            subscriptionId,
            REQUEST_CONFIRMATIONS,
            callbackGasLimit,
            3
        );

        // Map the requestId to the sender's address for future reference.
        requestIdToSender[requestId] = msg.sender;
        isRequestChest[requestId] = false;

        // Emit an event for external systems or services to track the NFT request.
        emit EventsLib.NftRequested(requestId, msg.sender);
    }

    function _mintNFT(
        address _player,
        AStructs.traitsShort memory _trait
    ) internal {
        tokenCounter += 1;

        // Mint the NFT and record its attributes
        _safeMint(_player, tokenCounter);
        category[tokenCounter] = _trait.category;
        quality[tokenCounter] = _trait.quality;
        _addTokenToOwnerEnumeration(_player, tokenCounter);
        _updatePlayerPower(_trait.category, _trait.quality, msg.sender, true);

        // if (_trait.quality > _trait.maxQuality) {
        //     _trait.maxQuality = _trait.quality;
        // }
        emit EventsLib.NftMinted(_trait, _player);
    }

    function fuseNFT(
        uint256[3] memory _tokenIdsFuse
    ) external nonReentrant returns (bool) {
        // Validate that the caller is the rightful owner of the NFTs and obtain their shared quality.
        uint16 commonQuality = _validateOwnershipAndGetQuality(_tokenIdsFuse);

        bool isCharged = false;
        uint8 category_ = category[_tokenIdsFuse[0]];
        if (
            category_ == NFTcategories.AtonTicket ||
            category_ == NFTcategories.Pixel
        ) {
            isCharged = true;
        }

        // Construct the attributes for the superior quality NFT that's to be minted for the caller.
        AStructs.traitsShort memory trait = AStructs.traitsShort({
            category: category_,
            quality: commonQuality + 1
        });
        _checkMaxQuality(category_, commonQuality + 1);

        // Proceed with the minting of the enhanced NFT for the caller.
        _mintNFT(msg.sender, trait);

        // Disseminate an event to log the fusion details, encompassing the original and new NFTs, their categories, and their qualities.
        emit EventsLib.fuseNFT(
            msg.sender,
            _tokenIdsFuse[0],
            _tokenIdsFuse[1],
            _tokenIdsFuse[2],
            tokenCounter, // tokenId
            category[tokenCounter],
            quality[tokenCounter]
        );
        _updatePlayerPower(category_, commonQuality + 1, msg.sender, true);

        // Extinguish the original NFTs after successful fusion, maintaining the rarity of the ecosystem.
        for (uint256 i = 0; i < 3; i++) {
            if (category_ == NFTcategories.Pixel) {
                uint encodedCoordinate = tokenIdCoordinates[_tokenIdsFuse[i]];
                pixelsTokenId[encodedCoordinate] = 0;
                tokenIdCoordinates[_tokenIdsFuse[i]] = 0;
            }
            _updatePlayerPower(category_, commonQuality, msg.sender, false);

            _burn(_tokenIdsFuse[i]);
        }

        return true; // Denote successful fusion.
    }

    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) internal override {
        uint16 qualityFound; // Holds the determined quality of the NFT.
        uint8 categoryFound; // Holds the determined category of the NFT.

        // Retrieve the NFT type associated with the requestId.
        bool isRequestChest_ = isRequestChest[requestId];

        // Determine NFT attributes based on its type.
        if (isRequestChest_) {
            categoryFound = _getChestCategoryFromRng(
                randomWords[0] % MAX_CATEGORY_CHANCE
            );
            if (categoryFound == NFTcategories.Atovix) {
                // Is Atovix
                qualityFound = uint16(
                    ((randomWords[1] %
                        stakesAtovix[requestIdToSender[requestId]].length) + 1)
                );
            } else {
                qualityFound = _getQualityFromRng(
                    randomWords[1] %
                        _diceSize(maxQuality[NFTcategories.VUNDrocket]),
                    NFTcategories.VUNDrocket
                );
            }
        } else {
            // Regular Mint
            // Logic to determine attributes for all other NFT types.
            categoryFound = _getRegularCategoryFromRng(
                randomWords[0] % MAX_CATEGORY_CHANCE
            );

            // Determine quality using the second random number.
            qualityFound = _getQualityFromRng(
                randomWords[1] %
                    _diceSize(maxQuality[NFTcategories.VUNDrocket]),
                categoryFound
            );
        }

        // Construct the NFT traits.
        AStructs.traitsShort memory trait = AStructs.traitsShort({
            category: categoryFound,
            quality: qualityFound
        });
        _checkMaxQuality(categoryFound, qualityFound);

        // Mint the NFT with determined traits and assign to the requester.
        _mintNFT(requestIdToSender[requestId], trait);
    }

    //NFT Actions

    function requestNft() external nonReentrant {
        _payToken(_getVUNDtoATON(100 * 10 ** 18), msg.sender, true);

        _mintRegularNft();
    }

    function stakeNFT(uint256 _tokenId) external nonReentrant {
        AStructs.traitsFull memory traitsNew = _tokenInfo(_tokenId);

        require(msg.sender == ownerOf(_tokenId), "you dont own this token");

        if (traitsNew.category == NFTcategories.TreasureChest) {
            _openTreasureChest(_tokenId);
            return;
        } else if (traitsNew.category == NFTcategories.AtonTicket) {
            _openAtonticket(_tokenId);
            return;
        }

        if (traitsNew.category == NFTcategories.Atovix) {
            stakesAtovix[msg.sender].push(_tokenId);
        } else {
            uint256 indexToRemove = stakesArray[msg.sender].length;
            for (uint256 i = 0; i < stakesArray[msg.sender].length; i++) {
                uint256 stakedTokenId = stakesArray[msg.sender][i];
                AStructs.traitsFull memory traitsStaked = _tokenInfo(
                    stakedTokenId
                );

                if (traitsStaked.category == traitsNew.category) {
                    if (traitsStaked.quality == traitsNew.quality) {
                        revert("NFT Duplicate");
                    }
                    indexToRemove = i;
                    _unStakeNFT(stakedTokenId);
                    break; // Exit the loop as we've found a matching category
                }
            }
            if (indexToRemove < stakesArray[msg.sender].length) {
                stakesArray[msg.sender][indexToRemove] = stakesArray[
                    msg.sender
                ][stakesArray[msg.sender].length - 1];
                stakesArray[msg.sender].pop();
            }

            stakesHash[msg.sender][traitsNew.category] = _tokenId;
            eventCount[_tokenId] = _getEventCount(
                msg.sender,
                traitsNew.category
            );
        }

        _transfer(msg.sender, address(this), _tokenId);
        stakesArray[msg.sender].push(_tokenId);
    }

    function unStakeNFT(uint256 _tokenId) external nonReentrant {
        // Call the internal function to handle the actual unstaking logic.
        _unStakeNFT(_tokenId);
    }

    function _unStakeNFT(uint256 _tokenId) internal {
        uint256 indexGeneralStake = _findAndRemoveStake(
            _tokenId,
            stakesArray[msg.sender]
        );
        uint256 indexAtovixStake = (category[_tokenId] == NFTcategories.Atovix)
            ? _findAndRemoveStake(_tokenId, stakesAtovix[msg.sender])
            : 0;

        // Merge the require statements to validate ownership and staking status
        require(
            address(this) == ownerOf(_tokenId) &&
                indexGeneralStake != type(uint256).max &&
                (category[_tokenId] != NFTcategories.Atovix ||
                    indexAtovixStake != type(uint256).max),
            "Invalid ownership or staking status"
        );

        // Reset the hash value associated with the staked NFT's category for the caller.
        stakesHash[msg.sender][category[_tokenId]] = 0;

        // Update the 'charged' status if the NFT is charged.
        if (!charged[_tokenId]) {
            charged[_tokenId] = _isChargedToken(msg.sender, _tokenId);
        }

        // Transfer ownership of the NFT back to the caller, completing the unstaking process.
        _transfer(address(this), msg.sender, _tokenId);
    }

    function _popStakedNFT(address _player, uint256 index) internal {
        // If the NFT to remove isn't the last one in the list, move the last NFT to its position.
        if (index != stakesArray[_player].length - 1) {
            stakesArray[_player][index] = stakesArray[_player][
                stakesArray[_player].length - 1
            ];
        }

        // Remove the last NFT (which is now either a duplicate or the one to be removed).
        stakesArray[_player].pop();
    }

    function _popStakedAtovix(address _player, uint256 index) internal {
        // If the NFT to remove isn't the last one in the list, move the last NFT to its position.
        if (index != stakesAtovix[_player].length - 1) {
            stakesAtovix[_player][index] = stakesAtovix[_player][
                stakesAtovix[_player].length - 1
            ];
        }

        // Remove the last NFT (which is now either a duplicate or the one to be removed).
        stakesAtovix[_player].pop();
    }

    function _getNFTlevel(address _player) internal view returns (uint256) {
        uint256 lvl;
        // Loop through the staked NFTs of the player to aggregate their total quality.
        for (uint256 i = 0; i < stakesArray[_player].length; i++) {
            lvl += quality[stakesArray[_player][i]];
        }
        lvl += stakesAtovix[_player].length * 10;
        // Retrieve the level of the VAULT for the calling player.
        return lvl;
    }

    function getPlayerNftData(
        address _player
    ) external view returns (AStructs.nftData[] memory) {
        // Calculate the combined total of staked and owned NFTs for the player
        uint256 totalLength = stakesArray[_player].length +
            _ownedTokens[_player].length;

        // Initialize an array to hold the NFT data
        AStructs.nftData[] memory nftDataArray = new AStructs.nftData[](
            totalLength
        );

        // Counter to track the current insertion position in nftDataArray
        uint256 currentIndex = 0;

        // Iterate through staked NFTs and populate their data in nftDataArray
        for (uint256 i = 0; i < stakesArray[_player].length; i++) {
            nftDataArray[currentIndex] = AStructs.nftData({
                tokenId: stakesArray[_player][i],
                trait: _tokenInfo(stakesArray[_player][i])
            });
            currentIndex++;
        }

        // Iterate through owned NFTs and populate their data in nftDataArray
        for (uint256 i = 0; i < _ownedTokens[_player].length; i++) {
            nftDataArray[currentIndex] = AStructs.nftData({
                tokenId: _ownedTokens[_player][i],
                trait: _tokenInfo(_ownedTokens[_player][i])
            });
            currentIndex++;
        }

        // Return the consolidated NFT data array
        return nftDataArray;
    }

    function getPlayerStakedNFTs(
        address _player
    ) external view returns (uint256[] memory) {
        return stakesArray[_player];
    }

    function buyTreasureChest() external nonReentrant returns (bool) {
        uint256 price = 20 * 10 ** 18 + 10 ** 15 * chestCount;
        // Internally mint a Treasure Chest NFT for the caller
        _payToken(price, msg.sender, false);
        _mintTreasureChest();
        return true;
    }

    function _openTreasureChest(
        uint256 _tokenId
    ) internal returns (uint256 requestId) {
        // Ensure the caller is the owner of the specified NFT
        require(ownerOf(_tokenId) == msg.sender, "You dont own this token");
        _updatePlayerPower(NFTcategories.TreasureChest, 1, msg.sender, false);

        // Burn the specified NFT, effectively "opening" the treasure chest
        _burn(_tokenId);

        // Request a random number from Chainlink VRF. The parameters for the VRF request,
        // such as the gas lane, subscription ID, confirmations required, and gas limit,
        // should be set elsewhere in the contract or be globally defined constants.
        requestId = vrfCoordinator.requestRandomWords(
            gasLane,
            subscriptionId,
            REQUEST_CONFIRMATIONS,
            callbackGasLimit,
            1
        );

        // Map the returned request ID to the sender's address, for tracking purposes
        requestIdToSender[requestId] = msg.sender;

        // Define the type of request (in this case, opening a Treasure Chest)
        isRequestChest[requestId] = true;

        // Emit an event indicating the NFT operation, which can be useful for front-end applications or auditing
        emit EventsLib.NftRequested(requestId, msg.sender);
    }

    function _openAtonticket(uint256 _tokenId) internal {
        // Ensure the NFT in question is an AtonTicket
        require(
            category[_tokenId] == NFTcategories.AtonTicket &&
                _ownerOf(_tokenId) == msg.sender,
            "_openAtonticket Error"
        );

        // Compute the base earnings for the pouch, this can be seen as the basic reward for opening it

        // Calculate the total earnings for the pouch based on its quality. Higher quality pouches yield more.
        // The formula indicates that the earnings exponentially increase with the quality of the pouch.
        uint16 _quality = quality[_tokenId];
        uint256 earningsATON = _getVUNDtoATON(20 * 10 ** 18) *
            6 ** (_quality - 1);

        // Credit the computed earnings to the pouch owner. VAULT presumably is a contract or module responsible for player earnings.
        VAULT.addEarningsToPlayer(
            msg.sender,
            0,
            earningsATON,
            "",
            AStructs.AtonTicket
        );
        _updatePlayerPower(
            NFTcategories.AtonTicket,
            _quality,
            msg.sender,
            false
        );

        // Burn the pouch NFT to signify it's been opened and its rewards have been claimed.
        _burn(_tokenId);
    }

    function _findAndRemoveStake(
        uint256 _tokenId,
        uint256[] storage stakeList
    ) internal returns (uint256) {
        for (uint256 i = 0; i < stakeList.length; i++) {
            if (_tokenId == stakeList[i]) {
                // If the token is found, remove it by replacing it with the last token in the list and then shrinking the list size.
                stakeList[i] = stakeList[stakeList.length - 1];
                stakeList.pop();
                return i;
            }
        }
        return type(uint256).max; // Return an "invalid" index to indicate the token was not found.
    }

    function _validateOwnershipAndGetQuality(
        uint256[3] memory _tokenValIds
    ) internal returns (uint16) {
        uint16 initialQuality = quality[_tokenValIds[0]];
        uint16 initialCategory = category[_tokenValIds[0]];
        // bool[3] memory flag;

        // Check ownership, quality, category, and charge status in one iteration.
        for (uint256 i = 1; i < 3; i++) {
            if (
                !((ownerOf(_tokenValIds[i]) == msg.sender ||
                    _isStakedByPlayer(_tokenValIds[i], msg.sender)) &&
                    quality[_tokenValIds[i]] == initialQuality &&
                    category[_tokenValIds[i]] == initialCategory &&
                    charged[_tokenValIds[i]] == true)
            ) {
                revert(
                    "Validation failed: Ownership, quality, category, or charge"
                );
            }
        }

        return initialQuality;
    }

    function _isStakedByPlayer(
        uint256 tokenId,
        address player
    ) internal returns (bool) {
        // Loop through the array of staked NFTs for the player.
        for (uint256 j = 0; j < stakesArray[player].length; j++) {
            // If a match is found for the given tokenId...
            if (tokenId == stakesArray[player][j]) {
                // ...remove the staked NFT from the player's stakes...
                _popStakedNFT(player, j);

                // ...and remove the NFT from the owner's enumeration under the contract's address.
                _removeTokenFromOwnerEnumeration(address(this), tokenId);

                // Indicate that the NFT was staked by the player and the cleaning operation was successful.
                return true;
            }
        }

        // If the loop completes without finding the NFT, return `false` indicating the NFT was not staked by the player.
        return false;
    }

    function _removeTokenFromOwnerEnumeration(
        address from,
        uint256 tokenId
    ) private {
        // Get the index of the last token in the owner's list.
        uint256 lastTokenIndex = _ownedTokens[from].length - 1;

        // Retrieve the position of the token being removed in the owner's list.
        uint256 tokenIndex = _ownedTokensIndex[tokenId];

        // If the token isn't the last one in the owner's list...
        if (tokenIndex != lastTokenIndex) {
            // Get the ID of the last token in the owner's list.
            uint256 lastTokenId = _ownedTokens[from][lastTokenIndex];

            // Move the last token to the position of the token being removed.
            _ownedTokens[from][tokenIndex] = lastTokenId;

            // Update the position of the moved token in the mapping.
            _ownedTokensIndex[lastTokenId] = tokenIndex;
        }

        // Delete the last position in the owner's token list.
        _ownedTokens[from].pop();

        // Remove the token's entry from the index mapping.
        delete _ownedTokensIndex[tokenId];
    }

    function _getPlayerLuck(address _player) internal view returns (uint256) {
        uint256 lvlNFT = _getNFTlevel(_player);
        uint256 lvlVAULT = VAULT.getPlayerLevel(msg.sender);
        uint256 lvlcurrentPaintedPixels = currentPaintedPixels[msg.sender];
        uint factor = 500;

        return factor * (lvlNFT + lvlVAULT + lvlcurrentPaintedPixels);
    }

    function _checkMaxQuality(uint8 _category, uint16 _quality) internal {
        if (_quality > maxQuality[_category]) {
            maxQuality[_category] = _quality;
        }
    }

    //ChainLink
    function _diceSize(uint256 _maxQuality) internal pure returns (uint256) {
        uint256 sumWeights = 0;
        for (uint256 i = 1; i <= _maxQuality; i++) {
            sumWeights += AStructs.pct_denom / 2 ** i;
        }
        return sumWeights;
    }

    function _buildQualityChanceArray(
        uint8 _category
    ) internal view returns (uint256[] memory) {
        uint256 _maxQuality = maxQuality[_category];

        uint256[] memory array = new uint256[](_maxQuality + 1);
        uint256 diceSize = _diceSize(_maxQuality);
        array[0] = diceSize;

        for (uint256 i = 1; i < array.length; i++) {
            array[i] = array[i - 1] - AStructs.pct_denom / (2 ** (i));

            if (i + 1 == array.length) {
                array[i] = 1;
            }
        }
        return array;
    }

    // #endregion Mint + ChainLink +(Stake)

    function _getRegularCategoryFromRng(
        uint256 categoryRng
    ) internal pure returns (uint8) {
        uint256 cumulativeSum = 0; // Initialize cumulative sum to 0.
        uint256[32]
            memory categoryChanceArray = _getRegularChanceCategoryArray(); // Fetch the cumulative distribution array.

        // Ensure the categoryRng doesn't go beyond the length of categoryChanceArray.
        if (categoryRng > categoryChanceArray.length) {
            categoryRng = categoryChanceArray.length;
        }

        for (uint256 i = 0; i < categoryChanceArray.length; i++) {
            // Loop through each element in the cumulative distribution.

            // Check if the given random number lies between the last cumulative sum
            // and the current item in the array, which means the category has been identified.
            if (
                categoryRng >= cumulativeSum &&
                categoryRng < categoryChanceArray[i]
            ) {
                uint8 categoryFound = _getRegularCategoryIndex(i); // Fetch the category index based on the loop counter.

                return categoryFound; // Return the determined category.
            }

            // Update the cumulativeSum for the next iteration.
            cumulativeSum = categoryChanceArray[i];
        }

        // If the function hasn't returned a category by this point, the categoryRng doesn't map
        // to any category, and thus, the function will revert.
        return 1;
    }

    function _getChestCategoryFromRng(
        uint256 _categoryRng
    ) internal view returns (uint8) {
        uint256 cumulativeSum = 0;
        uint256[4] memory categoryChanceArray = _chestChanceCategoryArray();

        // Ensuring _categoryRng doesn't exceed the length of categoryChanceArray.
        if (_categoryRng > categoryChanceArray.length) {
            _categoryRng = categoryChanceArray.length;
        }

        uint256 playerLuck = _getPlayerLuck(msg.sender);

        // Adjust the random number by adding player's levels from both NFT and VAULT.

        if (playerLuck > _categoryRng) {
            _categoryRng = 0;
        } else {
            _categoryRng -= playerLuck;
        }

        for (uint256 i = 0; i < categoryChanceArray.length; i++) {
            // Looping through each value in the cumulative distribution.

            // If the provided random number lies between the previous cumulative sum
            // and the current value in the array, the category is found.
            if (
                _categoryRng >= cumulativeSum &&
                _categoryRng < categoryChanceArray[i]
            ) {
                uint8 categoryFound = _chestCategoryIndex(i); // Fetch the category index.

                return categoryFound; // Return the identified category.
            }

            // Update the cumulativeSum for the next iteration.
            cumulativeSum = categoryChanceArray[i];
        }

        // If the function hasn't returned by this point, the categoryRng doesn't map
        // to any category, and the function will revert.
        return 1; // Return the identified category.
    }

    function _getRegularChanceCategoryArray()
        internal
        pure
        returns (uint256[32] memory)
    {
        uint256[32] memory categoryChanceArray;

        // Setting base chance for the first category.
        categoryChanceArray[0] = 20;

        // Incrementing the chances by 21 for the next 29 categories (potentially sports-related).
        for (uint256 i = 1; i <= 29; i++) {
            categoryChanceArray[i] = categoryChanceArray[i - 1] + 1 + 20;
        }

        // Special categories with their own thematic representations and chances incremented by 3.
        categoryChanceArray[30] = categoryChanceArray[29] + 1 + 9; // Treasure Chest
        categoryChanceArray[31] = categoryChanceArray[30] + 1 + 9; // VUND rocket

        return categoryChanceArray;
    }

    function _chestChanceCategoryArray()
        internal
        pure
        returns (uint256[4] memory)
    {
        uint256[4] memory categoryChanceArray;

        // Base chance for the first category.
        categoryChanceArray[0] = 7000000;

        // Cumulative chance for ATON rocket, which is the base chance + 1 + 2.
        categoryChanceArray[1] = categoryChanceArray[0] + 1 + 3000000;

        // Cumulative chance for VUND rocket. However, there seems to be an error in the original code.
        // This should ideally reference the previous category's chance.
        categoryChanceArray[2] = categoryChanceArray[1] + 1 + 1500000;

        // Cumulative chance for ART category.
        categoryChanceArray[3] = categoryChanceArray[2] + 1 + 1000000;

        return categoryChanceArray;
    }

    function getRegularChanceCategoryArray()
        external
        pure
        returns (uint256[32] memory)
    {
        return _getRegularChanceCategoryArray();
    }

    function getChestChanceCategoryArray()
        external
        pure
        returns (uint256[4] memory)
    {
        return _chestChanceCategoryArray();
    }

    function _getQualityFromRng(
        uint256 _qualityRng,
        uint8 _category
    ) public view returns (uint8) {
        // Retrieve the level of the NFT for the calling player.
        uint256 playerLuck = _getPlayerLuck(msg.sender);

        // Adjust the random number by adding player's levels from both NFT and VAULT.

        if (playerLuck > _qualityRng) {
            _qualityRng = 0;
        } else {
            _qualityRng -= playerLuck;
        }

        // Retrieve the maximum quality possible for the given category.
        uint256 _maxQuality = maxQuality[_category];

        // Define the range (dice size) for the random number based on the maximum quality.
        uint256 diceSize = _diceSize(_maxQuality);

        // Ensure the random number doesn't exceed the defined range.
        if (_qualityRng > diceSize) {
            _qualityRng = diceSize;
        }

        // Build an array that defines the chances of each quality for the provided category.
        uint256[] memory qualityChanceArray = _buildQualityChanceArray(
            _category
        );

        // Initialize a variable to store the found quality.
        uint8 qualityFound = 1;

        // Loop through each quality chance in the array.
        for (uint8 i = 0; i < qualityChanceArray.length; i++) {
            // If we are not at the last quality chance in the array...
            if (i + 1 < qualityChanceArray.length) {
                // Check if the random number falls between the current quality chance and the next one.
                if (
                    _qualityRng < qualityChanceArray[i] &&
                    _qualityRng > qualityChanceArray[i + 1]
                ) {
                    qualityFound = i + 1; // Set the quality to the current index + 1.
                }
            } else {
                // If we are at the last quality chance in the array, simply check if the random number is less than the current quality chance.
                if (_qualityRng < qualityChanceArray[i]) {
                    qualityFound = i + 1; // Set the quality to the current index + 1.
                }
            }
        }

        // Return the found quality.
        return qualityFound;
    }

    function _getRegularCategoryIndex(uint i) internal pure returns (uint8) {
        return NFTcategories.getRegularCategoryIndex(i);
    }

    function _chestCategoryIndex(uint i) internal pure returns (uint8) {
        return NFTcategories.getChestCategoryIndex(i);
    }

    function getTokenCounter() external view returns (uint256) {
        return tokenCounter;
    }

    function _getEventCount(
        address _player,
        uint8 _category
    ) internal view returns (uint256) {
        if (_category < 90) {
            return VAULT.getEventCounter(_player, _category);
        } else {
            return VAULT.getEventCounter(_player, 0);
        }
    }

    function _isChargedToken(
        address _player,
        uint256 _tokenId
    ) internal view returns (bool) {
        // Retrieve the final event count for the NFT's category and its owner.
        uint256 eventCountFinal = _getEventCount(_player, category[_tokenId]);

        // Check if the difference between the final event count and the NFT's last update event count
        // meets or exceeds the threshold for its category.
        if (eventCountFinal - eventCount[_tokenId] >= 2 ** quality[_tokenId]) {
            return true;
        }
        return false;
    }

    function getBonus(
        address _player,
        uint8 _category
    ) external view returns (uint16) {
        uint256 tokenId = stakesHash[_player][_category];

        if (tokenId > 0) {
            return quality[tokenId];
        } else {
            return 0;
        }
    }

    function getAtovixCount(address _player) external view returns (uint256) {
        return stakesAtovix[_player].length;
    }

    // #region Comissions

    function playerCommission(
        address _player
    )
        external
        view
        returns (
            uint256 unclaimedCommissionVUND,
            uint256 unclaimedCommissionATON
        )
    {
        return _playerCommission(_player);
    }

    function _playerCommission(
        address _player
    )
        internal
        view
        returns (
            uint256 unclaimedCommissionVUND,
            uint256 unclaimedCommissionATON
        )
    {
        uint256 playerPowerValue = playerPower[_player];
        uint256 tokenUnit = 10 ** 18;

        // Calculate owed per token for VUND and ATON, then compute the unclaimed commission if it's greater than zero.
        unclaimedCommissionVUND = _calculateUnclaimedCommission(
            playerPowerValue,
            accumulatedCommissionPerTokenVUND,
            lastAccumulatedCommissionPerTokenForPlayerVUND[_player],
            tokenUnit
        );

        unclaimedCommissionATON = _calculateUnclaimedCommission(
            playerPowerValue,
            accumulatedCommissionPerTokenATON,
            lastAccumulatedCommissionPerTokenForPlayerATON[_player],
            tokenUnit
        );
    }

    function _calculateUnclaimedCommission(
        uint256 playerPowerValue,
        uint256 accumulatedCommissionPerToken,
        uint256 lastAccumulatedCommissionPerTokenForPlayer,
        uint256 tokenUnit
    ) private pure returns (uint256 unclaimedCommission) {
        uint256 owedPerToken = accumulatedCommissionPerToken -
            lastAccumulatedCommissionPerTokenForPlayer;
        if (owedPerToken > 0) {
            unclaimedCommission = (playerPowerValue * owedPerToken) / tokenUnit;
        } else {
            unclaimedCommission = 0;
        }
    }

    function summary(
        address _player
    ) external view returns (AStructs.summary memory) {
        //  Objetivo: Entregar un resumen de informacion del contrato de NFTs y del jugador
        (
            uint256 unclaimedCommissionVUND,
            uint256 unclaimedCommissionATON
        ) = _playerCommission(_player);
        AStructs.summary memory _summary = AStructs.summary({
            tokenCounter: tokenCounter,
            chestCount: chestCount,
            chestPrice: 20 * 10 ** 18 + 10 ** 15 * chestCount,
            regularNFTprice: _getVUNDtoATON(40 * 10 ** 18),
            canvasSize: canvasSize,
            canvasPot: canvasPot,
            currentPaintedPixels: currentPaintedPixels[_player],
            // totalPaintedPixels: totalPaintedPixels[_player],
            playerPower: playerPower[_player],
            totalPowerSupply: totalPowerSupply,
            unclaimedCommissionVUND: unclaimedCommissionVUND,
            unclaimedCommissionATON: unclaimedCommissionATON
        });

        return _summary;
    }

    function _accumulateCommission(
        uint256 _newCommissionVUND,
        uint256 _newCommissionATON
    ) internal {
        // Calculate and update the commission per  power unit for VUND.
        // This will be used later to determine how much each player earns based on their power.
        accumulatedCommissionPerTokenVUND +=
            (_newCommissionVUND * (10 ** 18)) /
            totalPowerSupply;

        // Similarly, calculate and update the commission per power unit for ATON.
        accumulatedCommissionPerTokenATON +=
            (_newCommissionATON * (10 ** 18)) /
            totalPowerSupply;

        // Update the total commissions stored in the contract for both VUND and ATON.
        totalCommissionVUND += _newCommissionVUND;
        totalCommissionATON += _newCommissionATON;

        // Emit an event to log the details of the accumulated commissions.
        emit EventsLib.AccumulateNFT(
            _newCommissionVUND,
            accumulatedCommissionPerTokenVUND,
            _newCommissionATON,
            accumulatedCommissionPerTokenATON
        );
    }

    function _distributeCommission(address player) internal {
        // Fetch unclaimed commissions for both VUND and ATON
        (
            uint256 unclaimedCommissionVUND,
            uint256 unclaimedCommissionATON
        ) = _playerCommission(player);

        // Distribute VUND commission if available
        if (unclaimedCommissionVUND > 0) {
            _distributeVUNDCommission(player, unclaimedCommissionVUND);
        }

        // Distribute ATON commission if available
        if (unclaimedCommissionATON > 0) {
            _distributeATONCommission(player, unclaimedCommissionATON);
        }

        // Emit combined Earnings event after distributing both commissions
        emit EventsLib.Earnings(
            "",
            player,
            "",
            player,
            unclaimedCommissionVUND,
            unclaimedCommissionATON,
            AStructs.ComissionPower
        );
    }

    function _distributeVUNDCommission(
        address player,
        uint256 commission
    ) internal {
        // Transfer the commission directly, using a ternary operator to decide the recipient
        VAULT.transfer(
            player == address(this) ? Ownable.owner() : player,
            commission
        );

        // Update the last claimed commission for the player
        lastAccumulatedCommissionPerTokenForPlayerVUND[
            player
        ] = accumulatedCommissionPerTokenVUND;
    }

    function _distributeATONCommission(
        address player,
        uint256 commission
    ) internal {
        // Transfer the commission directly, using a ternary operator to decide the recipient
        ATON.transfer(
            player == address(this) ? Ownable.owner() : player,
            commission
        );

        // Update the last claimed commission for the player
        lastAccumulatedCommissionPerTokenForPlayerATON[
            player
        ] = accumulatedCommissionPerTokenATON;
    }

    function _updatePlayerPower(
        uint8 _category,
        uint16 _quality,
        address _player,
        bool isAdd
    ) internal {
        _distributeCommission(_player);
        uint256 _unit;

        // Determine the power unit based on the category
        if (_category == NFTcategories.Atovix) {
            uint256 atovixCount = stakesAtovix[_player].length;
            uint256 newPoints = atovixCount * (atovixCount - 1);
            if (isAdd) {
                uint256 previousPoints = (atovixCount - 1) * (atovixCount - 2);

                _unit = newPoints - previousPoints;
            } else {
                uint256 previousPoints = (atovixCount + 1) * atovixCount;

                _unit = previousPoints - newPoints;
            }
        } else if (
            _category == NFTcategories.Pixel ||
            _category == NFTcategories.AtonTicket
        ) {
            _unit = 2 * (2 ** _quality);
        } else if (_category == NFTcategories.VUNDrocket) {
            _unit = 3 * (2 ** _quality);
        } else {
            _unit = 2 ** _quality;
        }

        // Update power based on the boolean switch
        if (isAdd) {
            playerPower[_player] += _unit;
            totalPowerSupply += _unit;
        } else {
            playerPower[_player] -= _unit;
            totalPowerSupply -= _unit;
        }
    }

    function _payToken(
        uint256 _tokenAmount,
        address _player,
        bool isATON
    ) internal {
        // Perform the token transfer and accumulate commission, using a single require.
        require(
            (
                isATON
                    ? ATON.transferFrom(_player, address(this), _tokenAmount)
                    : IATON(address(VAULT)).transferFrom(
                        _player,
                        address(this),
                        _tokenAmount
                    )
            ),
            "Token transfer failed"
        );

        // Accumulate commission based on the token type.
        _accumulateCommission(
            isATON ? 0 : _tokenAmount / 2,
            isATON ? _tokenAmount : 0
        );
        if (!isATON) {
            VAULT.donateVUND(_player, _tokenAmount / 2);
        }
    }

    // #endregion Comissions

    // #region Pixel

    function paintPixel(
        uint128 x,
        uint128 y,
        uint8 _color
    ) external nonReentrant {
        uint coordinates = AStructs.encodeCoordinates(x, y);

        // Merge the two require statements to validate coordinate boundaries and pixel color.
        require(
            x <= canvasSize &&
                y <= canvasSize &&
                pixelsColor[coordinates] != _color,
            "Invalid coordinates or same color"
        );

        uint256 amountATON = _getVUNDtoATON(10 ** 18);
        VAULT.addEarningsToPlayer(
            msg.sender,
            0,
            amountATON,
            "",
            AStructs.PixelPaint
        );

        pixelsColor[coordinates] = _color;
        currentPaintedPixels[msg.sender] += 1;
        // totalPaintedPixels[msg.sender] += 1;

        uint256 tokenId = pixelsTokenId[coordinates];
        address landOwner = _ownerOf(tokenId);

        if (tokenId > 0 && landOwner != address(0)) {
            VAULT.addEarningsToPlayer(
                landOwner,
                0,
                (amountATON * 1000000 * quality[tokenId]) / AStructs.pct_denom,
                "",
                AStructs.PixelPaint
            );
            quality[tokenId] = _color;
        } else {
            VAULT.addEarningsToPlayer(
                VAULT.getOwner(),
                0,
                amountATON,
                "",
                AStructs.PixelPaint
            );
        }

        if (lastPainter[coordinates] != address(0)) {
            currentPaintedPixels[lastPainter[coordinates]] -= 1;
        }

        _growCanvas();
        lastPainter[coordinates] = msg.sender;
        emit EventsLib.PaintPixel(msg.sender, x, y, _color);
    }

    function claimPixel(
        uint128 x,
        uint128 y,
        uint256 _newTokenId
    ) external returns (bool) {
        uint coordinates = AStructs.encodeCoordinates(x, y);

        uint256 oldTokenId = pixelsTokenId[coordinates];
        // If the pixel at coordinates (x,y) hasn't been claimed by any token ID, associate it with the given _newTokenId
        if (oldTokenId == 0) {
            pixelsTokenId[coordinates] = _newTokenId;
        } else if (quality[oldTokenId] < quality[_newTokenId]) {
            pixelsTokenId[coordinates] = _newTokenId;
        } else {
            revert("Coordinate Already Claimed"); // If already claimed, revert the transaction
        }
        tokenIdCoordinates[_newTokenId] = coordinates;
        emit EventsLib.ClaimPixel(
            oldTokenId,
            _newTokenId,
            x,
            y,
            quality[_newTokenId]
        );
        return true;
    }

    function getPixelColors(
        uint256 page,
        uint256 perPage
    ) external view returns (AStructs.PixelDTO[] memory) {
        uint256 totalPixels = canvasSize * canvasSize;
        // Calculating starting index for pagination
        uint256 startIndex = (page - 1) * perPage;

        // Merge the require statements to validate input parameters and pagination range.
        require(
            perPage > 0 && page >= 1 && startIndex < totalPixels,
            "Invalid perPage, page number or page out of range"
        );

        // Calculating ending index for pagination
        uint256 endIndex = page * perPage > totalPixels
            ? totalPixels
            : page * perPage;

        // Determine the size of the resultant pixel array
        uint256 resultSize = endIndex - startIndex;
        AStructs.PixelDTO[] memory pixelArray = new AStructs.PixelDTO[](
            resultSize
        );

        uint256 resultIndex = 0;
        for (uint256 i = startIndex; i < endIndex; i++) {
            uint256 x = i / canvasSize;
            uint256 y = i % canvasSize;

            uint8 color = pixelsColor[
                AStructs.encodeCoordinates(uint128(x), uint128(y))
            ];
            AStructs.PixelDTO memory pixel = AStructs.PixelDTO({
                x: uint128(x),
                y: uint128(y),
                color: color,
                tokenId: pixelsTokenId[
                    AStructs.encodeCoordinates(uint128(x), uint128(y))
                ],
                painter: lastPainter[
                    AStructs.encodeCoordinates(uint128(x), uint128(y))
                ]
            });
            pixelArray[resultIndex] = pixel;
            resultIndex++;
        }

        return pixelArray;
    }

    function _growCanvas() internal {
        // Increment the canvas's pot by one (possibly representing a payment or donation for painting a pixel)
        canvasPot += 1;

        // Calculate the cost of adding a new row to the canvas.
        uint256 rowRequirement = 10 * (2 * canvasSize - 1) * 10 ** 18;

        // Check if the accumulated canvasPot is enough to warrant an expansion of the canvas size
        if (canvasPot >= rowRequirement) {
            // Reset the canvas pot and increment the size of the canvas
            canvasPot = 0;
            canvasSize++;

            // Mint a Treasure Chest NFT as a reward or incentive tied to the canvas growth
            _mintTreasureChest();

            // Emit an event to log the canvas expansion with the sender's address and the new canvas size
            emit EventsLib.CanvasSizeIncrease(msg.sender, canvasSize);
        }
    }

    // #endregion Pixel

    //
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override {
        uint8 _category = category[tokenId];
        uint16 _quality = quality[tokenId];
        // If the token isn't being minted, remove it from the sender's list of owned tokens.
        if (from != address(0)) {
            _removeTokenFromOwnerEnumeration(from, tokenId);
            _updatePlayerPower(_category, _quality, from, false);
        }

        // If the token isn't being burned, add it to the recipient's list of owned tokens.
        if (to != address(0)) {
            _addTokenToOwnerEnumeration(to, tokenId);
            _updatePlayerPower(_category, _quality, to, true);
        }

        // Reset the charged status of the token after transfer.
        charged[tokenId] = false;

        // Perform the actual token transfer using the logic from the parent contract.
        super._transfer(from, to, tokenId);
    }

    function tokenInfo(
        uint256 tokenId
    ) external view returns (AStructs.traitsFull memory) {
        return _tokenInfo(tokenId);
    }

    function _tokenInfo(
        uint256 _tokenId
    ) internal view returns (AStructs.traitsFull memory) {
        // Retrieve category and quality of the NFT using its tokenId.
        uint8 _category = category[_tokenId];
        uint16 _quality = quality[_tokenId];
        (uint128 x, uint128 y) = AStructs.decodeCoordinates(
            tokenIdCoordinates[_tokenId]
        );

        // Check if the NFT is currently staked (owned by this contract).
        bool _staked = _ownerOf(_tokenId) == address(this);

        // Determine if the NFT is already powered (charged).
        bool chargeThis = charged[_tokenId];

        // If the NFT is staked and not already powered, further evaluate if it should be powered.
        if (_staked && !chargeThis) {
            chargeThis = _isChargedToken(msg.sender, _tokenId);
        }

        // Construct and return the trait details for the NFT.
        return
            AStructs.traitsFull({
                category: _category,
                quality: _quality,
                uri: uriCode[
                    AStructs.encodeTrait(
                        _category,
                        _quality,
                        _staked,
                        chargeThis
                    )
                ],
                staked: _staked,
                charged: chargeThis,
                color: pixelsColor[_tokenId],
                maxQuality: maxQuality[_category],
                x: x,
                y: y
            });
    }

    function _getVUNDtoATON(
        uint256 _amountVUND
    ) internal view returns (uint256) {
        return
            (_amountVUND * AStructs.pct_denom) /
            IATON(ATON).calculateFactorAton();
    }

    function _addTokenToOwnerEnumeration(address to, uint256 tokenId) private {
        _ownedTokensIndex[tokenId] = _ownedTokens[to].length;
        _ownedTokens[to].push(tokenId);
    }

    function _initializeMaxQuality() internal {
        for (uint256 i = 0; i <= 99; i++) {
            maxQuality[i] = 1;
        }
    }

    function tokensOfOwner(
        address owner
    ) external view returns (uint256[] memory) {
        return _ownedTokens[owner];
    }
}
