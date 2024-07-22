// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import {IEntryPoint, UpgradeableModularAccount} from "../../src/account/UpgradeableModularAccount.sol";
import {PluginEntity, PluginEntityLib} from "../../src/helpers/PluginEntityLib.sol";
import {ValidationConfig, ValidationConfigLib} from "../../src/helpers/ValidationConfigLib.sol";
import {ExecutionHook} from "../../src/interfaces/IAccountLoupe.sol";
import {Call, IStandardExecutor} from "../../src/interfaces/IStandardExecutor.sol";
import {DirectCallPlugin} from "../mocks/plugins/DirectCallPlugin.sol";

import {AccountTestBase} from "../utils/AccountTestBase.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {LibClone} from "solady/utils/LibClone.sol";

contract ImmutableAppendTest is AccountTestBase {
    using ValidationConfigLib for ValidationConfig;

    /* -------------------------------------------------------------------------- */
    /*                                  Negatives                                 */
    /* -------------------------------------------------------------------------- */

    /* -------------------------------------------------------------------------- */
    /*                                  Positives                                 */
    /* -------------------------------------------------------------------------- */

    function test_success_getData() public {
        bytes memory expectedArgs = abi.encodePacked(
            PluginEntityLib.pack(address(singleSignerValidation), TEST_DEFAULT_VALIDATION_ENTITY_ID),
            singleSignerValidation.signerOf(TEST_DEFAULT_VALIDATION_ENTITY_ID, address(account1))
        );

        assertEq(keccak256(LibClone.argsOnERC1967(address(account1))), keccak256(expectedArgs));
    }

    /* -------------------------------------------------------------------------- */
    /*                                  Internals                                 */
    /* -------------------------------------------------------------------------- */
}
