// SPDX-License Identifier: MIT
pragma solidity 0.8.17;

import {ERC721SeaDrop} from "./ERC721SeaDrop.sol";
import {Strings} from "openzeppelin-contracts/utils/Strings.sol";
import {IERC721TL} from "./IERC721TL.sol";

/// @title ERC721TL Seadrop Shim
/// @notice Hacky contract that acts as a shim for minting ERC721TL or ERC7160TL tokens from Seadrop v1
/// @author Transient Labs, Inc.

contract ERC721TLSeadropShim is ERC721SeaDrop {
    using Strings for uint256;

    ///////////////////////////////////////////////////////////
    // Storage
    ///////////////////////////////////////////////////////////

    IERC721TL public creatorContract;
    string private _baseUri;
    mapping(address => uint256) private _numMintedPerRecipient; // recipient -> number minted
    uint256 public numMinted;

    ///////////////////////////////////////////////////////////
    // Constructor
    ///////////////////////////////////////////////////////////
    constructor(
        string memory name,
        string memory symbol,
        address creatorContractToMintTo,
        string memory baseUriToMint,
        address[] memory allowedSeaDrop
    ) ERC721SeaDrop(name, symbol, allowedSeaDrop) {
        creatorContract = IERC721TL(creatorContractToMintTo);
        _baseUri = baseUriToMint;
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

        // Cache variable
        uint256 uriCounter = numMinted;

        // Update state variables
        _numMintedPerRecipient[minter] += quantity;
        numMinted += quantity;

        // Mint the tokens to the minter
        for (uint256 i = 0; i < quantity; i++) {
            creatorContract.externalMint(minter, string(abi.encodePacked(_baseUri, "/", (uriCounter + i).toString())));
        }
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
