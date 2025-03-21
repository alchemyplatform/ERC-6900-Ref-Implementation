// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import {PackedUserOperation} from "@eth-infinitism/account-abstraction/interfaces/PackedUserOperation.sol";

import {
    ExecutionManifest,
    IERC6900ExecutionModule,
    ManifestExecutionFunction,
    ManifestExecutionHook
} from "../../../src/interfaces/IERC6900ExecutionModule.sol";

import {IERC6900ExecutionHookModule} from "../../../src/interfaces/IERC6900ExecutionHookModule.sol";
import {IERC6900ExecutionModule} from "../../../src/interfaces/IERC6900ExecutionModule.sol";

import {IERC6900ValidationHookModule} from "../../../src/interfaces/IERC6900ValidationHookModule.sol";
import {IERC6900ValidationModule} from "../../../src/interfaces/IERC6900ValidationModule.sol";

import {BaseModule} from "../../../src/modules/BaseModule.sol";

contract ComprehensiveModule is
    IERC6900ExecutionModule,
    IERC6900ValidationModule,
    IERC6900ValidationHookModule,
    IERC6900ExecutionHookModule,
    BaseModule
{
    enum EntityId {
        PRE_VALIDATION_HOOK_1,
        PRE_VALIDATION_HOOK_2,
        VALIDATION,
        BOTH_EXECUTION_HOOKS,
        PRE_EXECUTION_HOOK,
        POST_EXECUTION_HOOK,
        SIG_VALIDATION
    }

    string internal constant _NAME = "Comprehensive Module";
    string internal constant _VERSION = "1.0.0";
    string internal constant _AUTHOR = "ERC-6900 Authors";

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃    Execution functions    ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function foo() external {}

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃    Module interface functions    ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function onInstall(bytes calldata) external override {}

    function onUninstall(bytes calldata) external override {}

    function preUserOpValidationHook(uint32 entityId, PackedUserOperation calldata, bytes32)
        external
        pure
        override
        returns (uint256)
    {
        if (entityId == uint32(EntityId.PRE_VALIDATION_HOOK_1)) {
            return 0;
        } else if (entityId == uint32(EntityId.PRE_VALIDATION_HOOK_2)) {
            return 0;
        }
        revert NotImplemented();
    }

    function validateUserOp(uint32 entityId, PackedUserOperation calldata, bytes32)
        external
        pure
        override
        returns (uint256)
    {
        if (entityId == uint32(EntityId.VALIDATION)) {
            return 0;
        }
        revert NotImplemented();
    }

    function preRuntimeValidationHook(uint32 entityId, address, uint256, bytes calldata, bytes calldata)
        external
        pure
        override
    {
        if (entityId == uint32(EntityId.PRE_VALIDATION_HOOK_1)) {
            return;
        } else if (entityId == uint32(EntityId.PRE_VALIDATION_HOOK_2)) {
            return;
        }
        revert NotImplemented();
    }

    function validateRuntime(address, uint32 entityId, address, uint256, bytes calldata, bytes calldata)
        external
        pure
        override
    {
        if (entityId == uint32(EntityId.VALIDATION)) {
            return;
        }
        revert NotImplemented();
    }

    function preSignatureValidationHook(uint32, address, bytes32, bytes calldata) external pure override {
        return;
    }

    function validateSignature(address, uint32 entityId, address, bytes32, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        if (entityId == uint32(EntityId.SIG_VALIDATION)) {
            return 0xffffffff;
        }
        revert NotImplemented();
    }

    function preExecutionHook(uint32 entityId, address, uint256, bytes calldata)
        external
        pure
        override
        returns (bytes memory)
    {
        if (entityId == uint32(EntityId.PRE_EXECUTION_HOOK)) {
            return "";
        } else if (entityId == uint32(EntityId.BOTH_EXECUTION_HOOKS)) {
            return "";
        }
        revert NotImplemented();
    }

    function postExecutionHook(uint32 entityId, bytes calldata) external pure override {
        if (entityId == uint32(EntityId.POST_EXECUTION_HOOK)) {
            return;
        } else if (entityId == uint32(EntityId.BOTH_EXECUTION_HOOKS)) {
            return;
        }
        revert NotImplemented();
    }

    function executionManifest() external pure override returns (ExecutionManifest memory) {
        ExecutionManifest memory manifest;

        manifest.executionFunctions = new ManifestExecutionFunction[](1);
        manifest.executionFunctions[0] = ManifestExecutionFunction({
            executionSelector: this.foo.selector,
            skipRuntimeValidation: false,
            allowGlobalValidation: false
        });

        manifest.executionHooks = new ManifestExecutionHook[](3);
        manifest.executionHooks[0] = ManifestExecutionHook({
            executionSelector: this.foo.selector,
            entityId: uint32(EntityId.BOTH_EXECUTION_HOOKS),
            isPreHook: true,
            isPostHook: true
        });
        manifest.executionHooks[1] = ManifestExecutionHook({
            executionSelector: this.foo.selector,
            entityId: uint32(EntityId.PRE_EXECUTION_HOOK),
            isPreHook: true,
            isPostHook: false
        });
        manifest.executionHooks[2] = ManifestExecutionHook({
            executionSelector: this.foo.selector,
            entityId: uint32(EntityId.POST_EXECUTION_HOOK),
            isPreHook: false,
            isPostHook: true
        });

        return manifest;
    }

    function moduleId() external pure returns (string memory) {
        return "erc6900.comprehensive-module.1.0.0";
    }
}
