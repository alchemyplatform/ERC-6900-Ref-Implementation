// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import {console} from "forge-std/Test.sol";

import {IEntryPoint} from "@eth-infinitism/account-abstraction/interfaces/IEntryPoint.sol";
import {PackedUserOperation} from "@eth-infinitism/account-abstraction/interfaces/PackedUserOperation.sol";
import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import {ModuleManagerInternals} from "../../src/account/ModuleManagerInternals.sol";
import {ReferenceModularAccount} from "../../src/account/ReferenceModularAccount.sol";
import {SemiModularAccount} from "../../src/account/SemiModularAccount.sol";
import {ExecutionManifest} from "../../src/interfaces/IExecutionModule.sol";
import {Call} from "../../src/interfaces/IModularAccount.sol";
import {ExecutionDataView} from "../../src/interfaces/IModularAccountView.sol";
import {ModuleEntityLib} from "../../src/libraries/ModuleEntityLib.sol";
import {ValidationConfigLib} from "../../src/libraries/ValidationConfigLib.sol";
import {TokenReceiverModule} from "../../src/modules/TokenReceiverModule.sol";
import {SingleSignerValidationModule} from "../../src/modules/validation/SingleSignerValidationModule.sol";

import {Counter} from "../mocks/Counter.sol";
import {MockModule} from "../mocks/MockModule.sol";
import {ComprehensiveModule} from "../mocks/modules/ComprehensiveModule.sol";
import {AccountTestBase} from "../utils/AccountTestBase.sol";
import {TEST_DEFAULT_VALIDATION_ENTITY_ID} from "../utils/TestConstants.sol";

contract ReferenceModularAccountTest is AccountTestBase {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    TokenReceiverModule public tokenReceiverModule;

    // A separate account and owner that isn't deployed yet, used to test initcode
    address public owner2;
    uint256 public owner2Key;
    ReferenceModularAccount public account2;

    address public ethRecipient;
    Counter public counter;
    ExecutionManifest internal _manifest;

    event ExecutionInstalled(address indexed module, ExecutionManifest manifest);
    event ExecutionUninstalled(address indexed module, bool onUninstallSucceeded, ExecutionManifest manifest);
    event ReceivedCall(bytes msgData, uint256 msgValue);

    function setUp() public {
        tokenReceiverModule = _deployTokenReceiverModule();

        (owner2, owner2Key) = makeAddrAndKey("owner2");

        // Compute counterfactual address
        account2 = ReferenceModularAccount(payable(factory.getAddress(owner2, 0)));
        vm.deal(address(account2), 100 ether);

        ethRecipient = makeAddr("ethRecipient");
        vm.deal(ethRecipient, 1 wei);
        counter = new Counter();
        counter.increment(); // amoritze away gas cost of zero->nonzero transition
    }

    function test_deployAccount() public {
        factory.createAccount(owner2, 0);
    }

    function test_postDeploy_ethSend() public {
        PackedUserOperation memory userOp = PackedUserOperation({
            sender: address(account1),
            nonce: 0,
            initCode: "",
            callData: abi.encodeCall(ReferenceModularAccount.execute, (ethRecipient, 1 wei, "")),
            accountGasLimits: _encodeGas(VERIFICATION_GAS_LIMIT, CALL_GAS_LIMIT),
            preVerificationGas: 0,
            gasFees: _encodeGas(1, 1),
            paymasterAndData: "",
            signature: ""
        });

        // Generate signature
        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(owner1Key, userOpHash.toEthSignedMessageHash());
        userOp.signature = _encodeSignature(_signerValidation, GLOBAL_VALIDATION, abi.encodePacked(r, s, v));

        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;

        entryPoint.handleOps(userOps, beneficiary);

        assertEq(ethRecipient.balance, 2 wei);
    }

    function test_basicUserOp_withInitCode() public {
        bytes memory callData = vm.envOr("SMA_TEST", false)
            ? abi.encodeCall(SemiModularAccount(payable(account1)).updateFallbackSigner, (owner2))
            : abi.encodeCall(
                ReferenceModularAccount.execute,
                (
                    address(singleSignerValidationModule),
                    0,
                    abi.encodeCall(
                        SingleSignerValidationModule.transferSigner, (TEST_DEFAULT_VALIDATION_ENTITY_ID, owner2)
                    )
                )
            );

        PackedUserOperation memory userOp = PackedUserOperation({
            sender: address(account2),
            nonce: 0,
            initCode: abi.encodePacked(address(factory), abi.encodeCall(factory.createAccount, (owner2, 0))),
            callData: callData,
            accountGasLimits: _encodeGas(VERIFICATION_GAS_LIMIT, CALL_GAS_LIMIT),
            preVerificationGas: 0,
            gasFees: _encodeGas(1, 2),
            paymasterAndData: "",
            signature: ""
        });

        // Generate signature
        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(owner2Key, userOpHash.toEthSignedMessageHash());
        userOp.signature = _encodeSignature(_signerValidation, GLOBAL_VALIDATION, abi.encodePacked(r, s, v));

        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;

        entryPoint.handleOps(userOps, beneficiary);
    }

    function test_standardExecuteEthSend_withInitcode() public {
        address payable recipient = payable(makeAddr("recipient"));

        PackedUserOperation memory userOp = PackedUserOperation({
            sender: address(account2),
            nonce: 0,
            initCode: abi.encodePacked(address(factory), abi.encodeCall(factory.createAccount, (owner2, 0))),
            callData: abi.encodeCall(ReferenceModularAccount.execute, (recipient, 1 wei, "")),
            accountGasLimits: _encodeGas(VERIFICATION_GAS_LIMIT, CALL_GAS_LIMIT),
            preVerificationGas: 0,
            gasFees: _encodeGas(1, 1),
            paymasterAndData: "",
            signature: ""
        });

        // Generate signature
        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(owner2Key, userOpHash.toEthSignedMessageHash());
        userOp.signature = _encodeSignature(_signerValidation, GLOBAL_VALIDATION, abi.encodePacked(r, s, v));

        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;

        entryPoint.handleOps(userOps, beneficiary);

        assertEq(recipient.balance, 1 wei);
    }

    function test_debug_ReferenceModularAccount_storageAccesses() public {
        PackedUserOperation memory userOp = PackedUserOperation({
            sender: address(account1),
            nonce: 0,
            initCode: "",
            callData: abi.encodeCall(ReferenceModularAccount.execute, (ethRecipient, 1 wei, "")),
            accountGasLimits: _encodeGas(VERIFICATION_GAS_LIMIT, CALL_GAS_LIMIT),
            preVerificationGas: 0,
            gasFees: _encodeGas(1, 1),
            paymasterAndData: "",
            signature: ""
        });

        // Generate signature
        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(owner1Key, userOpHash.toEthSignedMessageHash());
        userOp.signature = _encodeSignature(_signerValidation, GLOBAL_VALIDATION, abi.encodePacked(r, s, v));

        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;

        vm.record();
        entryPoint.handleOps(userOps, beneficiary);
        _printStorageReadsAndWrites(address(account2));
    }

    function test_accountId() public {
        string memory accountId = account1.accountId();
        assertEq(
            accountId,
            vm.envOr("SMA_TEST", false)
                ? "erc6900.reference-semi-modular-account.0.8.0"
                : "erc6900.reference-modular-account.0.8.0"
        );
    }

    function test_contractInteraction() public {
        PackedUserOperation memory userOp = PackedUserOperation({
            sender: address(account1),
            nonce: 0,
            initCode: "",
            callData: abi.encodeCall(
                ReferenceModularAccount.execute, (address(counter), 0, abi.encodeCall(counter.increment, ()))
            ),
            accountGasLimits: _encodeGas(VERIFICATION_GAS_LIMIT, CALL_GAS_LIMIT),
            preVerificationGas: 0,
            gasFees: _encodeGas(1, 1),
            paymasterAndData: "",
            signature: ""
        });

        // Generate signature
        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(owner1Key, userOpHash.toEthSignedMessageHash());
        userOp.signature = _encodeSignature(_signerValidation, GLOBAL_VALIDATION, abi.encodePacked(r, s, v));

        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;

        entryPoint.handleOps(userOps, beneficiary);

        assertEq(counter.number(), 2);
    }

    function test_batchExecute() public {
        // Performs both an eth send and a contract interaction with counter
        Call[] memory calls = new Call[](2);
        calls[0] = Call({target: ethRecipient, value: 1 wei, data: ""});
        calls[1] = Call({target: address(counter), value: 0, data: abi.encodeCall(counter.increment, ())});

        PackedUserOperation memory userOp = PackedUserOperation({
            sender: address(account1),
            nonce: 0,
            initCode: "",
            callData: abi.encodeCall(ReferenceModularAccount.executeBatch, (calls)),
            accountGasLimits: _encodeGas(VERIFICATION_GAS_LIMIT, CALL_GAS_LIMIT),
            preVerificationGas: 0,
            gasFees: _encodeGas(1, 1),
            paymasterAndData: "",
            signature: ""
        });

        // Generate signature
        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(owner1Key, userOpHash.toEthSignedMessageHash());
        userOp.signature = _encodeSignature(_signerValidation, GLOBAL_VALIDATION, abi.encodePacked(r, s, v));

        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;

        entryPoint.handleOps(userOps, beneficiary);

        assertEq(counter.number(), 2);
        assertEq(ethRecipient.balance, 2 wei);
    }

    function test_installExecution() public {
        vm.startPrank(address(entryPoint));

        vm.expectEmit(true, true, true, true);
        emit ExecutionInstalled(address(tokenReceiverModule), tokenReceiverModule.executionManifest());
        account1.installExecution({
            module: address(tokenReceiverModule),
            manifest: tokenReceiverModule.executionManifest(),
            moduleInstallData: abi.encode(uint48(1 days))
        });

        ExecutionDataView memory data = account1.getExecutionData(TokenReceiverModule.onERC721Received.selector);
        assertEq(data.module, address(tokenReceiverModule));
    }

    function test_installExecution_PermittedCallSelectorNotInstalled() public {
        vm.startPrank(address(entryPoint));

        ExecutionManifest memory m;

        MockModule mockModuleWithBadPermittedExec = new MockModule(m);

        account1.installExecution({
            module: address(mockModuleWithBadPermittedExec),
            manifest: mockModuleWithBadPermittedExec.executionManifest(),
            moduleInstallData: ""
        });
    }

    function test_installExecution_alreadyInstalled() public {
        ExecutionManifest memory m = tokenReceiverModule.executionManifest();

        vm.prank(address(entryPoint));
        account1.installExecution({
            module: address(tokenReceiverModule),
            manifest: m,
            moduleInstallData: abi.encode(uint48(1 days))
        });

        vm.prank(address(entryPoint));
        vm.expectRevert(
            abi.encodeWithSelector(
                ModuleManagerInternals.ExecutionFunctionAlreadySet.selector,
                TokenReceiverModule.onERC721Received.selector
            )
        );
        account1.installExecution({
            module: address(tokenReceiverModule),
            manifest: m,
            moduleInstallData: abi.encode(uint48(1 days))
        });
    }

    function test_uninstallExecution_default() public {
        vm.startPrank(address(entryPoint));

        ComprehensiveModule module = new ComprehensiveModule();
        account1.installExecution({
            module: address(module),
            manifest: module.executionManifest(),
            moduleInstallData: ""
        });

        vm.expectEmit(true, true, true, true);
        emit ExecutionUninstalled(address(module), true, module.executionManifest());
        account1.uninstallExecution({
            module: address(module),
            manifest: module.executionManifest(),
            moduleUninstallData: ""
        });

        ExecutionDataView memory data = account1.getExecutionData(module.foo.selector);
        assertEq(data.module, address(0));
    }

    function _installExecutionWithExecHooks() internal returns (MockModule module) {
        vm.startPrank(address(entryPoint));

        module = new MockModule(_manifest);

        account1.installExecution({
            module: address(module),
            manifest: module.executionManifest(),
            moduleInstallData: ""
        });

        vm.stopPrank();
    }

    function test_upgradeToAndCall() public {
        vm.startPrank(address(entryPoint));
        ReferenceModularAccount account3 = new ReferenceModularAccount(entryPoint);
        bytes32 slot = account3.proxiableUUID();

        // account has impl from factory
        assertEq(
            address(factory.accountImplementation()), address(uint160(uint256(vm.load(address(account1), slot))))
        );
        account1.upgradeToAndCall(address(account3), bytes(""));
        // account has new impl
        assertEq(address(account3), address(uint160(uint256(vm.load(address(account1), slot)))));
    }

    // TODO: Consider if this test belongs here or in the tests specific to the SingleSignerValidationModule
    function test_transferOwnership() public {
        if (vm.envOr("SMA_TEST", false)) {
            // Note: replaced "owner1" with address(0), this doesn't actually affect the account, but allows the
            // test to pass by ensuring the signer can be set in the validation.
            assertEq(
                singleSignerValidationModule.signers(TEST_DEFAULT_VALIDATION_ENTITY_ID, address(account1)),
                address(0)
            );
        } else {
            assertEq(
                singleSignerValidationModule.signers(TEST_DEFAULT_VALIDATION_ENTITY_ID, address(account1)), owner1
            );
        }

        vm.prank(address(entryPoint));
        account1.execute(
            address(singleSignerValidationModule),
            0,
            abi.encodeCall(
                SingleSignerValidationModule.transferSigner, (TEST_DEFAULT_VALIDATION_ENTITY_ID, owner2)
            )
        );

        assertEq(
            singleSignerValidationModule.signers(TEST_DEFAULT_VALIDATION_ENTITY_ID, address(account1)), owner2
        );
    }

    function test_isValidSignature() public {
        bytes32 message = keccak256("hello world");

        bytes32 replaySafeHash = vm.envOr("SMA_TEST", false)
            ? SemiModularAccount(payable(account1)).replaySafeHash(message)
            : singleSignerValidationModule.replaySafeHash(address(account1), message);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(owner1Key, replaySafeHash);

        bytes memory signature = _encode1271Signature(_signerValidation, abi.encodePacked(r, s, v));

        bytes4 validationResult = IERC1271(address(account1)).isValidSignature(message, signature);

        assertEq(validationResult, bytes4(0x1626ba7e));
    }

    // Only need a test case for the negative case, as the positive case is covered by the isValidSignature test
    function test_signatureValidationFlag_enforce() public {
        // Install a new copy of SingleSignerValidationModule with the signature validation flag set to false
        uint32 newEntityId = 2;
        vm.prank(address(entryPoint));
        account1.installValidation(
            ValidationConfigLib.pack(address(singleSignerValidationModule), newEntityId, false, false, true),
            new bytes4[](0),
            abi.encode(newEntityId, owner1),
            new bytes[](0)
        );

        bytes32 message = keccak256("hello world");

        bytes32 replaySafeHash = vm.envOr("SMA_TEST", false)
            ? SemiModularAccount(payable(account1)).replaySafeHash(message)
            : singleSignerValidationModule.replaySafeHash(address(account1), message);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(owner1Key, replaySafeHash);

        bytes memory signature = _encode1271Signature(
            ModuleEntityLib.pack(address(singleSignerValidationModule), newEntityId), abi.encodePacked(r, s, v)
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                ReferenceModularAccount.SignatureValidationInvalid.selector,
                singleSignerValidationModule,
                newEntityId
            )
        );
        IERC1271(address(account1)).isValidSignature(message, signature);
    }

    function test_userOpValidationFlag_enforce() public {
        // Install a new copy of SingleSignerValidationModule with the userOp validation flag set to false
        uint32 newEntityId = 2;
        vm.prank(address(entryPoint));
        account1.installValidation(
            ValidationConfigLib.pack(address(singleSignerValidationModule), newEntityId, true, false, false),
            new bytes4[](0),
            abi.encode(newEntityId, owner1),
            new bytes[](0)
        );

        PackedUserOperation memory userOp = PackedUserOperation({
            sender: address(account1),
            nonce: 0,
            initCode: "",
            callData: abi.encodeCall(ReferenceModularAccount.execute, (ethRecipient, 1 wei, "")),
            accountGasLimits: _encodeGas(VERIFICATION_GAS_LIMIT, CALL_GAS_LIMIT),
            preVerificationGas: 0,
            gasFees: _encodeGas(1, 1),
            paymasterAndData: "",
            signature: ""
        });

        // Generate signature
        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(owner1Key, userOpHash.toEthSignedMessageHash());
        userOp.signature = _encodeSignature(
            ModuleEntityLib.pack(address(singleSignerValidationModule), newEntityId),
            GLOBAL_VALIDATION,
            abi.encodePacked(r, s, v)
        );

        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;

        vm.expectRevert(
            abi.encodeWithSelector(
                IEntryPoint.FailedOpWithRevert.selector,
                0,
                "AA23 reverted",
                abi.encodeWithSelector(
                    ReferenceModularAccount.UserOpValidationInvalid.selector,
                    singleSignerValidationModule,
                    newEntityId
                )
            )
        );
        entryPoint.handleOps(userOps, beneficiary);

        //show working rt validation
        vm.startPrank(address(owner1));
        account1.executeWithRuntimeValidation(
            abi.encodeCall(ReferenceModularAccount.execute, (ethRecipient, 1 wei, "")),
            _encodeSignature(
                ModuleEntityLib.pack(address(singleSignerValidationModule), newEntityId), GLOBAL_VALIDATION, ""
            )
        );

        assertEq(ethRecipient.balance, 2 wei);
    }

    // Internal Functions

    function _printStorageReadsAndWrites(address addr) internal {
        (bytes32[] memory accountReads, bytes32[] memory accountWrites) = vm.accesses(addr);
        for (uint256 i = 0; i < accountWrites.length; i++) {
            bytes32 valWritten = vm.load(addr, accountWrites[i]);
            // solhint-disable-next-line no-console
            console.log(
                string.concat("write loc: ", vm.toString(accountWrites[i]), " val: ", vm.toString(valWritten))
            );
        }

        for (uint256 i = 0; i < accountReads.length; i++) {
            bytes32 valRead = vm.load(addr, accountReads[i]);
            // solhint-disable-next-line no-console
            console.log(string.concat("read: ", vm.toString(accountReads[i]), " val: ", vm.toString(valRead)));
        }
    }
}
