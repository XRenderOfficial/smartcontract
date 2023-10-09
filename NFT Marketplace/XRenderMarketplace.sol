// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract XRenderMarketplace is
    Ownable,
    Pausable,
    ReentrancyGuard,
    IERC721Receiver
{
    using SafeMath for uint256;
    using Counters for Counters.Counter;
    using EnumerableSet for EnumerableSet.AddressSet;

    Counters.Counter private _soldItems;
    Counters.Counter private _orderIdCount;

    struct Order {
        uint256 id;
        address payable seller;
        address payable buyer;
        uint256 tokenId;
        uint256 price;
        address nftAddress;
        uint256 startTime;
        uint256 endTime;
        bool isSold;
        bool currentList;
    }

    uint256 private taxService = 2;
    uint256 private taxCreator = 5;
    address private ownerCollect;

    mapping(uint256 => Order) private orders;
    mapping(address => address) public creatorOfNFT;

    event OrderAdded(
        uint256 indexed orderId,
        address indexed seller,
        uint256 indexed tokenId,
        uint256 price,
        address nftAddress,
        uint256 startTime,
        uint256 endTime,
        bool isSold,
        bool currentList
    );
    event UpdatePriceNftOnSale(
        uint256 indexed orderId,
        uint256 indexed tokenId,
        uint256 price,
        uint256 timeUpdate,
        address nftAddress
    );

    event BuyNFT(
        uint256 indexed orderId,
        address indexed seller,
        address indexed buyer,
        address nftAddress,
        uint256 tokenId,
        uint256 price,
        uint256 timeBuy,
        bool isSold,
        bool currentList
    );

    event UnListNFTOnSale(
        uint256 indexed orderId,
        address indexed seller,
        address indexed nftAddress,
        uint256 tokenId,
        uint256 timeUnList
    );

    event SetTax(uint256 _taxService, uint256 _taxCreator);

    function createMarketplaceItem(
        address _nftAddress,
        uint256 _tokenId,
        uint256 _price,
        uint256 _time
    ) external {
        require(!paused(), "Contract is paused");
        require(
            IERC721(_nftAddress).ownerOf(_tokenId) == _msgSender(),
            "sender is not owner of token"
        );
        require(
            IERC721(_nftAddress).getApproved(_tokenId) == address(this) ||
                IERC721(_nftAddress).isApprovedForAll(
                    _msgSender(),
                    address(this)
                ),
            "NFTMarketplace: The contract is unauthorized to manage this token"
        );
        require(_price > 0, "NFTMarketplace: price must be greater than 0");
        require(_time > 0, "endTime is wrong!");
        _orderIdCount.increment();
        uint256 _orderId = _orderIdCount.current();
        Order storage _order = orders[_orderId];
        _order.id = _orderId;
        _order.seller = payable(_msgSender());
        _order.tokenId = _tokenId;
        _order.price = _price;
        _order.nftAddress = _nftAddress;
        _order.startTime = block.timestamp;
        _order.endTime = block.timestamp.add(_time);
        _order.isSold = false;
        _order.currentList = true;
        IERC721(_nftAddress).safeTransferFrom(
            msg.sender,
            address(this),
            _tokenId
        );

        emit OrderAdded(
            _orderId,
            msg.sender,
            _tokenId,
            _price,
            _nftAddress,
            block.timestamp,
            _order.endTime,
            false,
            true
        );
    }

    function unListNftOnSale(uint256 _orderId) public {
        Order storage _order = orders[_orderId];
        require(
            IERC721(_order.nftAddress).ownerOf(_order.tokenId) == address(this),
            "This NFT doesn't exist on marketplace"
        );
        require(_order.currentList == true, "You already sold NFT or Unlist");
        require(
            _order.buyer == address(0),
            "NFTMarketplace: buyer must be zero"
        );
        require(
            _order.seller == _msgSender() || msg.sender == owner(),
            "NFTMarketplace: must be owner"
        );
        uint256 _tokenId = _order.tokenId;
        _order.isSold = false;
        _order.currentList = false;
        IERC721(_order.nftAddress).transferFrom(
            address(this),
            _msgSender(),
            _tokenId
        );
        emit UnListNFTOnSale(
            _orderId,
            _order.seller,
            _order.nftAddress,
            _tokenId,
            block.timestamp
        );
    }

    function updatePriceOnSale(uint256 _orderId, uint256 _price) public {
        Order storage _order = orders[_orderId];
        require(
            IERC721(_order.nftAddress).ownerOf(_order.tokenId) == address(this),
            "This NFT doesn't exist on marketplace"
        );
        require(
            _order.buyer == address(0),
            "NFTMarketplace: buyer must be zero"
        );
        require(_order.seller == _msgSender(), "NFTMarketplace: must be owner");
        require(
            block.timestamp >= _order.startTime &&
                block.timestamp <= _order.endTime,
            "out of time listing"
        );
        require(_order.price != _price, "Same old price");
        _order.price = _price;
        emit UpdatePriceNftOnSale(
            _orderId,
            _order.tokenId,
            _order.price,
            block.timestamp,
            _order.nftAddress
        );
    }

    function buyNft(uint256 _orderId) external payable nonReentrant {
        _soldItems.current();
        Order storage _order = orders[_orderId];
        require(
            block.timestamp >= _order.startTime &&
                block.timestamp <= _order.endTime,
            "out of time listing"
        );
        require(
            IERC721(_order.nftAddress).ownerOf(_order.tokenId) == address(this),
            "This NFT doesn't exist on marketplace"
        );
        require(
            _order.price == msg.value,
            "Minimum price has not been reached"
        );
        _order.buyer = payable(_msgSender());
        address payable addressSeller = _order.seller;
        uint256 price = _order.price;
        _order.isSold = true;
        _order.currentList = false;
        IERC721(_order.nftAddress).safeTransferFrom(
            address(this),
            _msgSender(),
            _order.tokenId
        );

        // Transfer Money for creator and ownerCollection
        uint256 totalTaxService = caluteFee(price, taxService);
        uint256 totalTaxCreator = caluteFee(price, taxCreator);
        if (creatorOfNFT[_order.nftAddress] == address(0)) {
            bool sentForCreator = payable(owner()).send(totalTaxCreator);
            require(sentForCreator, "Failed to send Ether creator");
        } else {
            bool sentForCreator = payable(creatorOfNFT[_order.nftAddress]).send(
                totalTaxCreator
            );
            require(sentForCreator, "Failed to send Ether creator");
        }
        uint256 totalUserReceive = price - totalTaxService - totalTaxCreator;
        bool sentForUser = addressSeller.send(totalUserReceive);
        require(sentForUser, "Failed to send Ether User");
        _soldItems.increment();
        emit BuyNFT(
            _orderId,
            _order.seller,
            _order.buyer,
            _order.nftAddress,
            _order.tokenId,
            _order.price,
            block.timestamp,
            true,
            false
        );
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unPause() external onlyOwner {
        _unpause();
    }

    function caluteFee(
        uint256 _amount,
        uint256 _rate
    ) private pure returns (uint256) {
        return _amount.mul(_rate).div(100);
    }

    function setTax(
        uint256 _taxService,
        uint256 _taxCreator
    ) external onlyOwner {
        taxService = _taxService;
        taxCreator = _taxCreator;
        emit SetTax(_taxService, _taxCreator);
    }

    function getTax() external view returns (uint256, uint256) {
        return (taxService, taxCreator);
    }

    function withdraw() external payable onlyOwner {
        uint256 _amount = address(this).balance;
        bool sent = payable(msg.sender).send(_amount);
        require(sent, "Failed to send Ether");
    }

    function getOrderNFT(
        uint256 _idOrder
    ) external view returns (Order memory) {
        return orders[_idOrder];
    }

    function getAmountSoldItems() external view returns (uint256) {
        return _soldItems.current();
    }

    function getAmountListItems() external view returns (uint256) {
        return _orderIdCount.current();
    }

    function setCreatorOfNFT(
        address _addressOfNFT,
        address _addressCreator
    ) external onlyOwner {
        creatorOfNFT[_addressOfNFT] = _addressCreator;
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return
            bytes4(
                keccak256("onERC721Received(address,address,uint256,bytes)")
            );
    }
}
