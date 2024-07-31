// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {PackedUserOperation} from "@eth-infinitism/account-abstraction/interfaces/PackedUserOperation.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import {UpgradeableModularAccount} from "../../src/account/UpgradeableModularAccount.sol";

import {ModuleEntityLib} from "../../src/helpers/ModuleEntityLib.sol";
import {ModuleEntity} from "../../src/interfaces/IModuleManager.sol";

import {AccountTestBase} from "../utils/AccountTestBase.sol";

contract FallbackValidationTest is AccountTestBase {
    using MessageHashUtils for bytes32;

    address public ethRecipient;

    // A separate account and owner that isn't deployed yet, used to test initcode
    address public owner2;
    uint256 public owner2Key;
    UpgradeableModularAccount public account2;

    ModuleEntity constant FALLBACK_VALIDATION = ModuleEntity.wrap(bytes24(type(uint192).max));

    function setUp() public {
        (owner2, owner2Key) = makeAddrAndKey("owner2");

        // Compute counterfactual address
        account2 = UpgradeableModularAccount(payable(factory.getAddressFallbackSigner(owner2, 0)));
        vm.deal(address(account2), 100 ether);

        ethRecipient = makeAddr("ethRecipient");
        vm.deal(ethRecipient, 1 wei);
    }

    function test_fallbackValidation_userOp_simple() public {
        PackedUserOperation memory userOp = PackedUserOperation({
            sender: address(account2),
            nonce: 0,
            initCode: abi.encodePacked(
                address(factory), abi.encodeCall(factory.createAccountWithFallbackValidation, (owner2, 0))
            ),
            callData: abi.encodeCall(UpgradeableModularAccount.execute, (ethRecipient, 1 wei, "")),
            accountGasLimits: _encodeGas(VERIFICATION_GAS_LIMIT, CALL_GAS_LIMIT),
            preVerificationGas: 0,
            gasFees: _encodeGas(1, 1),
            paymasterAndData: "",
            signature: ""
        });

        // Generate signature
        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(owner2Key, userOpHash.toEthSignedMessageHash());
        userOp.signature = _encodeSignature(FALLBACK_VALIDATION, GLOBAL_VALIDATION, abi.encodePacked(r, s, v));

        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;

        entryPoint.handleOps(userOps, beneficiary);

        assertEq(ethRecipient.balance, 2 wei);
    }

    function test_fallbackValidation_runtime_simple() public {
        // Deploy the account first
        factory.createAccountWithFallbackValidation(owner2, 0);

        vm.prank(owner2);
        account2.executeWithAuthorization(
            abi.encodeCall(UpgradeableModularAccount.execute, (ethRecipient, 1 wei, "")),
            _encodeSignature(FALLBACK_VALIDATION, GLOBAL_VALIDATION, "")
        );

        assertEq(ethRecipient.balance, 2 wei);
    }
}
