// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import {IEntryPoint} from "@eth-infinitism/account-abstraction/interfaces/IEntryPoint.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import {ReferenceModularAccount} from "../../src/account/ReferenceModularAccount.sol";
import {TokenReceiverModule} from "../../src/modules/TokenReceiverModule.sol";

import {MockERC1155} from "../mocks/MockERC1155.sol";
import {MockERC721} from "../mocks/MockERC721.sol";
import {SingleSignerFactoryFixture} from "../mocks/SingleSignerFactoryFixture.sol";

import {EntryPointUtils} from "../utils/EntryPointUtils.sol";
import {OptimizedTest} from "../utils/OptimizedTest.sol";

contract TokenReceiverModuleTest is OptimizedTest, IERC1155Receiver, EntryPointUtils {
    IEntryPoint public entryPoint;
    ReferenceModularAccount public acct;
    TokenReceiverModule public module;

    MockERC721 public t0;
    MockERC1155 public t1;

    // init dynamic length arrays for use in args
    address[] public defaultOperators;
    uint256[] public tokenIds;
    uint256[] public tokenAmts;
    uint256[] public zeroTokenAmts;

    uint256 internal constant _TOKEN_AMOUNT = 1 ether;
    uint256 internal constant _TOKEN_ID = 0;
    uint256 internal constant _BATCH_TOKEN_IDS = 5;

    function setUp() public {
        entryPoint = _deployEntryPoint();
        SingleSignerFactoryFixture factory =
            new SingleSignerFactoryFixture(entryPoint, _deploySingleSignerValidationModule());

        acct = factory.createAccount(address(this), 0);
        module = _deployTokenReceiverModule();

        t0 = new MockERC721("t0", "t0");
        t0.mint(address(this), _TOKEN_ID);

        t1 = new MockERC1155();
        t1.mint(address(this), _TOKEN_ID, _TOKEN_AMOUNT);
        for (uint256 i = 1; i < _BATCH_TOKEN_IDS; i++) {
            t1.mint(address(this), i, _TOKEN_AMOUNT);
            tokenIds.push(i);
            tokenAmts.push(_TOKEN_AMOUNT);
            zeroTokenAmts.push(0);
        }
    }

    function _initModule() internal {
        vm.startPrank(address(entryPoint));
        acct.installExecution(address(module), module.executionManifest(), "");
        vm.stopPrank();
    }

    function test_failERC721Transfer() public {
        vm.expectRevert(
            abi.encodePacked(
                ReferenceModularAccount.UnrecognizedFunction.selector,
                IERC721Receiver.onERC721Received.selector,
                bytes28(0)
            )
        );
        t0.safeTransferFrom(address(this), address(acct), _TOKEN_ID);
    }

    function test_passERC721Transfer() public {
        _initModule();
        assertEq(t0.ownerOf(_TOKEN_ID), address(this));
        t0.safeTransferFrom(address(this), address(acct), _TOKEN_ID);
        assertEq(t0.ownerOf(_TOKEN_ID), address(acct));
    }

    function test_failERC1155Transfer() public {
        // for 1155, reverts are caught in a try catch and bubbled up with the reason from the account
        vm.expectRevert(
            abi.encodePacked(
                ReferenceModularAccount.UnrecognizedFunction.selector,
                IERC1155Receiver.onERC1155Received.selector,
                bytes28(0)
            )
        );
        t1.safeTransferFrom(address(this), address(acct), _TOKEN_ID, _TOKEN_AMOUNT, "");

        // for 1155, reverts are caught in a try catch and bubbled up with the reason from the account
        vm.expectRevert(
            abi.encodePacked(
                ReferenceModularAccount.UnrecognizedFunction.selector,
                IERC1155Receiver.onERC1155BatchReceived.selector,
                bytes28(0)
            )
        );
        t1.safeBatchTransferFrom(address(this), address(acct), tokenIds, tokenAmts, "");
    }

    function test_passERC1155Transfer() public {
        _initModule();

        assertEq(t1.balanceOf(address(this), _TOKEN_ID), _TOKEN_AMOUNT);
        assertEq(t1.balanceOf(address(acct), _TOKEN_ID), 0);
        t1.safeTransferFrom(address(this), address(acct), _TOKEN_ID, _TOKEN_AMOUNT, "");
        assertEq(t1.balanceOf(address(this), _TOKEN_ID), 0);
        assertEq(t1.balanceOf(address(acct), _TOKEN_ID), _TOKEN_AMOUNT);

        for (uint256 i = 1; i < _BATCH_TOKEN_IDS; i++) {
            assertEq(t1.balanceOf(address(this), i), _TOKEN_AMOUNT);
            assertEq(t1.balanceOf(address(acct), i), 0);
        }
        t1.safeBatchTransferFrom(address(this), address(acct), tokenIds, tokenAmts, "");
        for (uint256 i = 1; i < _BATCH_TOKEN_IDS; i++) {
            assertEq(t1.balanceOf(address(this), i), 0);
            assertEq(t1.balanceOf(address(acct), i), _TOKEN_AMOUNT);
        }
    }

    function test_failIntrospection() public {
        bool isSupported;

        isSupported = acct.supportsInterface(type(IERC721Receiver).interfaceId);
        assertEq(isSupported, false);
        isSupported = acct.supportsInterface(type(IERC1155Receiver).interfaceId);
        assertEq(isSupported, false);
    }

    function test_passIntrospection() public {
        _initModule();

        bool isSupported;

        isSupported = acct.supportsInterface(type(IERC721Receiver).interfaceId);
        assertEq(isSupported, true);
        isSupported = acct.supportsInterface(type(IERC1155Receiver).interfaceId);
        assertEq(isSupported, true);
    }

    /**
     * NON-TEST FUNCTIONS - USED SO MINT DOESNT FAIL
     */
    function onERC1155Received(address, address, uint256, uint256, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        return IERC1155Receiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }

    function supportsInterface(bytes4) external pure override returns (bool) {
        return false;
    }
}
