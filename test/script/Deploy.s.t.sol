// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {IEntryPoint} from "@eth-infinitism/account-abstraction/interfaces/IEntryPoint.sol";
import {IStakeManager} from "@eth-infinitism/account-abstraction/interfaces/IStakeManager.sol";
import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";

import {DeployScript} from "../../script/Deploy.s.sol";

import {AccountFactory} from "../../src/account/AccountFactory.sol";

import {ReferenceModularAccount} from "../../src/account/ReferenceModularAccount.sol";
import {SemiModularAccount} from "../../src/account/SemiModularAccount.sol";
import {SingleSignerValidationModule} from "../../src/modules/validation/SingleSignerValidationModule.sol";

import {EntryPointUtils} from "../utils/EntryPointUtils.sol";

contract DeployTest is Test, EntryPointUtils {
    DeployScript internal _deployScript;

    IEntryPoint internal _entryPoint;

    address internal _owner;

    address internal _accountImpl;
    address internal _smaImpl;
    address internal _singleSignerValidationModule;
    address internal _factory;

    function setUp() public {
        _entryPoint = _deployEntryPoint();

        // Set the owner to the foundry default sender, as this is what will be used as the sender within the
        // `startBroadcast` segment of the script.
        _owner = DEFAULT_SENDER;

        vm.setEnv("ENTRYPOINT", vm.toString(address(_entryPoint)));
        vm.setEnv("OWNER", vm.toString(_owner));

        _accountImpl = Create2.computeAddress(
            bytes32(0),
            keccak256(
                abi.encodePacked(type(ReferenceModularAccount).creationCode, abi.encode(address(_entryPoint)))
            ),
            CREATE2_FACTORY
        );

        _smaImpl = Create2.computeAddress(
            bytes32(0),
            keccak256(abi.encodePacked(type(SemiModularAccount).creationCode, abi.encode(address(_entryPoint)))),
            CREATE2_FACTORY
        );

        _singleSignerValidationModule = Create2.computeAddress(
            bytes32(0),
            keccak256(abi.encodePacked(type(SingleSignerValidationModule).creationCode)),
            CREATE2_FACTORY
        );

        _factory = Create2.computeAddress(
            bytes32(0),
            keccak256(
                abi.encodePacked(
                    type(AccountFactory).creationCode,
                    abi.encode(address(_entryPoint), _accountImpl, _smaImpl, _singleSignerValidationModule, _owner)
                )
            ),
            CREATE2_FACTORY
        );

        vm.setEnv("ACCOUNT_IMPL", vm.toString(address(_accountImpl)));
        vm.setEnv("SMA_IMPL", vm.toString(address(_smaImpl)));
        vm.setEnv("FACTORY", vm.toString(address(_factory)));
        vm.setEnv("SINGLE_SIGNER_VALIDATION_MODULE", vm.toString(_singleSignerValidationModule));

        vm.setEnv("ACCOUNT_IMPL_SALT", vm.toString(uint256(0)));
        vm.setEnv("SMA_IMPL_SALT", vm.toString(uint256(0)));
        vm.setEnv("FACTORY_SALT", vm.toString(uint256(0)));
        vm.setEnv("SINGLE_SIGNER_VALIDATION_MODULE_SALT", vm.toString(uint256(0)));

        _deployScript = new DeployScript();

        vm.deal(address(_deployScript), 0.1 ether);
    }

    function test_deployScript_run() public {
        _deployScript.run();

        assertTrue(_accountImpl.code.length > 0);
        assertTrue(_smaImpl.code.length > 0);
        assertTrue(_factory.code.length > 0);
        assertTrue(_singleSignerValidationModule.code.length > 0);

        assertEq(
            _singleSignerValidationModule.code,
            type(SingleSignerValidationModule).runtimeCode,
            "SingleSignerValidationModule runtime code mismatch"
        );

        // Check factory stake
        IStakeManager.DepositInfo memory depositInfo = _entryPoint.getDepositInfo(_factory);

        assertTrue(depositInfo.staked, "Factory not staked");
        assertEq(depositInfo.stake, 0.1 ether, "Unexpected factory stake amount");
        assertEq(depositInfo.unstakeDelaySec, 1 days, "Unexpected factory unstake delay");
    }

    function test_deployScript_addStake() public {
        test_deployScript_run();

        vm.setEnv("STAKE_AMOUNT", vm.toString(uint256(0.3 ether)));

        // Refresh script's env vars

        _deployScript = new DeployScript();

        _deployScript.run();

        IStakeManager.DepositInfo memory depositInfo = _entryPoint.getDepositInfo(_factory);

        assertEq(depositInfo.stake, 0.3 ether, "Unexpected factory stake amount");
    }
}
