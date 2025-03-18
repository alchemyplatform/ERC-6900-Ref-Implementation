// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import {EntryPoint} from "@eth-infinitism/account-abstraction/core/EntryPoint.sol";
import {PackedUserOperation} from "@eth-infinitism/account-abstraction/interfaces/PackedUserOperation.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import {ReferenceModularAccount} from "../../src/account/ReferenceModularAccount.sol";
import {SemiModularAccount} from "../../src/account/SemiModularAccount.sol";
import {Call, IERC6900Account} from "../../src/interfaces/IERC6900Account.sol";
import {ModuleEntity, ModuleEntityLib} from "../../src/libraries/ModuleEntityLib.sol";
import {SingleSignerValidationModule} from "../../src/modules/validation/SingleSignerValidationModule.sol";

import {ModuleSignatureUtils} from "./ModuleSignatureUtils.sol";
import {OptimizedTest} from "./OptimizedTest.sol";
import {TEST_DEFAULT_VALIDATION_ENTITY_ID as EXT_CONST_TEST_DEFAULT_VALIDATION_ENTITY_ID} from
    "./TestConstants.sol";

import {SingleSignerFactoryFixture} from "../mocks/SingleSignerFactoryFixture.sol";

/// @dev This contract handles common boilerplate setup for tests using ReferenceModularAccount with
/// SingleSignerValidationModule.
abstract contract AccountTestBase is OptimizedTest, ModuleSignatureUtils {
    using ModuleEntityLib for ModuleEntity;
    using MessageHashUtils for bytes32;

    EntryPoint public entryPoint;
    address payable public beneficiary;

    SingleSignerValidationModule public singleSignerValidationModule;
    SingleSignerFactoryFixture public factory;

    address public owner1;
    uint256 public owner1Key;
    ReferenceModularAccount public account1;

    ModuleEntity internal _signerValidation;

    // Re-declare the constant to prevent derived test contracts from having to import it
    uint32 public constant TEST_DEFAULT_VALIDATION_ENTITY_ID = EXT_CONST_TEST_DEFAULT_VALIDATION_ENTITY_ID;

    uint256 public constant CALL_GAS_LIMIT = 100_000;
    uint256 public constant VERIFICATION_GAS_LIMIT = 1_200_000;

    constructor() {
        entryPoint = new EntryPoint();
        (owner1, owner1Key) = makeAddrAndKey("owner1");
        beneficiary = payable(makeAddr("beneficiary"));

        address deployedSingleSignerValidation = address(_deploySingleSignerValidationModule());

        // We etch the single signer validation to the max address, such that it coincides with the fallback
        // validation module entity for semi modular account tests.
        singleSignerValidationModule = SingleSignerValidationModule(address(type(uint160).max));
        vm.etch(address(singleSignerValidationModule), deployedSingleSignerValidation.code);

        factory = new SingleSignerFactoryFixture(entryPoint, singleSignerValidationModule);

        account1 = factory.createAccount(owner1, 0);
        vm.deal(address(account1), 100 ether);

        _signerValidation =
            ModuleEntityLib.pack(address(singleSignerValidationModule), TEST_DEFAULT_VALIDATION_ENTITY_ID);
    }

    function _runExecUserOp(address target, bytes memory callData) internal {
        _runUserOp(abi.encodeCall(IERC6900Account.execute, (target, 0, callData)));
    }

    function _runExecUserOp(address target, bytes memory callData, bytes memory revertReason) internal {
        _runUserOp(abi.encodeCall(IERC6900Account.execute, (target, 0, callData)), revertReason);
    }

    function _runExecBatchUserOp(Call[] memory calls) internal {
        _runUserOp(abi.encodeCall(IERC6900Account.executeBatch, (calls)));
    }

    function _runExecBatchUserOp(Call[] memory calls, bytes memory revertReason) internal {
        _runUserOp(abi.encodeCall(IERC6900Account.executeBatch, (calls)), revertReason);
    }

    function _runUserOp(bytes memory callData) internal {
        // Run user op without expecting a revert
        _runUserOp(callData, hex"");
    }

    function _runUserOp(bytes memory callData, bytes memory expectedRevertData) internal {
        uint256 nonce = entryPoint.getNonce(address(account1), 0);

        PackedUserOperation memory userOp = PackedUserOperation({
            sender: address(account1),
            nonce: nonce,
            initCode: hex"",
            callData: callData,
            accountGasLimits: _encodeGas(VERIFICATION_GAS_LIMIT, CALL_GAS_LIMIT),
            preVerificationGas: 0,
            gasFees: _encodeGas(1, 1),
            paymasterAndData: hex"",
            signature: hex""
        });

        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(owner1Key, userOpHash.toEthSignedMessageHash());

        userOp.signature = _encodeSignature(_signerValidation, GLOBAL_VALIDATION, abi.encodePacked(r, s, v));

        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;

        if (expectedRevertData.length > 0) {
            vm.expectRevert(expectedRevertData);
        }
        entryPoint.handleOps(userOps, beneficiary);
    }

    function _runtimeExec(address target, bytes memory callData) internal {
        _runtimeCall(abi.encodeCall(IERC6900Account.execute, (target, 0, callData)));
    }

    function _runtimeExec(address target, bytes memory callData, bytes memory expectedRevertData) internal {
        _runtimeCall(abi.encodeCall(IERC6900Account.execute, (target, 0, callData)), expectedRevertData);
    }

    function _runtimeExecExpFail(address target, bytes memory callData, bytes memory expectedRevertData)
        internal
    {
        _runtimeCallExpFail(abi.encodeCall(IERC6900Account.execute, (target, 0, callData)), expectedRevertData);
    }

    function _runtimeExecBatch(Call[] memory calls) internal {
        _runtimeCall(abi.encodeCall(IERC6900Account.executeBatch, (calls)));
    }

    function _runtimeExecBatch(Call[] memory calls, bytes memory expectedRevertData) internal {
        _runtimeCall(abi.encodeCall(IERC6900Account.executeBatch, (calls)), expectedRevertData);
    }

    function _runtimeExecBatchExpFail(Call[] memory calls, bytes memory expectedRevertData) internal {
        _runtimeCallExpFail(abi.encodeCall(IERC6900Account.executeBatch, (calls)), expectedRevertData);
    }

    function _runtimeCall(bytes memory callData) internal {
        _runtimeCall(callData, "");
    }

    function _runtimeCall(bytes memory callData, bytes memory expectedRevertData) internal {
        if (expectedRevertData.length > 0) {
            vm.expectRevert(expectedRevertData);
        }

        vm.prank(owner1);
        account1.executeWithRuntimeValidation(callData, _encodeSignature(_signerValidation, GLOBAL_VALIDATION, ""));
    }

    // Always expects a revert, even if the revert data is zero-length.
    function _runtimeCallExpFail(bytes memory callData, bytes memory expectedRevertData) internal {
        vm.expectRevert(expectedRevertData);

        vm.prank(owner1);
        account1.executeWithRuntimeValidation(callData, _encodeSignature(_signerValidation, GLOBAL_VALIDATION, ""));
    }

    function _transferOwnershipToTest() internal {
        // Transfer ownership to test contract for easier invocation.
        vm.prank(owner1);
        if (vm.envOr("SMA_TEST", false)) {
            account1.executeWithRuntimeValidation(
                abi.encodeCall(SemiModularAccount(payable(account1)).updateFallbackSigner, (address(this))),
                _encodeSignature(_signerValidation, GLOBAL_VALIDATION, "")
            );
            return;
        }
        account1.executeWithRuntimeValidation(
            abi.encodeCall(
                account1.execute,
                (
                    address(singleSignerValidationModule),
                    0,
                    abi.encodeCall(
                        SingleSignerValidationModule.transferSigner,
                        (TEST_DEFAULT_VALIDATION_ENTITY_ID, address(this))
                    )
                )
            ),
            _encodeSignature(_signerValidation, GLOBAL_VALIDATION, "")
        );
    }

    // helper function to compress 2 gas values into a single bytes32
    function _encodeGas(uint256 g1, uint256 g2) internal pure returns (bytes32) {
        return bytes32(uint256((g1 << 128) + uint128(g2)));
    }
}
