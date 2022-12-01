// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface IMarketPlace {
    error Unauthorized(address caller);
    error PriceNotCovered();
    error UnavailableAction(uint256 itemId);

    event ItemListed(address indexed from, uint256 itemId, uint256 price);
    event ItemDeleted(address indexed from, uint256 itemId);
    event Sale(
        address indexed from,
        address indexed to,
        uint256 itemId,
        uint256 price
    );
    event Offer(
        address indexed from,
        address indexed to,
        uint256 itemId,
        uint256 price
    );
}
