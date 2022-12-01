// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interface/IMarketErrors.sol";

contract MarketPlace is Ownable, IMarketPlace {
    using Counters for Counters.Counter;
    Counters.Counter private _itemId;

    uint256 private _listingPrice = 0.0025 ether;
    uint256 _ownerPercent = 5;

    enum ListingType {
        AUCTION,
        SALE
    }

    function setListingPrice(uint256 price) external onlyOwner {
        _listingPrice = price;
    }

    function setOwnerPercent(uint256 percent_) external onlyOwner {
        _ownerPercent = percent_;
    }

    function getListingPrice() external view returns (uint256) {
        return _listingPrice;
    }

    function _checkTimeRange(
        uint256 endTime,
        uint256 startTime,
        uint256 itemId
    ) internal view {
        if (block.timestamp > endTime && endTime > 0)
            revert UnavailableAction(itemId);
        if (block.timestamp < startTime) revert UnavailableAction(itemId);
    }

    struct Item {
        uint256 itemId;
        address erc721;
        uint256 tokenId;
        address owner;
        uint256 endTime;
        uint256 startTime;
        uint256 price;
        address bidder;
        ListingType listingType;
    }

    mapping(uint256 => Item) public _items;

    function listItem(
        address erc721Address,
        uint256 tokenId,
        uint256 endTime,
        uint256 startTime,
        uint256 price,
        uint8 listingType
    ) external payable {
        if (msg.value != _listingPrice) {
            revert PriceNotCovered();
        }
        IERC721 erc721 = IERC721(erc721Address);
        if (erc721.ownerOf(tokenId) != msg.sender) {
            revert Unauthorized(msg.sender);
        }
        _itemId.increment();
        uint256 currentId = _itemId.current();

        _items[currentId] = Item(
            currentId,
            erc721Address,
            tokenId,
            msg.sender,
            endTime,
            startTime,
            price,
            address(0),
            ListingType(listingType)
        );

        erc721.transferFrom(msg.sender, address(this), tokenId);
        payable(owner()).transfer(_listingPrice);
        emit ItemListed(msg.sender, currentId, price);
    }

    function _transferItem(Item memory item, address to) internal {
        delete _items[item.itemId];
        IERC721(item.erc721).transferFrom(address(this), to, item.tokenId);
    }

    function deleteListing(uint256 itemId) external {
        Item memory item = _items[itemId];
        if (item.owner != msg.sender) {
            revert Unauthorized(msg.sender);
        }

        if (block.timestamp < item.endTime)
            revert UnavailableAction(item.itemId);

        if (item.bidder != address(0) && msg.sender != item.bidder)
            revert Unauthorized(msg.sender);
        if (item.bidder == address(0) && msg.sender != item.owner)
            revert Unauthorized(msg.sender);

        _transferItem(item, msg.sender);
        emit ItemDeleted(msg.sender, item.itemId);
    }

    function _percent(
        uint256 percent_,
        uint256 value_
    ) internal pure returns (uint256) {
        return (value_ * percent_) / 100;
    }

    function purchase(uint256 itemId) external payable {
        Item memory item = _items[itemId];
        if (item.listingType != ListingType.SALE)
            revert UnavailableAction(item.itemId);
        _checkTimeRange(item.endTime, item.startTime, item.itemId);
        if (msg.value != item.price) {
            revert PriceNotCovered();
        }

        _transferItem(item, msg.sender);
        _transferProfits(item);
        emit Sale(item.owner, msg.sender, item.itemId, msg.value);
    }

    function bid(uint256 itemId) external payable {
        Item memory item = _items[itemId];
        _checkTimeRange(item.endTime, item.startTime, item.itemId);
        if (item.listingType != ListingType.AUCTION)
            revert UnavailableAction(item.itemId);
        if (msg.value <= item.price) revert PriceNotCovered();

        Item storage itemStorage = _items[itemId];
        itemStorage.bidder = msg.sender;
        itemStorage.price = msg.value;

        if (item.bidder == address(0)) return;

        payable(item.bidder).transfer(item.price);
        emit Offer(msg.sender, item.owner, item.itemId, item.price);
    }

    function claimItem(uint256 itemId) external {
        Item memory item = _items[itemId];
        if (block.timestamp < item.endTime)
            revert UnavailableAction(item.itemId);

        if (item.bidder != address(0) && msg.sender != item.bidder)
            revert Unauthorized(msg.sender);
        if (item.bidder == address(0) && msg.sender != item.owner)
            revert Unauthorized(msg.sender);

        _transferItem(item, msg.sender);

        if (item.bidder == address(0)) return;
        _transferProfits(item);
    }

    function _transferProfits(Item memory item) internal {
        uint256 earnsOwner = _percent(_ownerPercent, item.price);

        (bool success, bytes memory result) = item.erc721.call(
            abi.encodeWithSignature(
                "royaltyInfo(uin256,uint256)",
                item.tokenId,
                item.price
            )
        );

        address receiver;
        uint256 royalties;

        if (success) {
            (receiver, royalties) = abi.decode(result, (address, uint256));
            payable(receiver).transfer(royalties);
        }
        uint256 earnsSeller = item.price - earnsOwner - royalties;

        payable(owner()).transfer(earnsOwner);
        payable(item.owner).transfer(earnsSeller);
    }

    function getItems(
        ListingType listingType_
    ) external view returns (Item[] memory) {
        uint256 totalItemCount = _itemId.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 1; i < totalItemCount; ) {
            if (_items[i].listingType == listingType_) {
                unchecked {
                    ++itemCount;
                }
            }
            unchecked {
                ++i;
            }
        }

        Item[] memory items = new Item[](itemCount);
        for (uint256 i = 1; i < totalItemCount; ) {
            if (_items[i].listingType == listingType_) {
                items[currentIndex] = _items[i];
                unchecked {
                    ++currentIndex;
                }
            }

            unchecked {
                ++i;
            }
        }
        return items;
    }
}
