// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.25;

import {ERC165Checker} from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {FunctionReferenceLib} from "../helpers/FunctionReferenceLib.sol";
import {
    IPlugin,
    ManifestExecutionHook,
    ManifestPermissionHook,
    ManifestFunction,
    ManifestAssociatedFunctionType,
    ManifestAssociatedFunction,
    PluginManifest
} from "../interfaces/IPlugin.sol";
import {ExecutionHook} from "../interfaces/IAccountLoupe.sol";
import {FunctionReference, IPluginManager} from "../interfaces/IPluginManager.sol";
import {AccountStorage, getAccountStorage, SelectorData, toSetValue} from "./AccountStorage.sol";

abstract contract PluginManagerInternals is IPluginManager {
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using EnumerableSet for EnumerableSet.AddressSet;
    using FunctionReferenceLib for FunctionReference;

    error ArrayLengthMismatch();
    error ExecutionFunctionAlreadySet(bytes4 selector);
    error InvalidDependenciesProvided();
    error InvalidPluginManifest();
    error MissingPluginDependency(address dependency);
    error NullFunctionReference();
    error NullPlugin();
    error PluginAlreadyInstalled(address plugin);
    error PluginDependencyViolation(address plugin);
    error PluginInstallCallbackFailed(address plugin, bytes revertReason);
    error PluginInterfaceNotSupported(address plugin);
    error PluginNotInstalled(address plugin);
    error ValidationFunctionAlreadySet(bytes4 selector, FunctionReference validationFunction);

    modifier notNullFunction(FunctionReference functionReference) {
        if (functionReference.isEmpty()) {
            revert NullFunctionReference();
        }
        _;
    }

    modifier notNullPlugin(address plugin) {
        if (plugin == address(0)) {
            revert NullPlugin();
        }
        _;
    }

    // Storage update operations

    function _setExecutionFunction(bytes4 selector, bool isPublic, bool allowSharedValidation, address plugin)
        internal
        notNullPlugin(plugin)
    {
        SelectorData storage _selectorData = getAccountStorage().selectorData[selector];

        if (_selectorData.plugin != address(0)) {
            revert ExecutionFunctionAlreadySet(selector);
        }

        _selectorData.plugin = plugin;
        _selectorData.isPublic = isPublic;
        _selectorData.allowSharedValidation = allowSharedValidation;
    }

    function _removeExecutionFunction(bytes4 selector) internal {
        SelectorData storage _selectorData = getAccountStorage().selectorData[selector];

        _selectorData.plugin = address(0);
        _selectorData.isPublic = false;
        _selectorData.allowSharedValidation = false;
    }

    function _addValidationFunction(bytes4 selector, FunctionReference validationFunction)
        internal
        notNullFunction(validationFunction)
    {
        SelectorData storage _selectorData = getAccountStorage().selectorData[selector];

        // Fail on duplicate selector definitions - otherwise dependencies could shadow non-depdency
        // validation functions, leading to partial uninstalls.
        if (!_selectorData.validations.add(toSetValue(validationFunction))) {
            revert ValidationFunctionAlreadySet(selector, validationFunction);
        }
    }

    function _removeValidationFunction(bytes4 selector, FunctionReference validationFunction)
        internal
        notNullFunction(validationFunction)
    {
        SelectorData storage _selectorData = getAccountStorage().selectorData[selector];

        // May ignore return value, as the manifest hash is validated to ensure that the validation function
        // exists.
        _selectorData.validations.remove(toSetValue(validationFunction));
    }

    function _addExecHooks(
        EnumerableSet.Bytes32Set storage hooks,
        FunctionReference hookFunction,
        bool isPreExecHook,
        bool isPostExecHook,
        bool requireUOContext
    ) internal {
        hooks.add(
            toSetValue(
                ExecutionHook({
                    hookFunction: hookFunction,
                    isPreHook: isPreExecHook,
                    isPostHook: isPostExecHook,
                    requireUOContext: requireUOContext
                })
            )
        );
    }

    function _removeExecHooks(
        EnumerableSet.Bytes32Set storage hooks,
        FunctionReference hookFunction,
        bool isPreExecHook,
        bool isPostExecHook,
        bool requireUOContext
    ) internal {
        hooks.remove(
            toSetValue(
                ExecutionHook({
                    hookFunction: hookFunction,
                    isPreHook: isPreExecHook,
                    isPostHook: isPostExecHook,
                    requireUOContext: requireUOContext
                })
            )
        );
    }

    function _installPlugin(
        address plugin,
        bytes32 manifestHash,
        bytes memory pluginInstallData,
        FunctionReference[] memory dependencies
    ) internal {
        AccountStorage storage _storage = getAccountStorage();

        // Check if the plugin exists.
        if (!_storage.plugins.add(plugin)) {
            revert PluginAlreadyInstalled(plugin);
        }

        // Check that the plugin supports the IPlugin interface.
        if (!ERC165Checker.supportsInterface(plugin, type(IPlugin).interfaceId)) {
            revert PluginInterfaceNotSupported(plugin);
        }

        // Check manifest hash.
        PluginManifest memory manifest = IPlugin(plugin).pluginManifest();
        if (!_isValidPluginManifest(manifest, manifestHash)) {
            revert InvalidPluginManifest();
        }

        // Check that the dependencies match the manifest.
        if (dependencies.length != manifest.dependencyInterfaceIds.length) {
            revert InvalidDependenciesProvided();
        }

        uint256 length = dependencies.length;
        for (uint256 i = 0; i < length; ++i) {
            // Check the dependency interface id over the address of the dependency.
            (address dependencyAddr,) = dependencies[i].unpack();

            // Check that the dependency is installed.
            if (_storage.pluginData[dependencyAddr].manifestHash == bytes32(0)) {
                revert MissingPluginDependency(dependencyAddr);
            }

            // Check that the dependency supports the expected interface.
            if (!ERC165Checker.supportsInterface(dependencyAddr, manifest.dependencyInterfaceIds[i])) {
                revert InvalidDependenciesProvided();
            }

            // Increment the dependency's dependents counter.
            _storage.pluginData[dependencyAddr].dependentCount += 1;
        }

        // Add the plugin metadata to the account
        _storage.pluginData[plugin].manifestHash = manifestHash;
        _storage.pluginData[plugin].dependencies = dependencies;

        // Update components according to the manifest.

        length = manifest.executionFunctions.length;
        for (uint256 i = 0; i < length; ++i) {
            bytes4 selector = manifest.executionFunctions[i].executionSelector;
            bool isPublic = manifest.executionFunctions[i].isPublic;
            bool allowSharedValidation = manifest.executionFunctions[i].allowSharedValidation;
            _setExecutionFunction(selector, isPublic, allowSharedValidation, plugin);
        }

        length = manifest.validationFunctions.length;
        for (uint256 i = 0; i < length; ++i) {
            ManifestAssociatedFunction memory mv = manifest.validationFunctions[i];
            _addValidationFunction(
                mv.executionSelector, _resolveManifestFunction(mv.associatedFunction, plugin, dependencies)
            );
        }

        length = manifest.signatureValidationFunctions.length;
        for (uint256 i = 0; i < length; ++i) {
            FunctionReference signatureValidationFunction =
                FunctionReferenceLib.pack(plugin, manifest.signatureValidationFunctions[i]);
            _storage.validationData[signatureValidationFunction].isSignatureValidation = true;
        }

        length = manifest.executionHooks.length;
        for (uint256 i = 0; i < length; ++i) {
            ManifestExecutionHook memory mh = manifest.executionHooks[i];
            EnumerableSet.Bytes32Set storage execHooks = _storage.selectorData[mh.executionSelector].executionHooks;
            FunctionReference hookFunction = FunctionReferenceLib.pack(plugin, mh.functionId);
            _addExecHooks(execHooks, hookFunction, mh.isPreHook, mh.isPostHook, mh.requireUOContext);
        }

        length = manifest.permissionHooks.length;
        for (uint256 i = 0; i < length; ++i) {
            ManifestPermissionHook memory mh = manifest.permissionHooks[i];
            EnumerableSet.Bytes32Set storage permissionHooks =
                _storage.validationData[mh.validationFunction].permissionHooks;
            FunctionReference hookFunction = FunctionReferenceLib.pack(plugin, mh.functionId);
            _addExecHooks(permissionHooks, hookFunction, mh.isPreHook, mh.isPostHook, mh.requireUOContext);
            if (mh.requireUOContext) {
                _storage.validationData[mh.validationFunction].requireUOHookCount += 1;
            }
        }

        length = manifest.interfaceIds.length;
        for (uint256 i = 0; i < length; ++i) {
            _storage.supportedIfaces[manifest.interfaceIds[i]] += 1;
        }

        // Initialize the plugin storage for the account.
        // solhint-disable-next-line no-empty-blocks
        try IPlugin(plugin).onInstall(pluginInstallData) {}
        catch (bytes memory revertReason) {
            revert PluginInstallCallbackFailed(plugin, revertReason);
        }

        emit PluginInstalled(plugin, manifestHash, dependencies);
    }

    function _uninstallPlugin(address plugin, PluginManifest memory manifest, bytes memory uninstallData)
        internal
    {
        AccountStorage storage _storage = getAccountStorage();

        // Check if the plugin exists.
        if (!_storage.plugins.remove(plugin)) {
            revert PluginNotInstalled(plugin);
        }

        // Check manifest hash.
        bytes32 manifestHash = _storage.pluginData[plugin].manifestHash;
        if (!_isValidPluginManifest(manifest, manifestHash)) {
            revert InvalidPluginManifest();
        }

        // Ensure that there are no dependent plugins.
        if (_storage.pluginData[plugin].dependentCount != 0) {
            revert PluginDependencyViolation(plugin);
        }

        // Remove this plugin as a dependent from its dependencies.
        FunctionReference[] memory dependencies = _storage.pluginData[plugin].dependencies;
        uint256 length = dependencies.length;
        for (uint256 i = 0; i < length; ++i) {
            FunctionReference dependency = dependencies[i];
            (address dependencyAddr,) = dependency.unpack();

            // Decrement the dependent count for the dependency function.
            _storage.pluginData[dependencyAddr].dependentCount -= 1;
        }

        // Remove components according to the manifest, in reverse order (by component type) of their installation.
        length = manifest.executionHooks.length;
        for (uint256 i = 0; i < length; ++i) {
            ManifestExecutionHook memory mh = manifest.executionHooks[i];
            FunctionReference hookFunction = FunctionReferenceLib.pack(plugin, mh.functionId);
            EnumerableSet.Bytes32Set storage execHooks = _storage.selectorData[mh.executionSelector].executionHooks;
            _removeExecHooks(execHooks, hookFunction, mh.isPreHook, mh.isPostHook, mh.requireUOContext);
        }

        length = manifest.permissionHooks.length;
        for (uint256 i = 0; i < length; ++i) {
            ManifestPermissionHook memory mh = manifest.permissionHooks[i];
            FunctionReference hookFunction = FunctionReferenceLib.pack(plugin, mh.functionId);
            EnumerableSet.Bytes32Set storage permissionHooks =
                _storage.validationData[mh.validationFunction].permissionHooks;
            _removeExecHooks(permissionHooks, hookFunction, mh.isPreHook, mh.isPostHook, mh.requireUOContext);
            if (mh.requireUOContext) {
                _storage.validationData[mh.validationFunction].requireUOHookCount -= 1;
            }
        }

        length = manifest.signatureValidationFunctions.length;
        for (uint256 i = 0; i < length; ++i) {
            FunctionReference signatureValidationFunction =
                FunctionReferenceLib.pack(plugin, manifest.signatureValidationFunctions[i]);
            _storage.validationData[signatureValidationFunction].isSignatureValidation = false;
        }

        length = manifest.validationFunctions.length;
        for (uint256 i = 0; i < length; ++i) {
            ManifestAssociatedFunction memory mv = manifest.validationFunctions[i];
            _removeValidationFunction(
                mv.executionSelector, _resolveManifestFunction(mv.associatedFunction, plugin, dependencies)
            );
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

        // Remove the plugin metadata from the account.
        delete _storage.pluginData[plugin];

        // Clear the plugin storage for the account.
        bool onUninstallSuccess = true;
        // solhint-disable-next-line no-empty-blocks
        try IPlugin(plugin).onUninstall(uninstallData) {}
        catch {
            onUninstallSuccess = false;
        }

        emit PluginUninstalled(plugin, onUninstallSuccess);
    }

    function _isValidPluginManifest(PluginManifest memory manifest, bytes32 manifestHash)
        internal
        pure
        returns (bool)
    {
        return manifestHash == keccak256(abi.encode(manifest));
    }

    function _resolveManifestFunction(
        ManifestFunction memory manifestFunction,
        address plugin,
        FunctionReference[] memory dependencies
    ) internal pure returns (FunctionReference) {
        if (manifestFunction.functionType == ManifestAssociatedFunctionType.SELF) {
            return FunctionReferenceLib.pack(plugin, manifestFunction.functionId);
        } else if (manifestFunction.functionType == ManifestAssociatedFunctionType.DEPENDENCY) {
            if (manifestFunction.dependencyIndex >= dependencies.length) {
                revert InvalidPluginManifest();
            }
            return dependencies[manifestFunction.dependencyIndex];
        }
        return FunctionReferenceLib._EMPTY_FUNCTION_REFERENCE; // Empty checks are done elsewhere
    }
}
