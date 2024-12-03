// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import {ExecutionManifest} from "./IExecutionModule.sol";

type ModuleEntity is bytes24;
// ModuleEntity is a packed representation of a module function
// Layout:
// 0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA________________________ // Address
// 0x________________________________________BBBBBBBB________________ // Entity ID
// 0x________________________________________________0000000000000000 // unused

type ValidationConfig is bytes25;
// ValidationConfig is a packed representation of a validation function and flags for its configuration.
// Layout:
// 0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA________________________ // Address
// 0x________________________________________BBBBBBBB________________ // Entity ID
// 0x________________________________________________CC______________ // ValidationFlags
// 0x__________________________________________________00000000000000 // unused

type ValidationFlags is uint8;
// ValidationFlags layout:
// 0b00000___ // unused
// 0b_____A__ // isGlobal
// 0b______B_ // isSignatureValidation
// 0b_______C // isUserOpValidation

type HookConfig is bytes25;
// HookConfig is a packed representation of a hook function and flags for its configuration.
// Layout:
// 0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA________________________ // Address
// 0x________________________________________BBBBBBBB________________ // Entity ID
// 0x________________________________________________CC______________ // Hook Flags
//
// Hook flags layout:
// 0b00000___ // unused
// 0b_____A__ // hasPre (exec only)
// 0b______B_ // hasPost (exec only)
// 0b_______C // hook type (0 for exec, 1 for validation)

struct Call {
    // The target address for the account to call.
    address target;
    // The value to send with the call.
    uint256 value;
    // The calldata for the call.
    bytes data;
}

interface IModularAccount {
    event ExecutionInstalled(address indexed module, ExecutionManifest manifest);
    event ExecutionUninstalled(address indexed module, bool onUninstallSucceeded, ExecutionManifest manifest);
    event ValidationInstalled(address indexed module, uint32 indexed entityId);
    event ValidationUninstalled(address indexed module, uint32 indexed entityId, bool onUninstallSucceeded);

    /// @notice Standard execute method.
    /// @param target The target address for the account to call.
    /// @param value The value to send with the call.
    /// @param data The calldata for the call.
    /// @return The return data from the call.
    function execute(address target, uint256 value, bytes calldata data) external payable returns (bytes memory);

    /// @notice Standard executeBatch method.
    /// @dev If the target is a module, the call SHOULD revert. If any of the calls revert, the entire batch MUST
    /// revert.
    /// @param calls The array of calls.
    /// @return An array containing the return data from the calls.
    function executeBatch(Call[] calldata calls) external payable returns (bytes[] memory);

    /// @notice Execute a call using the specified runtime validation.
    /// @param data The calldata to send to the account.
    /// @param authorization The authorization data to use for the call. The first 24 bytes is a ModuleEntity which
    /// specifies which runtime validation to use, and the rest is sent as a parameter to runtime validation.
    function executeWithRuntimeValidation(bytes calldata data, bytes calldata authorization)
        external
        payable
        returns (bytes memory);

    /// @notice Install a module to the modular account.
    /// @param module The module to install.
    /// @param manifest the manifest describing functions to install.
    /// @param installData Optional data to be used by the account to handle the initial execution setup. Data
    /// encoding
    /// is implementation-specific.
    function installExecution(address module, ExecutionManifest calldata manifest, bytes calldata installData)
        external;

    /// @notice Uninstall a module from the modular account.
    /// @param module The module to uninstall.
    /// @param manifest the manifest describing functions to uninstall.
    /// @param uninstallData Optional data to be used by the account to handle the execution uninstallation. Data
    /// encoding is implementation-specific.
    function uninstallExecution(address module, ExecutionManifest calldata manifest, bytes calldata uninstallData)
        external;

    /// @notice Installs a validation function across a set of execution selectors, and optionally mark it as a
    /// global validation function.
    /// @param validationConfig The validation function to install, along with configuration flags.
    /// @param selectors The selectors to install the validation function for.
    /// @param installData Optional data to be used by the account to handle the initial validation setup. Data
    /// encoding is implementation-specific.
    /// @param hooks Optional hooks to install and associate with the validation function. Data encoding is
    /// implementation-specific.
    function installValidation(
        ValidationConfig validationConfig,
        bytes4[] calldata selectors,
        bytes calldata installData,
        bytes[] calldata hooks
    ) external;

    /// @notice Uninstall a validation function from a set of execution selectors.
    /// @param validationFunction The validation function to uninstall.
    /// @param uninstallData Optional data to be used by the account to handle the validation uninstallation. Data
    /// encoding is implementation-specific.
    /// @param hookUninstallData Optional data to be used by the account to handle hook uninstallation. Data
    /// encoding
    /// is implementation-specific.
    function uninstallValidation(
        ModuleEntity validationFunction,
        bytes calldata uninstallData,
        bytes[] calldata hookUninstallData
    ) external;

    /// @notice Return a unique identifier for the account implementation.
    /// @dev This function MUST return a string in the format "vendor.account.semver". The vendor and account
    /// names MUST NOT contain a period character.
    /// @return The account ID.
    function accountId() external view returns (string memory);
}
