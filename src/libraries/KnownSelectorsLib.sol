// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import {IAccount} from "@eth-infinitism/account-abstraction/interfaces/IAccount.sol";
import {IAggregator} from "@eth-infinitism/account-abstraction/interfaces/IAggregator.sol";
import {IPaymaster} from "@eth-infinitism/account-abstraction/interfaces/IPaymaster.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {IERC6900Account} from "../interfaces/IERC6900Account.sol";

import {IERC6900AccountView} from "../interfaces/IERC6900AccountView.sol";

import {IERC6900ExecutionHookModule} from "../interfaces/IERC6900ExecutionHookModule.sol";

import {IERC6900ExecutionModule} from "../interfaces/IERC6900ExecutionModule.sol";
import {IERC6900Module} from "../interfaces/IERC6900Module.sol";
import {IERC6900ValidationHookModule} from "../interfaces/IERC6900ValidationHookModule.sol";
import {IERC6900ValidationModule} from "../interfaces/IERC6900ValidationModule.sol";

/// @dev Library to help to check if a selector is a know function selector of the modular account or ERC-4337
/// contract.
library KnownSelectorsLib {
    function isNativeFunction(bytes4 selector) internal pure returns (bool) {
        return
        // check against IAccount methods
        selector == IAccount.validateUserOp.selector
        // check against IERC6900Account methods
        || selector == IERC6900Account.installExecution.selector
            || selector == IERC6900Account.uninstallExecution.selector
            || selector == IERC6900Account.installValidation.selector
            || selector == IERC6900Account.uninstallValidation.selector || selector == IERC6900Account.execute.selector
            || selector == IERC6900Account.executeBatch.selector
            || selector == IERC6900Account.executeWithRuntimeValidation.selector
            || selector == IERC6900Account.accountId.selector
        // check against IERC165 methods
        || selector == IERC165.supportsInterface.selector
        // check against UUPSUpgradeable methods
        || selector == UUPSUpgradeable.proxiableUUID.selector
            || selector == UUPSUpgradeable.upgradeToAndCall.selector
        // check against IERC6900AccountView methods
        || selector == IERC6900AccountView.getExecutionData.selector
            || selector == IERC6900AccountView.getValidationData.selector;
    }

    function isErc4337Function(bytes4 selector) internal pure returns (bool) {
        return selector == IAggregator.validateSignatures.selector
            || selector == IAggregator.validateUserOpSignature.selector
            || selector == IAggregator.aggregateSignatures.selector
            || selector == IPaymaster.validatePaymasterUserOp.selector || selector == IPaymaster.postOp.selector;
    }

    function isIModuleFunction(bytes4 selector) internal pure returns (bool) {
        return selector == IERC6900Module.onInstall.selector || selector == IERC6900Module.onUninstall.selector
            || selector == IERC6900Module.moduleId.selector
            || selector == IERC6900ExecutionModule.executionManifest.selector
            || selector == IERC6900ExecutionHookModule.preExecutionHook.selector
            || selector == IERC6900ExecutionHookModule.postExecutionHook.selector
            || selector == IERC6900ValidationModule.validateUserOp.selector
            || selector == IERC6900ValidationModule.validateRuntime.selector
            || selector == IERC6900ValidationModule.validateSignature.selector
            || selector == IERC6900ValidationHookModule.preUserOpValidationHook.selector
            || selector == IERC6900ValidationHookModule.preRuntimeValidationHook.selector;
    }
}
