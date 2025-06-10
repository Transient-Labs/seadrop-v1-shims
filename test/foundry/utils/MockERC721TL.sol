// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ERC721} from "openzeppelin-contracts/token/ERC721/ERC721.sol";

contract MockERC721TL is ERC721 {
    uint256 private _counter;

    constructor() ERC721("Mock", "MOCK") {}

    function externalMint(address recipient, string memory uri) external {
        _mint(recipient, ++_counter);
    }
}
