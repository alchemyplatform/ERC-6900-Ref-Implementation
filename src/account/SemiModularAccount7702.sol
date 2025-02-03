// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import {IModularAccount} from "../interfaces/IModularAccount.sol";
import {SemiModularAccount} from "./SemiModularAccount.sol";
import {IEntryPoint} from "@eth-infinitism/account-abstraction/interfaces/IEntryPoint.sol";

contract SemiModularAccount7702 is SemiModularAccount {
    error UpgradeNotAllowed();

    constructor(IEntryPoint anEntryPoint) SemiModularAccount(anEntryPoint) {}

    /// @inheritdoc IModularAccount
    function accountId() external pure virtual override returns (string memory) {
        return "erc6900.reference-semi-modular-account-7702.0.8.0";
    }

    /// @dev To prevent accidental self-calls, upgrades are disabled in 7702 accounts.
    function upgradeToAndCall(address, bytes memory) public payable override {
        revert UpgradeNotAllowed();
    }

    /// @dev If the fallback signer is set in storage, ignore the 7702 signer.
    function _retrieveFallbackSignerUnchecked(SemiModularAccountStorage storage _storage)
        internal
        view
        override
        returns (address)
    {
        address storageFallbackSigner = _storage.fallbackSigner;
        if (storageFallbackSigner != address(0)) {
            return storageFallbackSigner;
        }

        // To support 7702, we default to address(this) as the fallback signer.
        return address(this);
    }
}
