// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./INFT.sol";
import "./access/Ownable.sol";
import "./access/IMarketCurrencyManager.sol";
import "./lifecycle/Pausable.sol";
import "./ERC/ERC20/IBEP20.sol";
import "./access/IMarketAccessManager.sol";
import "./security/ReentrancyGuard.sol";
import "./MarketV2Storage.sol";
import "./ERC/ERC20/SafeBEP20.sol";

contract MarketV2 is Ownable, Pausable, ReentrancyGuard {
    using SafeBEP20 for IBEP20;

    uint256 public duration; //seconds

    mapping(address => bool) nfts;
    IMarketAccessManager private accessManager;
    MarketV2Storage private marketV2Storage;
    IMarketCurrencyManager private currencyManager;
    address vault;

    event Purchase(
        address indexed previousOwner,
        address indexed newOwner,
        address indexed nft,
        uint256 nftId,
        address currency,
        uint256 listingPrice,
        uint256 price,
        uint256 sellerAmount,
        uint256 commissionAmount,
        uint256 time
    );

    event Listing(
        address indexed owner,
        address indexed nft,
        uint256 indexed nftId,
        address listingUser,
        address currency,
        uint256 listingPrice,
        uint256 listingTime,
        uint256 openTime
    );

    event PriceUpdate(
        address indexed owner,
        address indexed nft,
        uint256 nftId,
        uint256 oldPrice,
        uint256 newPrice,
        uint256 time
    );

    event UnListing(address indexed owner, address indexed nft, uint256 indexed nftId, uint256 time);

    constructor(
        IMarketAccessManager _accessManager,
        MarketV2Storage _marketV2Storage,
        IMarketCurrencyManager _currencyManager,
        address _vault,
        uint256 _duration
    ) {
        require(_vault != address(0), "Error: Vault address(0)");
        require(
            address(_accessManager) != address(0),
            "Error: AccessManager address(0)"
        );
        require(
            address(_marketV2Storage) != address(0),
            "Error: MarketV2Storage address(0)"
        );

        require(
            address(_currencyManager) != address(0),
            "Error: CurrencyManager address(0)"
        );

        accessManager = _accessManager;
        marketV2Storage = _marketV2Storage;
        currencyManager = _currencyManager;
        vault = _vault;
        duration = _duration;
    }

    function setAccessManager(IMarketAccessManager _accessManager)
        external
        onlyOwner
    {
        require(
            address(_accessManager) != address(0),
            "Error: AccessManager address(0)"
        );
        accessManager = _accessManager;
    }

    function setVauld(address _vault) external onlyOwner {
        require(_vault != address(0), "Error: Vault address(0)");
        vault = _vault;
    }

    function setDuration(uint256 _duration) external onlyOwner {
        duration = _duration;
    }

    function setNFT(address[] memory _nfts, bool[] memory _isSupports) external onlyOwner {
        require(_nfts.length == _isSupports.length, "Error: invalid input");

        for (uint256 i = 0; i < _nfts.length; i++) {
            require(address(_nfts[i]) != address(0), "Error: NFT address(0)");
            nfts[_nfts[i]] = _isSupports[i];
        }
    }

    function setStorage(MarketV2Storage _marketV2Storage) external onlyOwner {
        require(
            address(_marketV2Storage) != address(0),
            "Error: MarketV2Storage address(0)"
        );
        marketV2Storage = _marketV2Storage;
    }

    function setCurrencyManager(IMarketCurrencyManager _currencyManager)
        external
        onlyOwner
    {
        require(
            address(_currencyManager) != address(0),
            "Error: CurrencyManager address(0)"
        );
        currencyManager = _currencyManager;
    }

    function getItem(address _nft, uint256 _nftId)
        public
        view
        returns (
            address,
            address,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        require(nfts[_nft], "Error: NFT not support");
        require(INFT(_nft).exists(_nftId), "Error: wrong nftId");

        address owner;
        address currency;
        uint256 price;
        uint256 listingTime;
        uint256 openTime;
        (owner, currency, price, listingTime, openTime) = marketV2Storage
            .getItem(_nft, _nftId);
        uint256 gene;
        (, , , gene, ) = INFT(_nft).get(_nftId);

        return (owner, currency, price, gene, listingTime, openTime);
    }

    function listing(
        address _nft,
        uint256 _nftId,
        address _currency,
        uint256 _price
    ) external whenNotPaused {
        require(
            accessManager.isListingAllowed(_msgSender()),
            "Not have listing permisison"
        );

        require(nfts[_nft], "Error: NFT not support");
        require(INFT(_nft).exists(_nftId), "Error: wrong nftId");
        require(
            INFT(_nft).ownerOf(_nftId) == _msgSender(),
            "Error: you are not the owner"
        );
        address owner;
        (owner, , , , ) = marketV2Storage.getItem(_nft,_nftId);
        require(owner == address(0), "Error: item listing already");

        //check currency
        bool valid;
        uint256 minAmount;
        (, minAmount, valid) = currencyManager.getCurrency(_nft, _currency);
        require(valid, "Error: Currency invalid");
        require(_price >= minAmount, "Error: price invalid");

        marketV2Storage.addItem(
            _nft,
            _nftId,
            _msgSender(),
            _currency,
            _price,
            block.timestamp,
            block.timestamp + duration
        );
        //transfer NFT for market contract
        INFT(_nft).transferFrom(_msgSender(), address(this), _nftId);
        emit Listing(
            _msgSender(),
            _nft,
            _nftId,
            _msgSender(),
            _currency,
            _price,
            block.timestamp,
            block.timestamp + duration
        );
    }

    function listingByAdmin(
        address[] memory _nfts,
        uint256[] memory _nftIds,
        address[] memory _currencies,
        uint256[] memory _prices,
        uint256[] memory _durations
    ) external whenNotPaused {
        require(
            accessManager.isListingAdminAllowed(_msgSender()),
            "Not have listing permisison"
        );

        require(_nfts.length == _nftIds.length, "Input invalid");
        require(_nftIds.length == _currencies.length, "Input invalid");
        require(_nftIds.length == _prices.length, "Input invalid");
        require(_nftIds.length == _durations.length, "Input invalid");

        for (uint256 i = 0; i < _nftIds.length; i++) {
            require(nfts[_nfts[i]], "Error: NFT not support");
            require(INFT(_nfts[i]).exists(_nftIds[i]), "Error: wrong nftId");
            require(
                INFT(_nfts[i]).ownerOf(_nftIds[i]) == _msgSender(),
                "Error: you are not the owner"
            );
            address owner;
            (owner, , , , ) = marketV2Storage.getItem(_nfts[i],_nftIds[i]);
            require(owner == address(0), "Error: item listing already");

            marketV2Storage.addItem(
                _nfts[i],
                _nftIds[i],
                _msgSender(),
                _currencies[i],
                _prices[i],
                block.timestamp,
                block.timestamp + _durations[i]
            );
            //transfer NFT for market contract
            INFT(_nfts[i]).transferFrom(
                _msgSender(),
                address(this),
                _nftIds[i]
            );
            emit Listing(
                _msgSender(),
                _nfts[i],
                _nftIds[i],
                _msgSender(),
                _currencies[i],
                _prices[i],
                block.timestamp,
                block.timestamp + _durations[i]
            );
        }
    }

    function buy(
        address _nft,
        uint256 _nftId,
        uint256 _amount
    ) external payable whenNotPaused nonReentrant {
        address owner;
        address currency;
        uint256 price;
        uint256 openTime;
        (owner, currency, price, , openTime) = marketV2Storage.getItem(_nft, _nftId);
        if (currency == address(0)) {
            _amount = msg.value;
        }
        validate(_nft, _nftId, _amount, owner, currency, price, openTime);

        address previousOwner = INFT(_nft).ownerOf(_nftId);
        address newOwner = _msgSender();

        uint256 commissionAmount;
        uint256 sellerAmount;
        (commissionAmount, sellerAmount) = trade(
            _nft,
            _nftId,
            currency,
            _amount,
            owner
        );

        emit Purchase(
            previousOwner,
            newOwner,
            _nft,
            _nftId,
            currency,
            price,
            _amount,
            sellerAmount,
            commissionAmount,
            block.timestamp
        );
    }

    function validate(
        address _nft,
        uint256 _nftId,
        uint256 _amount,
        address _owner,
        address _currency,
        uint256 _price,
        uint256 _openTime
    ) internal view {
        require(nfts[_nft], "Error: NFT not support");
        require(INFT(_nft).exists(_nftId), "Error: wrong nftId");
        require(_owner != address(0), "Item not listed currently");
        require(
            _msgSender() != INFT(_nft).ownerOf(_nftId),
            "Can not buy what you own"
        );
        require(block.timestamp >= _openTime, "Item still lock");
        if (_currency == address(0)) {
            require(msg.value >= _price, "Error: the amount is lower");
        } else {
            require(_amount >= _price, "Error: the amount is lower");
        }
    }

    function trade(
        address _nft,
        uint256 _nftId,
        address _currency,
        uint256 _amount,
        address _nftOwner
    ) internal returns (uint256, uint256) {
        address buyer = _msgSender();

        INFT(_nft).transferFrom(address(this), buyer, _nftId);

        uint256 commission;
        (commission, , ) = currencyManager.getCurrency(_nft,_currency);
        uint256 commissionAmount = (_amount * commission) / 10000;
        uint256 sellerAmount = _amount - commissionAmount;

        if (_currency == address(0)) {
            payable(_nftOwner).transfer(sellerAmount);
            payable(vault).transfer(commissionAmount);
        } else {
            IBEP20(_currency).safeTransferFrom(buyer, _nftOwner, sellerAmount);
            IBEP20(_currency).safeTransferFrom(buyer, vault, commissionAmount);

            //transfer BNB back to user if currency is not address(0)
            if (msg.value != 0) {
                payable(_msgSender()).transfer(msg.value);
            }
        }

        marketV2Storage.deleteItem(_nft, _nftId);
        return (commissionAmount, sellerAmount);
    }

    function updatePrice(
        address[]memory _nfts,
        uint256[] memory _nftIds,
        uint256[] memory _prices
    ) public whenNotPaused returns (bool) {
        require(
            accessManager.isUpdatePriceAllowed(_msgSender()),
            "Not have listing permisison"
        );

        require(_nftIds.length == _nfts.length, "Input invalid");
        require(_nftIds.length == _prices.length, "Input invalid");
        for (uint256 i = 0; i < _nftIds.length; i++) {
            require(nfts[_nfts[i]], "Error: NFT not support");

            address nftOwner;
            address currency;
            uint256 oldPrice;
            uint256 listingTime;
            uint256 openTime;
            (
                nftOwner,
                currency,
                oldPrice,
                listingTime,
                openTime
            ) = marketV2Storage.getItem(_nfts[i], _nftIds[i]);

            require(_msgSender() == nftOwner, "Error: you are not the owner");
            marketV2Storage.updateItem(
                _nfts[i],
                _nftIds[i],
                nftOwner,
                currency,
                _prices[i],
                listingTime,
                openTime
            );

            emit PriceUpdate(
                _msgSender(),
                _nfts[i],
                _nftIds[i],
                oldPrice,
                _prices[i],
                block.timestamp
            );
        }

        return true;
    }

    function unListing(address[]memory _nfts,uint256[] memory _nftIds)
        public
        whenNotPaused
        returns (bool)
    {
        require(_nfts.length==_nftIds.length,"Error: invalid input");

        for (uint256 i = 0; i < _nftIds.length; i++) {
            require(nfts[_nfts[i]], "Error: NFT not support");

            address nftOwner;
            (nftOwner, , , , ) = marketV2Storage.getItem(_nfts[i],_nftIds[i]);
            require(_msgSender() == nftOwner, "Error: you are not the owner");

            marketV2Storage.deleteItem(_nfts[i], _nftIds[i]);

            INFT(_nfts[i]).transferFrom(address(this), _msgSender(), _nftIds[i]);

            emit UnListing(_msgSender(), _nfts[i], _nftIds[i], block.timestamp);
        }

        return true;
    }

    function getCurrency(address _nft, address _currency)
        external
        view
        returns (
            uint256,
            uint256,
            bool
        )
    {
        return currencyManager.getCurrency(_nft, _currency);
    }

    /* ========== EMERGENCY ========== */
    /*
    Users make mistake by transfering usdt/busd ... to contract address. 
    This function allows contract owner to withdraw those tokens and send back to users.
    */
    function rescueStuckErc20(address _token) external onlyOwner {
        uint256 _amount = IBEP20(_token).balanceOf(address(this));
        IBEP20(_token).safeTransfer(owner(), _amount);
    }
}
