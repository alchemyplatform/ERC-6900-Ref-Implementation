// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

import {FunctionReference, FunctionReferenceLib} from "../../src/helpers/FunctionReferenceLib.sol";
import {ExecutionHook} from "../../src/interfaces/IAccountLoupe.sol";
import {IPluginManager} from "../../src/interfaces/IPluginManager.sol";
import {IStandardExecutor} from "../../src/interfaces/IStandardExecutor.sol";

import {ComprehensivePlugin} from "../mocks/plugins/ComprehensivePlugin.sol";
import {AccountTestBase} from "../utils/AccountTestBase.sol";

contract AccountLoupeTest is AccountTestBase {
    ComprehensivePlugin public comprehensivePlugin;

    event ReceivedCall(bytes msgData, uint256 msgValue);

    function setUp() public {
        _transferOwnershipToTest();

        comprehensivePlugin = new ComprehensivePlugin();

        bytes32 manifestHash = keccak256(abi.encode(comprehensivePlugin.pluginManifest()));
        vm.prank(address(entryPoint));
        account1.installPlugin(address(comprehensivePlugin), manifestHash, "", new FunctionReference[](0));

        FunctionReference[] memory preValidationHooks = new FunctionReference[](2);
        preValidationHooks[0] = FunctionReferenceLib.pack(
            address(comprehensivePlugin), uint8(ComprehensivePlugin.FunctionId.PRE_VALIDATION_HOOK_1)
        );
        preValidationHooks[1] = FunctionReferenceLib.pack(
            address(comprehensivePlugin), uint8(ComprehensivePlugin.FunctionId.PRE_VALIDATION_HOOK_2)
        );

        bytes[] memory installDatas = new bytes[](2);
        vm.prank(address(entryPoint));
        account1.installValidation(
            _ownerValidation, true, new bytes4[](0), bytes(""), abi.encode(preValidationHooks, installDatas)
        );
    }

    function test_pluginLoupe_getInstalledPlugins_initial() public {
        address[] memory plugins = account1.getInstalledPlugins();

        assertEq(plugins.length, 2);

        assertEq(plugins[0], address(singleOwnerPlugin));
        assertEq(plugins[1], address(comprehensivePlugin));
    }

    function test_pluginLoupe_getExecutionFunctionHandler_native() public {
        bytes4[] memory selectorsToCheck = new bytes4[](5);

        selectorsToCheck[0] = IStandardExecutor.execute.selector;

        selectorsToCheck[1] = IStandardExecutor.executeBatch.selector;

        selectorsToCheck[2] = UUPSUpgradeable.upgradeToAndCall.selector;

        selectorsToCheck[3] = IPluginManager.installPlugin.selector;

        selectorsToCheck[4] = IPluginManager.uninstallPlugin.selector;

        for (uint256 i = 0; i < selectorsToCheck.length; i++) {
            address plugin = account1.getExecutionFunctionHandler(selectorsToCheck[i]);

            assertEq(plugin, address(account1));
        }
    }

    function test_pluginLoupe_getExecutionFunctionConfig_plugin() public {
        bytes4[] memory selectorsToCheck = new bytes4[](1);
        address[] memory expectedPluginAddress = new address[](1);

        selectorsToCheck[0] = comprehensivePlugin.foo.selector;
        expectedPluginAddress[0] = address(comprehensivePlugin);

        for (uint256 i = 0; i < selectorsToCheck.length; i++) {
            address plugin = account1.getExecutionFunctionHandler(selectorsToCheck[i]);

            assertEq(plugin, expectedPluginAddress[i]);
        }
    }

    function test_pluginLoupe_getSelectors() public {
        FunctionReference comprehensivePluginValidation = FunctionReferenceLib.pack(
            address(comprehensivePlugin), uint8(ComprehensivePlugin.FunctionId.VALIDATION)
        );

        bytes4[] memory selectors = account1.getSelectors(comprehensivePluginValidation);

        assertEq(selectors.length, 1);
        assertEq(selectors[0], comprehensivePlugin.foo.selector);
    }

    function test_pluginLoupe_getExecutionHooks() public {
        ExecutionHook[] memory hooks = account1.getExecutionHooks(comprehensivePlugin.foo.selector);
        ExecutionHook[3] memory expectedHooks = [
            ExecutionHook({
                hookFunction: FunctionReferenceLib.pack(
                    address(comprehensivePlugin), uint8(ComprehensivePlugin.FunctionId.BOTH_EXECUTION_HOOKS)
                ),
                isPreHook: true,
                isPostHook: true
            }),
            ExecutionHook({
                hookFunction: FunctionReferenceLib.pack(
                    address(comprehensivePlugin), uint8(ComprehensivePlugin.FunctionId.PRE_EXECUTION_HOOK)
                ),
                isPreHook: true,
                isPostHook: false
            }),
            ExecutionHook({
                hookFunction: FunctionReferenceLib.pack(
                    address(comprehensivePlugin), uint8(ComprehensivePlugin.FunctionId.POST_EXECUTION_HOOK)
                ),
                isPreHook: false,
                isPostHook: true
            })
        ];

        assertEq(hooks.length, 3);
        for (uint256 i = 0; i < hooks.length; i++) {
            assertEq(
                FunctionReference.unwrap(hooks[i].hookFunction),
                FunctionReference.unwrap(expectedHooks[i].hookFunction)
            );
            assertEq(hooks[i].isPreHook, expectedHooks[i].isPreHook);
            assertEq(hooks[i].isPostHook, expectedHooks[i].isPostHook);
        }
    }

    function test_pluginLoupe_getValidationHooks() public {
        FunctionReference[] memory hooks = account1.getPreValidationHooks(_ownerValidation);

        assertEq(hooks.length, 2);
        assertEq(
            FunctionReference.unwrap(hooks[0]),
            FunctionReference.unwrap(
                FunctionReferenceLib.pack(
                    address(comprehensivePlugin), uint8(ComprehensivePlugin.FunctionId.PRE_VALIDATION_HOOK_1)
                )
            )
        );
        assertEq(
            FunctionReference.unwrap(hooks[1]),
            FunctionReference.unwrap(
                FunctionReferenceLib.pack(
                    address(comprehensivePlugin), uint8(ComprehensivePlugin.FunctionId.PRE_VALIDATION_HOOK_2)
                )
            )
        );
    }
}
