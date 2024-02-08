// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract NFTMarketplace {
    using Address for address payable;
    using SafeMath for uint256;

    struct Listing {
        uint256 price;
        address owner;
        bool active;
    }

    address public owner;
    IERC721Enumerable private nft;
    uint256 private feePercentage;
    mapping(uint256 => Listing) private listings;
    mapping(address => mapping(uint256 => bool)) private userOpenListings;
    
    // Optional feature: Track statistics of the listing and sales of NFT on the marketplace
    uint256 public totalListings;
    uint256 public totalSales;
    mapping(uint256 => uint256) public listingSaleCount;

    event NFTListed(uint256 indexed tokenId, uint256 price, address indexed owner);
    event NFTSold(uint256 indexed tokenId, uint256 price, address indexed oldOwner, address indexed newOwner);
    event ListingPriceChanged(uint256 indexed tokenId, uint256 oldPrice, uint256 newPrice);
    event NFTUnlisted(uint256 indexed tokenId);
    event FeePercentageSet(uint256 oldFeePercentage, uint256 newFeePercentage);
  
    modifier onlyOwner() {
        require(msg.sender == owner, "Only contract owner can call this function");
        _;
    }
  
    constructor() {
        owner = msg.sender;
        feePercentage = 1; // Default fee percentage is 1% of the sale price
    }

    /**
     * @dev Sets the ERC721 token contract address.
     * @param _nftAddress The address of the ERC721 token contract.
     */
    function setNftAddress(address _nftAddress) external onlyOwner {
        require(_nftAddress != address(0), "Invalid NFT address");
        nft = IERC721Enumerable(_nftAddress);
    }

    /**
     * @dev Lists an NFT for sale on the marketplace.
     * @param _tokenId The token ID of the NFT to list for sale.
     * @param _price The listing price of the NFT.
     */
    function listNFT(uint256 _tokenId, uint256 _price) external {
        require(nft.ownerOf(_tokenId) == msg.sender, "You don't own this NFT");
        require(_price > 0, "Price must be greater than zero");
        require(!listings[_tokenId].active, "NFT is already listed");

        listings[_tokenId] = Listing({
            price: _price,
            owner: msg.sender,
            active: true
        });
        userOpenListings[msg.sender][_tokenId] = true;
        totalListings = totalListings.add(1);

        emit NFTListed(_tokenId, _price, msg.sender);
    }

    /**
     * @dev Buys an NFT from the marketplace.
     * @param _tokenId The token ID of the NFT to buy.
     */
    function buyNFT(uint256 _tokenId) external payable {
        require(listings[_tokenId].active, "NFT is not listed for sale");
        require(msg.value >= listings[_tokenId].price, "Insufficient payment");

        address oldOwner = listings[_tokenId].owner;
        address newOwner = msg.sender;
        uint256 salePrice = listings[_tokenId].price;

        listings[_tokenId].active = false;
        userOpenListings[oldOwner][_tokenId] = false;
        totalSales = totalSales.add(1);
        listingSaleCount[_tokenId] = listingSaleCount[_tokenId].add(1);

        // Transfer NFT ownership
        nft.safeTransferFrom(oldOwner, newOwner, _tokenId);

        // Calculate and transfer fees
        uint256 feeAmount = (salePrice * feePercentage) / 100;
        if (feeAmount > 0) {
            payable(owner).sendValue(feeAmount);
        }

        // Transfer payment to the old NFT owner
        payable(oldOwner).sendValue(salePrice.sub(feeAmount));

        emit NFTSold(_tokenId, salePrice, oldOwner, newOwner);
    }

    /**
     * @dev Changes the listing price of an NFT.
     * @param _tokenId The token ID of the NFT.
     * @param _newPrice The new listing price of the NFT.
     */
    function changeListingPrice(uint256 _tokenId, uint256 _newPrice) external {
        require(listings[_tokenId].active, "NFT is not listed for sale");
        require(listings[_tokenId].owner == msg.sender, "You don't own this NFT");
        require(_newPrice > 0, "Price must be greater than zero");

        uint256 oldPrice = listings[_tokenId].price;
        listings[_tokenId].price = _newPrice;

        emit ListingPriceChanged(_tokenId, oldPrice, _newPrice);
    }

    /**
     * @dev Unlists an NFT from the marketplace.
     * @param _tokenId The token ID of the NFT to unlist.
     */
    function unlistNFT(uint256 _tokenId) external {
        require(listings[_tokenId].active, "NFT is not listed for sale");
        require(listings[_tokenId].owner == msg.sender, "You don't own this NFT");

        listings[_tokenId].active = false;
        userOpenListings[msg.sender][_tokenId] = false;
        totalListings = totalListings.sub(1);

        emit NFTUnlisted(_tokenId);
    }

    /**
     * @dev Sets the marketplace fee percentage.
     * @param _feePercentage The new fee percentage.
     */
    function setFeePercentage(uint256 _feePercentage) external onlyOwner {
        require(_feePercentage <= 100, "Fee percentage must be less than or equal to 100");

        uint256 oldFeePercentage = feePercentage;
        feePercentage = _feePercentage;

        emit FeePercentageSet(oldFeePercentage, _feePercentage);
    }

    /**
     * @dev Gets the listing details of an NFT.
     * @param _tokenId The token ID of the NFT.
     * @return The listing price, owner, and active state of the NFT.
     */
    function getListing(uint256 _tokenId) external view returns (uint256, address, bool) {
        Listing memory listing = listings[_tokenId];
        return (listing.price, listing.owner, listing.active);
    }

    /**
     * @dev Checks if an NFT is listed for sale.
     * @param _tokenId The token ID of the NFT.
     * @return A boolean indicating if the NFT is listed for sale.
     */
    function isNFTListed(uint256 _tokenId) external view returns (bool) {
        return listings[_tokenId].active;
    }

    /**
     * @dev Gets the fee percentage.
     * @return The fee percentage of the marketplace.
     */
    function getFeePercentage() external view returns (uint256) {
        return feePercentage;
    }

    /**
     * @dev Checks if the given address owns the specified NFT.
     * @param _owner The address to check for ownership.
     * @param _tokenId The token ID of the NFT.
     * @return A boolean indicating if the address owns the NFT.
     */
    function ownsNFT(address _owner, uint256 _tokenId) external view returns (bool) {
        return nft.ownerOf(_tokenId) == _owner;
    }

    /**
     * @dev Gets the total number of NFT listings.
     * @return The total number of NFT listings.
     */
    function getTotalListings() external view returns (uint256) {
        return totalListings;
    }

    /**
     * @dev Gets the total number of NFT sales.
     * @return The total number of NFT sales.
     */
    function getTotalSales() external view returns (uint256) {
        return totalSales;
    }

    /**
     * @dev Gets the number of sales for a specific NFT listing.
     * @param _tokenId The token ID of the NFT.
     * @return The number of sales for the NFT listing.
     */
    function getListingSaleCount(uint256 _tokenId) external view returns (uint256) {
        return listingSaleCount[_tokenId];
    }
}