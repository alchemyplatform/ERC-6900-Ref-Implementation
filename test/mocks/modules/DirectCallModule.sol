// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";

import {IERC6900Account} from "../../../src/interfaces/IERC6900Account.sol";
import {IERC6900ExecutionHookModule} from "../../../src/interfaces/IERC6900ExecutionHookModule.sol";
import {BaseModule} from "../../../src/modules/BaseModule.sol";

contract DirectCallModule is BaseModule, IERC6900ExecutionHookModule {
    bool public preHookRan = false;
    bool public postHookRan = false;

    function onInstall(bytes calldata) external override {}

    function onUninstall(bytes calldata) external override {}

    function directCall() external returns (bytes memory) {
        return IERC6900Account(msg.sender).execute(address(this), 0, abi.encodeCall(this.getData, ()));
    }

    function getData() external pure returns (bytes memory) {
        return hex"04546b";
    }

    function moduleId() external pure returns (string memory) {
        return "erc6900.direct-call-module.1.0.0";
    }

    function preExecutionHook(uint32, address sender, uint256, bytes calldata)
        external
        override
        returns (bytes memory)
    {
        require(sender == address(this), "mock direct call pre execution hook failed");
        preHookRan = true;
        return abi.encode(keccak256(hex"04546b"));
    }

    function postExecutionHook(uint32, bytes calldata preExecHookData) external override {
        require(
            abi.decode(preExecHookData, (bytes32)) == keccak256(hex"04546b"),
            "mock direct call post execution hook failed"
        );
        postHookRan = true;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(BaseModule, IERC165)
        returns (bool)
    {
        return interfaceId == type(IERC6900ExecutionHookModule).interfaceId || super.supportsInterface(interfaceId);
    }
}
