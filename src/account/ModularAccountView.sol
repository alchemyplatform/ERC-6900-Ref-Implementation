// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {HookConfig, IERC6900Account, ModuleEntity} from "../interfaces/IERC6900Account.sol";
import {ExecutionDataView, IERC6900AccountView, ValidationDataView} from "../interfaces/IERC6900AccountView.sol";
import {HookConfigLib} from "../libraries/HookConfigLib.sol";
import {ExecutionStorage, ValidationStorage, getAccountStorage, toHookConfig} from "./AccountStorage.sol";

abstract contract ModularAccountView is IERC6900AccountView {
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    using HookConfigLib for HookConfig;

    /// @inheritdoc IERC6900AccountView
    function getExecutionData(bytes4 selector) external view override returns (ExecutionDataView memory data) {
        if (
            selector == IERC6900Account.execute.selector || selector == IERC6900Account.executeBatch.selector
                || selector == UUPSUpgradeable.upgradeToAndCall.selector
                || selector == IERC6900Account.installExecution.selector
                || selector == IERC6900Account.uninstallExecution.selector
        ) {
            data.module = address(this);
            data.allowGlobalValidation = true;
        } else {
            ExecutionStorage storage executionStorage = getAccountStorage().executionStorage[selector];
            data.module = executionStorage.module;
            data.skipRuntimeValidation = executionStorage.skipRuntimeValidation;
            data.allowGlobalValidation = executionStorage.allowGlobalValidation;

            uint256 executionHooksLen = executionStorage.executionHooks.length();
            data.executionHooks = new HookConfig[](executionHooksLen);
            for (uint256 i = 0; i < executionHooksLen; ++i) {
                data.executionHooks[i] = toHookConfig(executionStorage.executionHooks.at(i));
            }
        }
    }

    /// @inheritdoc IERC6900AccountView
    function getValidationData(ModuleEntity validationFunction)
        external
        view
        override
        returns (ValidationDataView memory data)
    {
        ValidationStorage storage validationStorage = getAccountStorage().validationStorage[validationFunction];
        data.validationFlags = validationStorage.validationFlags;
        data.validationHooks = validationStorage.validationHooks;

        uint256 execHooksLen = validationStorage.executionHooks.length();
        data.executionHooks = new HookConfig[](execHooksLen);
        for (uint256 i = 0; i < execHooksLen; ++i) {
            data.executionHooks[i] = toHookConfig(validationStorage.executionHooks.at(i));
        }

        bytes32[] memory selectors = validationStorage.selectors.values();
        uint256 selectorsLen = selectors.length;
        data.selectors = new bytes4[](selectorsLen);
        for (uint256 j = 0; j < selectorsLen; ++j) {
            data.selectors[j] = bytes4(selectors[j]);
        }
    }
}
