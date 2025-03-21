// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import {IERC6900ValidationModule} from "../../interfaces/IERC6900ValidationModule.sol";

interface ISingleSignerValidationModule is IERC6900ValidationModule {
    /// @notice This event is emitted when Signer of the account's validation changes.
    /// @param account The account whose validation Signer changed.
    /// @param entityId The entityId for the account and the signer.
    /// @param newSigner The address of the new signer.
    /// @param previousSigner The address of the previous signer.
    event SignerTransferred(
        address indexed account, uint32 indexed entityId, address indexed newSigner, address previousSigner
    ) anonymous;

    error NotAuthorized();

    /// @notice Transfer Signer of the account's validation to `newSigner`.
    /// @param entityId The entityId for the account and the signer.
    /// @param newSigner The address of the new signer.
    function transferSigner(uint32 entityId, address newSigner) external;
}
