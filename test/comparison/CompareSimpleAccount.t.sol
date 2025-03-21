// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {IEntryPoint} from "@eth-infinitism/account-abstraction/interfaces/IEntryPoint.sol";
import {PackedUserOperation} from "@eth-infinitism/account-abstraction/interfaces/PackedUserOperation.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import {SimpleAccount} from "@eth-infinitism/account-abstraction/samples/SimpleAccount.sol";
import {SimpleAccountFactory} from "@eth-infinitism/account-abstraction/samples/SimpleAccountFactory.sol";

import {Counter} from "../mocks/Counter.sol";
import {EntryPointUtils} from "../utils/EntryPointUtils.sol";

contract CompareSimpleAccountTest is Test, EntryPointUtils {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    IEntryPoint public entryPoint;
    address payable public beneficiary;

    SimpleAccountFactory public factory;

    // Owner 1 deploys account contract in the same transaction
    address public owner1;
    uint256 public owner1Key;
    address public account1;

    // owner 2 pre-deploys account contract
    address public owner2;
    uint256 public owner2Key;
    address public account2;

    Counter public counter;

    uint256 public constant CALL_GAS_LIMIT = 500_000;
    uint256 public constant VERIFICATION_GAS_LIMIT = 500_000;

    // helper function to compress 2 gas values into a single bytes32
    function _encodeGas(uint256 g1, uint256 g2) internal pure returns (bytes32) {
        return bytes32(uint256((g1 << 128) + uint128(g2)));
    }

    function setUp() public {
        entryPoint = _deployEntryPoint();
        (owner1, owner1Key) = makeAddrAndKey("owner1");
        beneficiary = payable(makeAddr("beneficiary"));
        vm.deal(beneficiary, 1 wei);

        factory = new SimpleAccountFactory(entryPoint);
        account1 = factory.getAddress(owner1, 0);
        vm.deal(account1, 100 ether);

        counter = new Counter();
        counter.increment();

        // Pre-generate account 2
        (owner2, owner2Key) = makeAddrAndKey("owner2");
        account2 = address(factory.createAccount(owner2, 0));
        vm.deal(account2, 100 ether);
        vm.prank(account2);
        entryPoint.depositTo{value: 1 wei}(account2);
    }

    function test_SimpleAccount_deploy_basicSend() public {
        PackedUserOperation memory userOp = PackedUserOperation({
            sender: account1,
            nonce: 0,
            initCode: abi.encodePacked(address(factory), abi.encodeCall(factory.createAccount, (owner1, 0))),
            callData: abi.encodeCall(SimpleAccount.execute, (beneficiary, 1, "")),
            accountGasLimits: _encodeGas(VERIFICATION_GAS_LIMIT, CALL_GAS_LIMIT),
            preVerificationGas: 0,
            gasFees: _encodeGas(1, 2),
            paymasterAndData: "",
            signature: ""
        });

        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(owner1Key, userOpHash.toEthSignedMessageHash());
        userOp.signature = abi.encodePacked(r, s, v);

        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;

        entryPoint.handleOps(userOps, beneficiary);
    }

    function test_SimpleAccount_deploy_empty() public {
        PackedUserOperation memory userOp = PackedUserOperation({
            sender: account1,
            nonce: 0,
            initCode: abi.encodePacked(address(factory), abi.encodeCall(factory.createAccount, (owner1, 0))),
            callData: "",
            accountGasLimits: _encodeGas(VERIFICATION_GAS_LIMIT, CALL_GAS_LIMIT),
            preVerificationGas: 0,
            gasFees: _encodeGas(1, 2),
            paymasterAndData: "",
            signature: ""
        });

        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(owner1Key, userOpHash.toEthSignedMessageHash());
        userOp.signature = abi.encodePacked(r, s, v);

        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;

        entryPoint.handleOps(userOps, beneficiary);
    }

    function test_SimpleAccount_postDeploy_basicSend() public {
        PackedUserOperation memory userOp = PackedUserOperation({
            sender: account2,
            nonce: 0,
            initCode: "",
            callData: abi.encodeCall(SimpleAccount.execute, (beneficiary, 1, "")),
            accountGasLimits: _encodeGas(VERIFICATION_GAS_LIMIT, CALL_GAS_LIMIT),
            preVerificationGas: 0,
            gasFees: _encodeGas(1, 2),
            paymasterAndData: "",
            signature: ""
        });

        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(owner2Key, userOpHash.toEthSignedMessageHash());
        userOp.signature = abi.encodePacked(r, s, v);

        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;

        entryPoint.handleOps(userOps, beneficiary);
    }

    function test_SimpleAccount_postDeploy_contractInteraction() public {
        PackedUserOperation memory userOp = PackedUserOperation({
            sender: account2,
            nonce: 0,
            initCode: "",
            callData: abi.encodeCall(
                SimpleAccount.execute, (address(counter), 0, abi.encodeCall(Counter.increment, ()))
            ),
            accountGasLimits: _encodeGas(VERIFICATION_GAS_LIMIT, CALL_GAS_LIMIT),
            preVerificationGas: 0,
            gasFees: _encodeGas(1, 2),
            paymasterAndData: "",
            signature: ""
        });

        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(owner2Key, userOpHash.toEthSignedMessageHash());
        userOp.signature = abi.encodePacked(r, s, v);

        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;

        entryPoint.handleOps(userOps, beneficiary);

        assertEq(counter.number(), 2);
    }
}
