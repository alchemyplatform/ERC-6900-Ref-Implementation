// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import {IAccount} from "@eth-infinitism/account-abstraction/interfaces/IAccount.sol";
import {IPaymaster} from "@eth-infinitism/account-abstraction/interfaces/IPaymaster.sol";
import {Test} from "forge-std/Test.sol";

import {IERC6900Module} from "../../src/interfaces/IERC6900Module.sol";
import {KnownSelectorsLib} from "../../src/libraries/KnownSelectorsLib.sol";

contract KnownSelectorsLibTest is Test {
    function test_isNativeFunction() public {
        assertTrue(KnownSelectorsLib.isNativeFunction(IAccount.validateUserOp.selector));
    }

    function test_isErc4337Function() public {
        assertTrue(KnownSelectorsLib.isErc4337Function(IPaymaster.validatePaymasterUserOp.selector));
    }

    function test_isIModuleFunction() public {
        assertTrue(KnownSelectorsLib.isIModuleFunction(IERC6900Module.moduleId.selector));
    }
}
