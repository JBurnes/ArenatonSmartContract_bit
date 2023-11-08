// SPDX-License-Identifier: LicenseRef-Proprietary

pragma solidity ^0.8.9;

// import './AStructs.sol';

library NFTcategories {
    // Define an enum for clarity in code. This makes the code more readable and avoids magic numbers.
    // Categories for Earnings
    uint8 public constant Soccer = 1;

    uint8 public constant Kabaddi = 42;
    // uint8 public constant ATONrocket = 90;
    uint8 public constant TreasureChest = 90;

    uint8 public constant AtonTicket = 91;
    uint8 public constant CloneSocket = 92;
    uint8 public constant Pixel = 93;
    uint8 public constant Atovix = 94;
    uint8 public constant VUNDrocket = 95;

    uint8 public constant AtovixPower = 20;
    uint8 public constant PixelPower = 10;
    uint8 public constant VUNDrocketPower = 20;

    // function NFTcategories() external pure {}

    function getRegularCategoryIndex(uint i) external pure returns (uint8) {
        uint8[32] memory categoryArray = [
            Soccer, // Socc er
            2,
            3,
            4,
            5,
            6,
            7,
            8,
            9,
            10,
            11,
            12,
            13,
            14,
            15,
            16,
            17,
            18,
            19,
            21,
            22,
            23,
            24,
            25,
            26,
            28,
            29,
            30,
            36,
            Kabaddi, // Kabaddi
            VUNDrocket, // VUND Rocket
            TreasureChest // TreasureChest
        ];
        return categoryArray[i];
    }

    uint8 public constant RegularNFT = 0;
    uint8 public constant TreasureChestNFT = 1;

    function getChestCategoryIndex(uint i) external pure returns (uint8) {
        uint8[4] memory categoryArray = [
            AtonTicket, // Socc er
            Pixel, // VUND Rocket
            Atovix, //ART
            VUNDrocket
        ];
        return categoryArray[i];
    }

    function getAllCategoryIndex() external pure returns (uint16[35] memory categoryArray) {
        return [
            Soccer, // Socc er
            2,
            3,
            4,
            5,
            6,
            7,
            8,
            9,
            10,
            11,
            12,
            13,
            14,
            15,
            16,
            17,
            18,
            19,
            21,
            22,
            23,
            24,
            25,
            26,
            28,
            29,
            30,
            36,
            uint16(Kabaddi), // Kabaddi
            uint16(TreasureChest), // TreasureChest
            uint16(AtonTicket), // Socc er
            uint16(Pixel), // VUND Rocket
            uint16(Atovix), //ART
            uint16(VUNDrocket)
        ];
    }
}
// All rights reserved. This software and associated documentation files (the "Software"),
// cannot be used, copied, modified, merged, published, distributed, sublicensed, and/or
// sold without the express and written permission of the owner.
