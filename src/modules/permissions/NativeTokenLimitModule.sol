// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import {UserOperationLib} from "@eth-infinitism/account-abstraction/core/UserOperationLib.sol";
import {PackedUserOperation} from "@eth-infinitism/account-abstraction/interfaces/PackedUserOperation.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {Call, IERC6900Account} from "../../interfaces/IERC6900Account.sol";

import {IERC6900ExecutionHookModule} from "../../interfaces/IERC6900ExecutionHookModule.sol";
import {IERC6900Module} from "../../interfaces/IERC6900Module.sol";
import {IERC6900ValidationHookModule} from "../../interfaces/IERC6900ValidationHookModule.sol";
import {BaseModule, IERC165} from "../BaseModule.sol";

/// @title Native Token Limit Module
/// @author ERC-6900 Authors
/// @notice This module supports a single total native token spend limit.
/// It tracks a total spend limit across UserOperation gas limits and native token transfers.
/// If a non whitelisted paymaster is used, UO gas would not cause the limit to decrease.
/// If a whitelisted paymaster is used, gas is still counted towards the limit
contract NativeTokenLimitModule is BaseModule, IERC6900ExecutionHookModule, IERC6900ValidationHookModule {
    using UserOperationLib for PackedUserOperation;
    using EnumerableSet for EnumerableSet.Bytes32Set;

    mapping(uint256 funcIds => mapping(address account => uint256 limit)) public limits;
    // Accounts should add paymasters that still use the accounts tokens here
    // E.g. ERC20 paymasters that pull funds from the account
    mapping(address paymaster => mapping(address account => bool allowed)) public specialPaymasters;

    error ExceededNativeTokenLimit();
    error ExceededNumberOfEntities();

    function updateLimits(uint32 entityId, uint256 newLimit) external {
        limits[entityId][msg.sender] = newLimit;
    }

    function updateSpecialPaymaster(address paymaster, bool allowed) external {
        specialPaymasters[paymaster][msg.sender] = allowed;
    }

    /// @inheritdoc IERC6900ValidationHookModule
    function preUserOpValidationHook(uint32 entityId, PackedUserOperation calldata userOp, bytes32)
        external
        returns (uint256)
    {
        // Decrease limit only if no paymaster is used, or if its a special paymaster
        if (
            userOp.paymasterAndData.length == 0
                || specialPaymasters[address(bytes20(userOp.paymasterAndData[:20]))][msg.sender]
        ) {
            uint256 vgl = UserOperationLib.unpackVerificationGasLimit(userOp);
            uint256 cgl = UserOperationLib.unpackCallGasLimit(userOp);
            uint256 pvgl;
            uint256 ppogl;
            if (userOp.paymasterAndData.length > 0) {
                // Can skip the EP length check here since it would have reverted there if it was invalid
                (, pvgl, ppogl) = UserOperationLib.unpackPaymasterStaticFields(userOp.paymasterAndData);
            }
            uint256 totalGas = userOp.preVerificationGas + vgl + cgl + pvgl + ppogl;
            uint256 usage = totalGas * UserOperationLib.unpackMaxFeePerGas(userOp);

            uint256 limit = limits[entityId][msg.sender];
            if (usage > limit) {
                revert ExceededNativeTokenLimit();
            }
            limits[entityId][msg.sender] = limit - usage;
        }
        return 0;
    }

    /// @inheritdoc IERC6900ExecutionHookModule
    function preExecutionHook(uint32 entityId, address, uint256, bytes calldata data)
        external
        override
        returns (bytes memory)
    {
        return _checkAndDecrementLimit(entityId, data);
    }

    /// @inheritdoc IERC6900Module
    function onInstall(bytes calldata data) external override {
        (uint32 startEntityId, uint256[] memory spendLimits) = abi.decode(data, (uint32, uint256[]));

        if (startEntityId + spendLimits.length > type(uint32).max) {
            revert ExceededNumberOfEntities();
        }

        for (uint256 i = 0; i < spendLimits.length; i++) {
            limits[i + startEntityId][msg.sender] = spendLimits[i];
        }
    }

    /// @inheritdoc IERC6900Module
    function onUninstall(bytes calldata data) external override {
        // This is the highest entityId that's being used by the account
        uint32 entityId = abi.decode(data, (uint32));
        for (uint256 i = 0; i < entityId; i++) {
            delete limits[i][msg.sender];
        }
    }

    /// @inheritdoc IERC6900ExecutionHookModule
    function postExecutionHook(uint32, bytes calldata) external pure override {
        revert NotImplemented();
    }

    // No implementation, no revert
    // Runtime spends no account gas, and we check native token spend limits in exec hooks
    function preRuntimeValidationHook(uint32, address, uint256, bytes calldata, bytes calldata)
        external
        pure
        override
    {} // solhint-disable-line no-empty-blocks

    // solhint-disable-next-line no-empty-blocks
    function preSignatureValidationHook(uint32, address, bytes32, bytes calldata) external pure override {}

    /// @inheritdoc IERC6900Module
    function moduleId() external pure returns (string memory) {
        return "erc6900.native-token-limit-module.1.0.0";
    }

    // ┏━━━━━━━━━━━━━━━┓
    // ┃    EIP-165    ┃
    // ┗━━━━━━━━━━━━━━━┛

    /// @inheritdoc BaseModule
    function supportsInterface(bytes4 interfaceId) public view override(BaseModule, IERC165) returns (bool) {
        return interfaceId == type(IERC6900ExecutionHookModule).interfaceId || super.supportsInterface(interfaceId);
    }

    function _checkAndDecrementLimit(uint32 entityId, bytes calldata data) internal returns (bytes memory) {
        (bytes4 selector, bytes memory callData) = _getSelectorAndCalldata(data);

        uint256 value;
        // Get value being sent
        if (selector == IERC6900Account.execute.selector) {
            (, value) = abi.decode(callData, (address, uint256));
        } else if (selector == IERC6900Account.executeBatch.selector) {
            Call[] memory calls = abi.decode(callData, (Call[]));
            for (uint256 i = 0; i < calls.length; i++) {
                value += calls[i].value;
            }
        }

        uint256 limit = limits[entityId][msg.sender];
        if (value > limit) {
            revert ExceededNativeTokenLimit();
        }
        limits[entityId][msg.sender] = limit - value;

        return "";
    }
}
