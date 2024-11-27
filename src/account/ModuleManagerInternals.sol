// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import {ERC165Checker} from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {collectReturnData} from "../helpers/CollectReturnData.sol";
import {MAX_VALIDATION_ASSOC_HOOKS} from "../helpers/Constants.sol";
import {IExecutionHookModule} from "../interfaces/IExecutionHookModule.sol";
import {ExecutionManifest, ManifestExecutionHook} from "../interfaces/IExecutionModule.sol";
import {
    HookConfig,
    IModularAccount,
    ModuleEntity,
    ValidationConfig,
    ValidationFlags
} from "../interfaces/IModularAccount.sol";
import {IModule} from "../interfaces/IModule.sol";
import {IValidationHookModule} from "../interfaces/IValidationHookModule.sol";
import {IValidationModule} from "../interfaces/IValidationModule.sol";
import {HookConfigLib} from "../libraries/HookConfigLib.sol";
import {KnownSelectorsLib} from "../libraries/KnownSelectorsLib.sol";
import {ModuleEntityLib} from "../libraries/ModuleEntityLib.sol";
import {ValidationConfigLib} from "../libraries/ValidationConfigLib.sol";

import {
    AccountStorage,
    ExecutionStorage,
    ValidationStorage,
    getAccountStorage,
    toModuleEntity,
    toSetValue
} from "./AccountStorage.sol";

abstract contract ModuleManagerInternals is IModularAccount {
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using ModuleEntityLib for ModuleEntity;
    using ValidationConfigLib for ValidationConfig;
    using HookConfigLib for HookConfig;

    error ArrayLengthMismatch();
    error Erc4337FunctionNotAllowed(bytes4 selector);
    error ExecutionFunctionAlreadySet(bytes4 selector);
    error IModuleFunctionNotAllowed(bytes4 selector);
    error InterfaceNotSupported(address module);
    error NativeFunctionNotAllowed(bytes4 selector);
    error NullModule();
    error ExecutionHookAlreadySet(HookConfig hookConfig);
    error ModuleInstallCallbackFailed(address module, bytes revertReason);
    error ModuleNotInstalled(address module);
    error PreValidationHookLimitExceeded();
    error ValidationAlreadySet(bytes4 selector, ModuleEntity validationFunction);

    // Storage update operations

    function _setExecutionFunction(
        bytes4 selector,
        bool skipRuntimeValidation,
        bool allowGlobalValidation,
        address module
    ) internal {
        ExecutionStorage storage _executionStorage = getAccountStorage().executionStorage[selector];

        if (_executionStorage.module != address(0)) {
            revert ExecutionFunctionAlreadySet(selector);
        }

        // Make sure incoming execution function does not collide with any native functions (data are stored on the
        // account implementation contract)
        if (KnownSelectorsLib.isNativeFunction(selector)) {
            revert NativeFunctionNotAllowed(selector);
        }

        // Make sure incoming execution function is not a function in IModule
        if (KnownSelectorsLib.isIModuleFunction(selector)) {
            revert IModuleFunctionNotAllowed(selector);
        }

        // Also make sure it doesn't collide with functions defined by ERC-4337
        // and called by the entry point. This prevents a malicious module from
        // sneaking in a function with the same selector as e.g.
        // `validatePaymasterUserOp` and turning the account into their own
        // personal paymaster.
        if (KnownSelectorsLib.isErc4337Function(selector)) {
            revert Erc4337FunctionNotAllowed(selector);
        }

        _executionStorage.module = module;
        _executionStorage.skipRuntimeValidation = skipRuntimeValidation;
        _executionStorage.allowGlobalValidation = allowGlobalValidation;
    }

    function _removeExecutionFunction(bytes4 selector) internal {
        ExecutionStorage storage _executionStorage = getAccountStorage().executionStorage[selector];

        _executionStorage.module = address(0);
        _executionStorage.skipRuntimeValidation = false;
        _executionStorage.allowGlobalValidation = false;
    }

    function _removeValidationFunction(ModuleEntity validationFunction) internal {
        ValidationStorage storage _validationStorage = getAccountStorage().validationStorage[validationFunction];
        _validationStorage.validationFlags = ValidationFlags.wrap(0);
    }

    function _addExecHooks(EnumerableSet.Bytes32Set storage hooks, HookConfig hookConfig) internal {
        if (!hooks.add(toSetValue(hookConfig))) {
            revert ExecutionHookAlreadySet(hookConfig);
        }
    }

    function _removeExecHooks(EnumerableSet.Bytes32Set storage hooks, HookConfig hookConfig) internal {
        hooks.remove(toSetValue(hookConfig));
    }

    function _installExecution(
        address module,
        ExecutionManifest calldata manifest,
        bytes calldata moduleInstallData
    ) internal {
        AccountStorage storage _storage = getAccountStorage();

        if (module == address(0)) {
            revert NullModule();
        }

        // Update components according to the manifest.
        uint256 length = manifest.executionFunctions.length;
        for (uint256 i = 0; i < length; ++i) {
            bytes4 selector = manifest.executionFunctions[i].executionSelector;
            bool skipRuntimeValidation = manifest.executionFunctions[i].skipRuntimeValidation;
            bool allowGlobalValidation = manifest.executionFunctions[i].allowGlobalValidation;
            _setExecutionFunction(selector, skipRuntimeValidation, allowGlobalValidation, module);
        }

        length = manifest.executionHooks.length;
        for (uint256 i = 0; i < length; ++i) {
            ManifestExecutionHook memory mh = manifest.executionHooks[i];
            EnumerableSet.Bytes32Set storage execHooks =
                _storage.executionStorage[mh.executionSelector].executionHooks;
            HookConfig hookConfig = HookConfigLib.packExecHook({
                _module: module,
                _entityId: mh.entityId,
                _hasPre: mh.isPreHook,
                _hasPost: mh.isPostHook
            });
            _addExecHooks(execHooks, hookConfig);
        }

        length = manifest.interfaceIds.length;
        for (uint256 i = 0; i < length; ++i) {
            _storage.supportedIfaces[manifest.interfaceIds[i]] += 1;
        }

        _onInstall(module, moduleInstallData, type(IModule).interfaceId);

        emit ExecutionInstalled(module, manifest);
    }

    function _uninstallExecution(address module, ExecutionManifest calldata manifest, bytes calldata uninstallData)
        internal
    {
        AccountStorage storage _storage = getAccountStorage();

        // Remove components according to the manifest, in reverse order (by component type) of their installation.

        uint256 length = manifest.executionHooks.length;
        for (uint256 i = 0; i < length; ++i) {
            ManifestExecutionHook memory mh = manifest.executionHooks[i];
            EnumerableSet.Bytes32Set storage execHooks =
                _storage.executionStorage[mh.executionSelector].executionHooks;
            HookConfig hookConfig = HookConfigLib.packExecHook({
                _module: module,
                _entityId: mh.entityId,
                _hasPre: mh.isPreHook,
                _hasPost: mh.isPostHook
            });
            _removeExecHooks(execHooks, hookConfig);
        }

        length = manifest.executionFunctions.length;
        for (uint256 i = 0; i < length; ++i) {
            bytes4 selector = manifest.executionFunctions[i].executionSelector;
            _removeExecutionFunction(selector);
        }

        length = manifest.interfaceIds.length;
        for (uint256 i = 0; i < length; ++i) {
            _storage.supportedIfaces[manifest.interfaceIds[i]] -= 1;
        }

        // Clear the module storage for the account.
        bool onUninstallSuccess = _onUninstall(module, uninstallData);

        emit ExecutionUninstalled(module, onUninstallSuccess, manifest);
    }

    function _onInstall(address module, bytes calldata data, bytes4 interfaceId) internal {
        if (data.length > 0) {
            if (!ERC165Checker.supportsInterface(module, interfaceId)) {
                revert InterfaceNotSupported(module);
            }
            // solhint-disable-next-line no-empty-blocks
            try IModule(module).onInstall(data) {}
            catch {
                bytes memory revertReason = collectReturnData();
                revert ModuleInstallCallbackFailed(module, revertReason);
            }
        }
    }

    function _onUninstall(address module, bytes calldata data) internal returns (bool onUninstallSuccess) {
        onUninstallSuccess = true;
        if (data.length > 0) {
            // Clear the module storage for the account.
            // solhint-disable-next-line no-empty-blocks
            try IModule(module).onUninstall(data) {}
            catch {
                onUninstallSuccess = false;
            }
        }
    }

    function _installValidation(
        ValidationConfig validationConfig,
        bytes4[] calldata selectors,
        bytes calldata installData,
        bytes[] calldata hooks
    ) internal {
        ValidationStorage storage _validationStorage =
            getAccountStorage().validationStorage[validationConfig.moduleEntity()];
        (ModuleEntity moduleEntity, ValidationFlags validationFlags) = validationConfig.unpack();

        for (uint256 i = 0; i < hooks.length; ++i) {
            HookConfig hookConfig = HookConfig.wrap(bytes25(hooks[i][:25]));
            bytes calldata hookData = hooks[i][25:];

            if (hookConfig.isValidationHook()) {
                _validationStorage.validationHooks.push(hookConfig);

                // Avoid collision between reserved index and actual indices
                if (_validationStorage.validationHooks.length > MAX_VALIDATION_ASSOC_HOOKS) {
                    revert PreValidationHookLimitExceeded();
                }

                _onInstall(hookConfig.module(), hookData, type(IValidationHookModule).interfaceId);

                continue;
            }
            // Hook is an execution hook
            _addExecHooks(_validationStorage.executionHooks, hookConfig);

            _onInstall(hookConfig.module(), hookData, type(IExecutionHookModule).interfaceId);
        }

        for (uint256 i = 0; i < selectors.length; ++i) {
            bytes4 selector = selectors[i];
            if (!_validationStorage.selectors.add(toSetValue(selector))) {
                revert ValidationAlreadySet(selector, moduleEntity);
            }
        }

        _validationStorage.validationFlags = validationFlags;

        _onInstall(validationConfig.module(), installData, type(IValidationModule).interfaceId);
        emit ValidationInstalled(validationConfig.module(), validationConfig.entityId());
    }

    function _uninstallValidation(
        ModuleEntity validationFunction,
        bytes calldata uninstallData,
        bytes[] calldata hookUninstallDatas
    ) internal {
        ValidationStorage storage _validationStorage = getAccountStorage().validationStorage[validationFunction];
        bool onUninstallSuccess = true;

        _removeValidationFunction(validationFunction);

        // Send `onUninstall` to hooks
        if (hookUninstallDatas.length > 0) {
            // If any uninstall data is provided, assert it is of the correct length.
            if (
                hookUninstallDatas.length
                    != _validationStorage.validationHooks.length + _validationStorage.executionHooks.length()
            ) {
                revert ArrayLengthMismatch();
            }

            // Hook uninstall data is provided in the order of pre validation hooks, then execution hooks.
            uint256 hookIndex = 0;
            for (uint256 i = 0; i < _validationStorage.validationHooks.length; ++i) {
                bytes calldata hookData = hookUninstallDatas[hookIndex];
                (address hookModule,) =
                    ModuleEntityLib.unpack(_validationStorage.validationHooks[i].moduleEntity());
                onUninstallSuccess = onUninstallSuccess && _onUninstall(hookModule, hookData);
                hookIndex++;
            }

            for (uint256 i = 0; i < _validationStorage.executionHooks.length(); ++i) {
                bytes calldata hookData = hookUninstallDatas[hookIndex];
                (address hookModule,) =
                    ModuleEntityLib.unpack(toModuleEntity(_validationStorage.executionHooks.at(i)));
                onUninstallSuccess = onUninstallSuccess && _onUninstall(hookModule, hookData);
                hookIndex++;
            }
        }

        // Clear all stored hooks
        delete _validationStorage.validationHooks;

        EnumerableSet.Bytes32Set storage executionHooks = _validationStorage.executionHooks;
        uint256 executionHookLen = executionHooks.length();
        for (uint256 i = 0; i < executionHookLen; ++i) {
            bytes32 executionHook = executionHooks.at(0);
            executionHooks.remove(executionHook);
        }

        // Clear selectors
        uint256 selectorLen = _validationStorage.selectors.length();
        for (uint256 i = 0; i < selectorLen; ++i) {
            bytes32 selectorSetValue = _validationStorage.selectors.at(0);
            _validationStorage.selectors.remove(selectorSetValue);
        }

        (address module, uint32 entityId) = ModuleEntityLib.unpack(validationFunction);
        onUninstallSuccess = onUninstallSuccess && _onUninstall(module, uninstallData);

        emit ValidationUninstalled(module, entityId, onUninstallSuccess);
    }
}
