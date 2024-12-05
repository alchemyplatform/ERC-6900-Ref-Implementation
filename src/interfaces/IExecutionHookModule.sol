// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import {IModule} from "./IModule.sol";

interface IExecutionHookModule is IModule {
    /// @notice Run the pre execution hook specified by the `entityId`.
    /// @dev To indicate the entire call should revert, the function MUST revert.
    /// @param entityId An identifier that routes the call to different internal implementations, should there
    /// be more than one.
    /// @param sender The caller address.
    /// @param value The call value.
    /// @param data The calldata sent. For `executeUserOp` calls of validation-associated hooks, hook modules
    /// should receive the full calldata.
    /// @return Context to pass to a post execution hook, if present. An empty bytes array MAY be returned.
    function preExecutionHook(uint32 entityId, address sender, uint256 value, bytes calldata data)
        external
        returns (bytes memory);

    /// @notice Run the post execution hook specified by the `entityId`.
    /// @dev To indicate the entire call should revert, the function MUST revert.
    /// @param entityId An identifier that routes the call to different internal implementations, should there
    /// be more than one.
    /// @param preExecHookData The context returned by its associated pre execution hook.
    function postExecutionHook(uint32 entityId, bytes calldata preExecHookData) external;
}
