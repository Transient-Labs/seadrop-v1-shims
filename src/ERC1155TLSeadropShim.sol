// SPDX-License Identifier: MIT
pragma solidity 0.8.17;

import {ERC721SeaDrop} from "./ERC721SeaDrop.sol";
import {IERC1155TL} from "./IERC1155TL.sol";

/// @title ERC1155TL Seadrop Shim
/// @notice Hacky contract that acts as a shim for minting an ERC1155TL token from Seadrop v1
/// @author Transient Labs, Inc.

contract ERC1155TLSeadropShim is ERC721SeaDrop {
    ///////////////////////////////////////////////////////////
    // Storage
    ///////////////////////////////////////////////////////////

    IERC1155TL public creatorContract;
    uint256 public tokenId;
    mapping(address => uint256) private _numMintedPerRecipient; // recipient -> number minted
    uint256 public numMinted;

    ///////////////////////////////////////////////////////////
    // Constructor
    ///////////////////////////////////////////////////////////
    constructor(
        string memory name,
        string memory symbol,
        address creatorContractToMintTo,
        uint256 tokenIdToMint,
        address[] memory allowedSeaDrop
    ) ERC721SeaDrop(name, symbol, allowedSeaDrop) {
        creatorContract = IERC1155TL(creatorContractToMintTo);
        tokenId = tokenIdToMint;
    }

    ///////////////////////////////////////////////////////////
    // Override needed functions
    ///////////////////////////////////////////////////////////

    function mintSeaDrop(address minter, uint256 quantity) external virtual override nonReentrant {
        // Ensure the SeaDrop is allowed.
        _onlyAllowedSeaDrop(msg.sender);

        // Extra safety check to ensure the max supply is not exceeded.
        if (numMinted + quantity > maxSupply()) {
            revert MintQuantityExceedsMaxSupply(numMinted + quantity, maxSupply());
        }

        // Update state variables
        _numMintedPerRecipient[minter] += quantity;
        numMinted += quantity;

        // Mint the quantity of tokens to the minter.
        address[] memory addresses = new address[](1);
        addresses[0] = minter;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = quantity;
        creatorContract.externalMint(tokenId, addresses, amounts);
    }

    function getMintStats(address minter)
        external
        view
        override
        returns (uint256 minterNumMinted, uint256 currentTotalSupply, uint256 maxSupply)
    {
        minterNumMinted = _numMintedPerRecipient[minter];
        currentTotalSupply = numMinted;
        maxSupply = _maxSupply;
    }
}
