// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";

interface IERC6900Module is IERC165 {
    /// @notice Initialize module data for the modular account.
    /// @dev Called by the modular account during `installExecution`.
    /// @param data Optional bytes array to be decoded and used by the module to setup initial module data for the
    /// modular account.
    function onInstall(bytes calldata data) external;

    /// @notice Clear module data for the modular account.
    /// @dev Called by the modular account during `uninstallExecution`.
    /// @param data Optional bytes array to be decoded and used by the module to clear module data for the modular
    /// account.
    function onUninstall(bytes calldata data) external;

    /// @notice Return a unique identifier for the module.
    /// @dev This function MUST return a string in the format "vendor.module.semver". The vendor and module
    /// names MUST NOT contain a period character.
    /// @return The module ID.
    function moduleId() external view returns (string memory);
}
