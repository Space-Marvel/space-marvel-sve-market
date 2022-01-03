// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

interface INFT {
    function get(uint256 _nftId)
        external
        view
        returns (
            address,
            uint256,
            uint256,
            uint256,
            uint256
        );

    function exists(uint256 _id) external view returns (bool);

    function ownerOf(uint256 tokenId) external view returns (address);

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;
}
