// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ERC1155} from "openzeppelin-contracts/token/ERC1155/ERC1155.sol";

contract MockERC1155TL is ERC1155 {
    constructor() ERC1155("https://mock.uri") {}

    function externalMint(uint256 tokenId, address[] calldata addresses, uint256[] calldata amounts) external {
        for (uint256 i = 0; i < addresses.length; i++) {
            _mint(addresses[i], tokenId, amounts[i], "");
        }
    }
}
