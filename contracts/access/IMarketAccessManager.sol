// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

interface IMarketAccessManager {
    function isListingAllowed(address _caller) external view returns (bool);

    function isUpdatePriceAllowed(address _caller) external view returns (bool);

    function isListingAdminAllowed(address _caller)
        external
        view
        returns (bool);
}
