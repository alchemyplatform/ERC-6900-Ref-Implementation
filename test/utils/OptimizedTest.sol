// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {IEntryPoint} from "@eth-infinitism/account-abstraction/interfaces/IEntryPoint.sol";

import {ReferenceModularAccount} from "../../src/account/ReferenceModularAccount.sol";
import {SemiModularAccount} from "../../src/account/SemiModularAccount.sol";

import {TokenReceiverModule} from "../../src/modules/TokenReceiverModule.sol";
import {SingleSignerValidationModule} from "../../src/modules/validation/SingleSignerValidationModule.sol";

/// @dev This contract provides functions to deploy optimized (via IR) precompiled contracts. By compiling just
/// the source contracts (excluding the test suite) via IR, and using the resulting bytecode within the tests
/// (built without IR), we can avoid the significant overhead of compiling the entire test suite via IR.
///
/// To use the optimized precompiled contracts, the project must first be built with the "optimized-build" profile
/// to populate the artifacts in the `out-optimized` directory. Then use the "optimized-test" or
/// "optimized-test-deep" profile to run the tests.
///
/// To bypass this behavior for coverage or debugging, use the "default" profile.
abstract contract OptimizedTest is Test {
    function _isOptimizedTest() internal returns (bool) {
        string memory profile = vm.envOr("FOUNDRY_PROFILE", string("default"));
        return _isStringEq(profile, "optimized-test-deep") || _isStringEq(profile, "optimized-test");
    }

    function _isStringEq(string memory a, string memory b) internal pure returns (bool) {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }

    function _deployReferenceModularAccount(IEntryPoint entryPoint) internal returns (ReferenceModularAccount) {
        return _isOptimizedTest()
            ? ReferenceModularAccount(
                payable(
                    deployCode(
                        "out-optimized/ReferenceModularAccount.sol/ReferenceModularAccount.json",
                        abi.encode(entryPoint)
                    )
                )
            )
            : new ReferenceModularAccount(entryPoint);
    }

    function _deploySemiModularAccount(IEntryPoint entryPoint) internal returns (ReferenceModularAccount) {
        return _isOptimizedTest()
            ? ReferenceModularAccount(
                payable(
                    deployCode("out-optimized/SemiModularAccount.sol/SemiModularAccount.json", abi.encode(entryPoint))
                )
            )
            : ReferenceModularAccount(new SemiModularAccount(entryPoint));
    }

    function _deployTokenReceiverModule() internal returns (TokenReceiverModule) {
        return _isOptimizedTest()
            ? TokenReceiverModule(deployCode("out-optimized/TokenReceiverModule.sol/TokenReceiverModule.json"))
            : new TokenReceiverModule();
    }

    function _deploySingleSignerValidationModule() internal returns (SingleSignerValidationModule) {
        return _isOptimizedTest()
            ? SingleSignerValidationModule(
                deployCode("out-optimized/SingleSignerValidationModule.sol/SingleSignerValidationModule.json")
            )
            : new SingleSignerValidationModule();
    }
}
