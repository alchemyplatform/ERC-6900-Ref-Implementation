// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {PackedUserOperation} from "@eth-infinitism/account-abstraction/interfaces/PackedUserOperation.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import {IEntryPoint} from "@eth-infinitism/account-abstraction/interfaces/IEntryPoint.sol";

import {UpgradeableModularAccount} from "../../src/account/UpgradeableModularAccount.sol";

import {ModuleEntityLib} from "../../src/helpers/ModuleEntityLib.sol";
import {ValidationConfigLib} from "../../src/helpers/ValidationConfigLib.sol";
import {ModuleEntity} from "../../src/interfaces/IModuleManager.sol";
import {IStandardExecutor} from "../../src/interfaces/IStandardExecutor.sol";
import {SingleSignerValidation} from "../../src/modules/validation/SingleSignerValidation.sol";

import {AccountTestBase} from "../utils/AccountTestBase.sol";
import {TEST_DEFAULT_VALIDATION_ENTITY_ID} from "../utils/TestConstants.sol";

contract MultiValidationTest is AccountTestBase {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    SingleSignerValidation public validator2;

    address public owner2;
    uint256 public owner2Key;

    function setUp() public {
        validator2 = new SingleSignerValidation();

        (owner2, owner2Key) = makeAddrAndKey("owner2");
    }

    function test_overlappingValidationInstall() public {
        vm.prank(address(entryPoint));
        account1.installValidation(
            ValidationConfigLib.pack(address(validator2), TEST_DEFAULT_VALIDATION_ENTITY_ID, true, true),
            new bytes4[](0),
            abi.encode(TEST_DEFAULT_VALIDATION_ENTITY_ID, owner2),
            "",
            ""
        );

        ModuleEntity[] memory validations = new ModuleEntity[](2);
        validations[0] = ModuleEntityLib.pack(address(singleSignerValidation), TEST_DEFAULT_VALIDATION_ENTITY_ID);
        validations[1] = ModuleEntityLib.pack(address(validator2), TEST_DEFAULT_VALIDATION_ENTITY_ID);

        bytes4[] memory selectors0 = account1.getSelectors(validations[0]);
        bytes4[] memory selectors1 = account1.getSelectors(validations[1]);
        assertEq(selectors0.length, selectors1.length);
        for (uint256 i = 0; i < selectors0.length; i++) {
            assertEq(selectors0[i], selectors1[i]);
        }
    }

    function test_runtimeValidation_specify() public {
        test_overlappingValidationInstall();

        // Assert that the runtime validation can be specified.

        vm.prank(owner1);
        vm.expectRevert(
            abi.encodeWithSelector(
                UpgradeableModularAccount.RuntimeValidationFunctionReverted.selector,
                address(validator2),
                1,
                abi.encodeWithSignature("NotAuthorized()")
            )
        );
        account1.executeWithAuthorization(
            abi.encodeCall(IStandardExecutor.execute, (address(0), 0, "")),
            _encodeSignature(
                ModuleEntityLib.pack(address(validator2), TEST_DEFAULT_VALIDATION_ENTITY_ID), GLOBAL_VALIDATION, ""
            )
        );

        vm.prank(owner2);
        account1.executeWithAuthorization(
            abi.encodeCall(IStandardExecutor.execute, (address(0), 0, "")),
            _encodeSignature(
                ModuleEntityLib.pack(address(validator2), TEST_DEFAULT_VALIDATION_ENTITY_ID), GLOBAL_VALIDATION, ""
            )
        );
    }

    function test_userOpValidation_specify() public {
        test_overlappingValidationInstall();

        // Assert that the userOp validation can be specified.

        PackedUserOperation memory userOp = PackedUserOperation({
            sender: address(account1),
            nonce: 0,
            initCode: "",
            callData: abi.encodeCall(UpgradeableModularAccount.execute, (address(0), 0, "")),
            accountGasLimits: _encodeGas(VERIFICATION_GAS_LIMIT, CALL_GAS_LIMIT),
            preVerificationGas: 0,
            gasFees: _encodeGas(1, 1),
            paymasterAndData: "",
            signature: ""
        });

        // Generate signature
        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(owner2Key, userOpHash.toEthSignedMessageHash());
        userOp.signature = _encodeSignature(
            ModuleEntityLib.pack(address(validator2), TEST_DEFAULT_VALIDATION_ENTITY_ID),
            GLOBAL_VALIDATION,
            abi.encodePacked(r, s, v)
        );

        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;

        entryPoint.handleOps(userOps, beneficiary);

        // Sign with owner 1, expect fail

        userOp.nonce = 1;
        (v, r, s) = vm.sign(owner1Key, userOpHash.toEthSignedMessageHash());
        userOp.signature = _encodeSignature(
            ModuleEntityLib.pack(address(validator2), TEST_DEFAULT_VALIDATION_ENTITY_ID),
            GLOBAL_VALIDATION,
            abi.encodePacked(r, s, v)
        );

        userOps[0] = userOp;
        vm.expectRevert(abi.encodeWithSelector(IEntryPoint.FailedOp.selector, 0, "AA24 signature error"));
        entryPoint.handleOps(userOps, beneficiary);
    }
}
