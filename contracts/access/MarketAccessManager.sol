// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./IMarketAccessManager.sol";
import "./Ownable.sol";

contract MarketAccessManager is IMarketAccessManager, Ownable {
    bool listingPublicAll;
    bool updatePricePublicAll;

    mapping(address => bool) listingWhilelist;
    mapping(address => bool) updatePriceWhilelist;

    function setListingWhilelist(address _to, bool _isWhilelist)
        public
        onlyOwner
    {
        listingWhilelist[_to] = _isWhilelist;
    }

    function setUpdatePriceWhilelist(address _to, bool _isWhilelist)
        public
        onlyOwner
    {
        updatePriceWhilelist[_to] = _isWhilelist;
    }

    function setListingPublicAll(bool _listingPublicAll) public onlyOwner {
        listingPublicAll = _listingPublicAll;
    }

    function setUpdatePricePublicAll(bool _updatePricePublicAll) public onlyOwner {
        updatePricePublicAll = _updatePricePublicAll;
    }

    function isListingAllowed(address _caller)
        external
        view
        override
        returns (bool)
    {
        return listingPublicAll || listingWhilelist[_caller];
    }

    function isUpdatePriceAllowed(address _caller)
        external
        view
        override
        returns (bool)
    {
        return updatePricePublicAll || updatePriceWhilelist[_caller];
    }

    function isListingAdminAllowed(address _caller) 
        external
        view
        override
        returns (bool)
    {
        return listingWhilelist[_caller];
    }
}
