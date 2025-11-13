// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract NFTProject is ERC721Enumerable, Ownable, ERC2981, ReentrancyGuard, Pausable {
    using Strings for uint256;

    // State variables
    uint256 public mintPrice;
    uint256 public maxSupply;
    uint256 public maxPerWallet;
    uint256 public maxPerTransaction;
    string public baseURI;
    string public unrevealedURI;
    bool public revealed;
    bool public publicMintActive;
    uint256 private _nextTokenId;

    mapping(address => uint256) public mintedPerWallet;
    mapping(address => bool) public whitelist;

    event Minted(address indexed minter, uint256 indexed tokenId, uint256 quantity);
    event BaseURIUpdated(string newBaseURI);
    event Revealed();
    event PublicMintToggled(bool active);
    event WhitelistUpdated(address indexed user, bool status);

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _maxSupply,
        uint256 _mintPrice,
        uint256 _maxPerWallet,
        uint256 _maxPerTransaction,
        string memory _unrevealedURI,
        address _royaltyReceiver,
        uint96 _royaltyFeeNumerator
    ) ERC721(_name, _symbol) Ownable(msg.sender) {
        maxSupply = _maxSupply;
        mintPrice = _mintPrice;
        maxPerWallet = _maxPerWallet;
        maxPerTransaction = _maxPerTransaction;
        unrevealedURI = _unrevealedURI;
        revealed = false;
        publicMintActive = false;
        _nextTokenId = 1;
        
        if (_royaltyReceiver != address(0)) {
            _setDefaultRoyalty(_royaltyReceiver, _royaltyFeeNumerator);
        }
    }

    modifier mintCompliance(uint256 quantity) {
        require(quantity > 0, "Quantity must be > 0");
        require(quantity <= maxPerTransaction, "Exceeds max per transaction");
        require(totalSupply() + quantity <= maxSupply, "Exceeds max supply");
        require(mintedPerWallet[msg.sender] + quantity <= maxPerWallet, "Exceeds wallet limit");
        _;
    }

    function mint(uint256 quantity) 
        external 
        payable 
        whenNotPaused
        nonReentrant
        mintCompliance(quantity)
    {
        require(publicMintActive, "Public mint not active");
        require(msg.value >= mintPrice * quantity, "Insufficient payment");

        _mintTokens(msg.sender, quantity);

        uint256 required = mintPrice * quantity;
        if (msg.value > required) {
            (bool success, ) = payable(msg.sender).call{value: msg.value - required}("");
            require(success, "Refund failed");
        }
    }

    function whitelistMint(uint256 quantity)
        external
        payable
        whenNotPaused
        nonReentrant
        mintCompliance(quantity)
    {
        require(whitelist[msg.sender], "Not whitelisted");
        require(msg.value >= mintPrice * quantity, "Insufficient payment");

        _mintTokens(msg.sender, quantity);

        uint256 required = mintPrice * quantity;
        if (msg.value > required) {
            (bool success, ) = payable(msg.sender).call{value: msg.value - required}("");
            require(success, "Refund failed");
        }
    }

    function ownerMint(address to, uint256 quantity) 
        external 
        onlyOwner
        nonReentrant
    {
        require(quantity > 0, "Quantity must be > 0");
        require(totalSupply() + quantity <= maxSupply, "Exceeds max supply");

        _mintTokens(to, quantity);
    }

    function _mintTokens(address to, uint256 quantity) internal {
        for (uint256 i = 0; i < quantity; i++) {
            uint256 tokenId = _nextTokenId;
            _safeMint(to, tokenId);
            _nextTokenId++;
        }

        mintedPerWallet[to] += quantity;
        emit Minted(to, _nextTokenId - quantity, quantity);
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "Nonexistent token");

        if (!revealed) {
            return unrevealedURI;
        }

        string memory base = _baseURI();
        return bytes(base).length > 0 
            ? string(abi.encodePacked(base, tokenId.toString(), ".json")) 
            : "";
    }

    function addToWhitelist(address[] calldata addresses) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            whitelist[addresses[i]] = true;
            emit WhitelistUpdated(addresses[i], true);
        }
    }

    function removeFromWhitelist(address[] calldata addresses) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            whitelist[addresses[i]] = false;
            emit WhitelistUpdated(addresses[i], false);
        }
    }

    function setBaseURI(string calldata _baseURI) external onlyOwner {
        baseURI = _baseURI;
        emit BaseURIUpdated(_baseURI);
    }

    function setUnrevealedURI(string calldata _uri) external onlyOwner {
        unrevealedURI = _uri;
    }

    function reveal() external onlyOwner {
        revealed = true;
        emit Revealed();
    }

    function togglePublicMint() external onlyOwner {
        publicMintActive = !publicMintActive;
        emit PublicMintToggled(publicMintActive);
    }

    function setMintPrice(uint256 _price) external onlyOwner {
        mintPrice = _price;
    }

    function setMaxPerWallet(uint256 _max) external onlyOwner {
        maxPerWallet = _max;
    }

    function setMaxPerTransaction(uint256 _max) external onlyOwner {
        maxPerTransaction = _max;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function updateRoyalty(address receiver, uint96 feeNumerator) external onlyOwner {
        _setDefaultRoyalty(receiver, feeNumerator);
    }

    function withdraw() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        
        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "Withdrawal failed");
    }

    function walletOfOwner(address _owner) public view returns (uint256[] memory) {
        uint256 ownerTokenCount = balanceOf(_owner);
        uint256[] memory tokenIds = new uint256[](ownerTokenCount);
        for (uint256 i = 0; i < ownerTokenCount; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokenIds;
    }

    function remainingSupply() public view returns (uint256) {
        return maxSupply - totalSupply();
    }

    function supportsInterface(bytes4 interfaceId) 
        public 
        view 
        virtual 
        override(ERC721Enumerable, ERC2981) 
        returns (bool) 
    {
        return super.supportsInterface(interfaceId);
    }
}
