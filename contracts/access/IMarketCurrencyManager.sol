// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

interface IMarketCurrencyManager {
    function setCurrencies(
        address[] memory _nfts,
        address[] memory _currencies,
        uint256[] memory _commisions,
        uint256[] memory _minAmounts,
        bool[] memory _valids
    ) external;

    function getCurrency(address _nft, address _currency)
        external
        view
        returns (
            uint256,
            uint256,
            bool
        );
}
