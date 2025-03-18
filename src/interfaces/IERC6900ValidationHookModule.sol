// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import {PackedUserOperation} from "@eth-infinitism/account-abstraction/interfaces/PackedUserOperation.sol";

import {IERC6900Module} from "./IERC6900Module.sol";

interface IERC6900ValidationHookModule is IERC6900Module {
    /// @notice Run the pre user operation validation hook specified by the `entityId`.
    /// @dev Pre user operation validation hooks MUST NOT return an authorizer value other than 0 or 1.
    /// @param entityId An identifier that routes the call to different internal implementations, should there
    /// be more than one.
    /// @param userOp The user operation.
    /// @param userOpHash The user operation hash.
    /// @return Packed validation data for validAfter (6 bytes), validUntil (6 bytes), and authorizer (20 bytes).
    function preUserOpValidationHook(uint32 entityId, PackedUserOperation calldata userOp, bytes32 userOpHash)
        external
        returns (uint256);

    /// @notice Run the pre runtime validation hook specified by the `entityId`.
    /// @dev To indicate the entire call should revert, the function MUST revert.
    /// @param entityId An identifier that routes the call to different internal implementations, should there
    /// be more than one.
    /// @param sender The caller address.
    /// @param value The call value.
    /// @param data The calldata sent.
    /// @param authorization Additional data for the hook to use.
    function preRuntimeValidationHook(
        uint32 entityId,
        address sender,
        uint256 value,
        bytes calldata data,
        bytes calldata authorization
    ) external;

    /// @notice Run the pre signature validation hook specified by the `entityId`.
    /// @dev To indicate the call should revert, the function MUST revert.
    /// @param entityId An identifier that routes the call to different internal implementations, should there
    /// be more than one.
    /// @param sender The caller address.
    /// @param hash The hash of the message being signed.
    /// @param signature The signature of the message.
    function preSignatureValidationHook(uint32 entityId, address sender, bytes32 hash, bytes calldata signature)
        external
        view;
}
