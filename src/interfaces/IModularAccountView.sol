// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import {HookConfig, ModuleEntity, ValidationFlags} from "../interfaces/IModularAccount.sol";

/// @dev Represents data associated with a specific function selector.
struct ExecutionDataView {
    // The module that implements this execution function.
    // If this is a native function, the address must remain address(0).
    address module;
    // Whether or not the function needs runtime validation, or can be called by anyone. The function can still be
    // state changing if this flag is set to true.
    // Note that even if this is set to true, user op validation will still be required, otherwise anyone could
    // drain the account of native tokens by wasting gas.
    bool skipRuntimeValidation;
    // Whether or not a global validation function may be used to validate this function.
    bool allowGlobalValidation;
    // The execution hooks for this function selector.
    HookConfig[] executionHooks;
}

struct ValidationDataView {
    // ValidationFlags layout:
    // 0b00000___ // unused
    // 0b_____A__ // isGlobal
    // 0b______B_ // isSignatureValidation
    // 0b_______C // isUserOpValidation
    ValidationFlags validationFlags;
    // The validation hooks for this validation function.
    HookConfig[] validationHooks;
    // Execution hooks to run with this validation function.
    HookConfig[] executionHooks;
    // The set of selectors that may be validated by this validation function.
    bytes4[] selectors;
}

interface IModularAccountView {
    /// @notice Get the execution data for a selector.
    /// @dev If the selector is a native function, the module address will be the address of the account.
    /// @param selector The selector to get the data for.
    /// @return The execution data for this selector.
    function getExecutionData(bytes4 selector) external view returns (ExecutionDataView memory);

    /// @notice Get the validation data for a validation function.
    /// @dev If the selector is a native function, the module address will be the address of the account.
    /// @param validationFunction The validation function to get the data for.
    /// @return The validation data for this validation function.
    function getValidationData(ModuleEntity validationFunction)
        external
        view
        returns (ValidationDataView memory);
}
