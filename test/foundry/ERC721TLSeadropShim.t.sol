// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {TestHelper} from "test/foundry/utils/TestHelper.sol";

import {SeaDrop} from "seadrop/SeaDrop.sol";

import {ERC721TLSeadropShim} from "seadrop/ERC721TLSeadropShim.sol";

import {INonFungibleSeaDropToken} from "seadrop/interfaces/INonFungibleSeaDropToken.sol";

import {PublicDrop} from "seadrop/lib/SeaDropStructs.sol";

import {MaliciousRecipient} from "seadrop/test/MaliciousRecipient.sol";

import {MockERC721TL} from "./utils/MockERC721TL.sol";

contract ERC721TLSeadropShimTest is TestHelper {
    MaliciousRecipient attacker;
    ERC721TLSeadropShim public shim;
    MockERC721TL public erc721tl;

    function setUp() public {
        attacker = new MaliciousRecipient();
        // Deploy the 1155 shim
        erc721tl = new MockERC721TL();

        // Deploy the shim contract.
        address[] memory allowedSeaDrop = new address[](1);
        allowedSeaDrop[0] = address(seadrop);
        shim = new ERC721TLSeadropShim("", "", address(erc721tl), "uri", allowedSeaDrop);

        // Set the max supply to 1000.
        shim.setMaxSupply(1000);

        // Set the creator payout address.
        shim.updateCreatorPayoutAddress(address(seadrop), creator);

        // Create the public drop stage.
        PublicDrop memory publicDrop = PublicDrop(
            0.1 ether, // mint price
            uint48(block.timestamp), // start time
            uint48(block.timestamp) + 100, // end time
            10, // max mints per wallet
            100, // fee (1%)
            false // if false, allow any fee recipient
        );

        // Set the public drop for the shim contract.
        shim.updatePublicDrop(address(seadrop), publicDrop);
    }

    function testMintPublicReenter() public payable {
        // Create the public drop stage.
        PublicDrop memory publicDrop = PublicDrop(
            1 ether, // mint price
            uint48(block.timestamp), // start time
            uint48(block.timestamp) + 100, // end time
            1, // max mints per wallet
            100, // fee (1%)
            false // if false, allow any fee recipient
                // If true, then only the fee recipient can perform the attack
        );
        vm.prank(address(shim));
        seadrop.updatePublicDrop(publicDrop);

        assert(!attacker.startAttack());
        // send some eth and set startAttack
        attacker.setStartAttack{value: 10 ether}();
        assert(attacker.startAttack());

        assertEq(shim.balanceOf(address(attacker)), 0);
        assertEq(uint256(seadrop.getPublicDrop(address(shim)).maxTotalMintableByWallet), 1);

        // expect fail on reentrancy
        vm.expectRevert("ETH_TRANSFER_FAILED");
        attacker.attack(seadrop, address(shim));
    }

    function testMintPublic(FuzzInputs memory args) public validateArgs(args) {
        PublicDrop memory publicDrop = seadrop.getPublicDrop(address(shim));

        uint256 mintValue = args.numMints * publicDrop.mintPrice;

        hoax(args.minter, 100 ether);

        uint256 preMinterBalance = args.minter.balance;
        uint256 preFeeRecipientBalance = args.feeRecipient.balance;
        uint256 preCreatorBalance = creator.balance;

        seadrop.mintPublic{value: mintValue}(address(shim), args.feeRecipient, args.minter, args.numMints);

        // Check minter shim balance increased.
        assertEq(erc721tl.balanceOf(args.minter), args.numMints);
        assertEq(erc721tl.ownerOf(1), args.minter);
        assertEq(shim.numMinted(), args.numMints);
        (uint256 minterNumMinted, uint256 currentTotalSupply, uint256 maxSupply) = shim.getMintStats(args.minter);
        assertEq(minterNumMinted, args.numMints);
        assertEq(currentTotalSupply, args.numMints);
        assertEq(maxSupply, shim.maxSupply());

        // Check minter ether balance decreased.
        assertEq(preMinterBalance - mintValue, args.minter.balance);

        // Check fee recipient ether balance increased.
        uint256 feeAmount = (mintValue * 100) / 10_000;
        assertEq(preFeeRecipientBalance + feeAmount, args.feeRecipient.balance);

        // Check creator ether balance increased.
        uint256 payoutAmount = mintValue - feeAmount;
        assertEq(preCreatorBalance + payoutAmount, creator.balance);
    }

    function testMintPublic_incorrectPayment(FuzzInputs memory args) public validateArgs(args) {
        PublicDrop memory publicDrop = seadrop.getPublicDrop(address(shim));
        uint256 mintValue = args.numMints * publicDrop.mintPrice;

        vm.expectRevert(abi.encodeWithSelector(IncorrectPayment.selector, 1, mintValue));

        hoax(args.minter, 100 ether);

        seadrop.mintPublic{value: 1 wei}(address(shim), args.feeRecipient, args.minter, args.numMints);
    }

    function testMintPublic_freeMint(FuzzInputs memory args) public validateArgs(args) {
        // Create public drop object with free mint.
        PublicDrop memory publicDrop = PublicDrop(
            0 ether, // mint price (free)
            uint48(block.timestamp), // start time
            uint48(block.timestamp) + 100, // end time
            10, // max mints per wallet
            100, // fee (1%)
            false // if false, allow any fee recipient
        );

        vm.prank(address(shim));
        // Set the public drop for the erc721 contract.
        seadrop.updatePublicDrop(publicDrop);

        vm.prank(args.minter);

        seadrop.mintPublic(address(shim), args.feeRecipient, args.minter, args.numMints);

        // Check minter shim balance increased.
        assertEq(erc721tl.balanceOf(args.minter), args.numMints);
        assertEq(erc721tl.ownerOf(1), args.minter);
    }

    function testMintPublic_differentPayerThanMinter(FuzzInputs memory args) public validateArgs(args) {
        PublicDrop memory publicDrop = seadrop.getPublicDrop(address(shim));

        address payer = makeAddr("payer");

        // Allow the payer.
        shim.updatePayer(address(seadrop), payer, true);

        vm.assume(payer != creator && payer != args.minter && payer != args.feeRecipient);

        hoax(payer, 100 ether);

        uint256 mintValue = args.numMints * publicDrop.mintPrice;

        uint256 prePayerBalance = payer.balance;
        uint256 preFeeRecipientBalance = args.feeRecipient.balance;
        uint256 preCreatorBalance = creator.balance;

        seadrop.mintPublic{value: mintValue}(address(shim), args.feeRecipient, args.minter, args.numMints);

        // Check minter shim balance increased.
        assertEq(erc721tl.balanceOf(args.minter), args.numMints);
        assertEq(erc721tl.ownerOf(1), args.minter);

        // Check payer ether balance decreased.
        assertEq(prePayerBalance - mintValue, payer.balance);

        // Check fee recipient ether balance increased.
        uint256 feeAmount = (mintValue * 100) / 10_000;
        assertEq(preFeeRecipientBalance + feeAmount, args.feeRecipient.balance);

        // Check creator ether balance increased.
        uint256 payoutAmount = mintValue - feeAmount;
        assertEq(preCreatorBalance + payoutAmount, creator.balance);
    }

    function testMintSeaDrop_revertNonSeaDrop(FuzzInputs memory args) public validateArgs(args) {
        vm.expectRevert(INonFungibleSeaDropToken.OnlyAllowedSeaDrop.selector);
        shim.mintSeaDrop(args.minter, args.numMints);
    }
}
