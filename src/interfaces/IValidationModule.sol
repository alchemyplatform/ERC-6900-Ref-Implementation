// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import {PackedUserOperation} from "@eth-infinitism/account-abstraction/interfaces/PackedUserOperation.sol";

import {IModule} from "./IModule.sol";

interface IValidationModule is IModule {
    /// @notice Run the user operation validation function specified by the `entityId`.
    /// @param entityId An identifier that routes the call to different internal implementations, should there
    /// be more than one.
    /// @param userOp The user operation.
    /// @param userOpHash The user operation hash.
    /// @return Packed validation data for validAfter (6 bytes), validUntil (6 bytes), and authorizer (20 bytes).
    function validateUserOp(uint32 entityId, PackedUserOperation calldata userOp, bytes32 userOpHash)
        external
        returns (uint256);

    /// @notice Run the runtime validation function specified by the `entityId`.
    /// @dev To indicate the entire call should revert, the function MUST revert.
    /// @param account The account to validate for.
    /// @param entityId An identifier that routes the call to different internal implementations, should there
    /// be more than one.
    /// @param sender The caller address.
    /// @param value The call value.
    /// @param data The calldata sent.
    /// @param authorization Additional data for the validation function to use.
    function validateRuntime(
        address account,
        uint32 entityId,
        address sender,
        uint256 value,
        bytes calldata data,
        bytes calldata authorization
    ) external;

    /// @notice Validates a signature using ERC-1271.
    /// @dev To indicate the entire call should revert, the function MUST revert.
    /// @param account The account to validate for.
    /// @param entityId An identifier that routes the call to different internal implementations, should there
    /// be more than one.
    /// @param sender The address that sent the ERC-1271 request to the smart account.
    /// @param hash The hash of the ERC-1271 request.
    /// @param signature The signature of the ERC-1271 request.
    /// @return The ERC-1271 `MAGIC_VALUE` if the signature is valid, or 0xFFFFFFFF if invalid.
    function validateSignature(
        address account,
        uint32 entityId,
        address sender,
        bytes32 hash,
        bytes calldata signature
    ) external view returns (bytes4);
}
