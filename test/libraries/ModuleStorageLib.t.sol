// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {ModuleStorageLib, StoragePointer} from "../../src/libraries/ModuleStorageLib.sol";

contract ModuleStorageLibTest is Test {
    using ModuleStorageLib for bytes;
    using ModuleStorageLib for bytes32;

    uint256 public constant FUZZ_ARR_SIZE = 32;

    address public account1;

    struct TestStruct {
        uint256 a;
        uint256 b;
    }

    function setUp() public {
        account1 = makeAddr("account1");
    }

    function test_storagePointer() public {
        bytes memory key = ModuleStorageLib.allocateAssociatedStorageKey(account1, 0, 1);

        StoragePointer ptr = ModuleStorageLib.associatedStorageLookup(
            key, hex"00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff"
        );
        TestStruct storage val = _castPtrToStruct(ptr);

        vm.record();
        val.a = 0xdeadbeef;
        val.b = 123;
        (, bytes32[] memory accountWrites) = vm.accesses(address(this));

        // printStorageReadsAndWrites(address(this));

        assertEq(accountWrites.length, 2);
        bytes32 expectedKey = keccak256(
            abi.encodePacked(
                uint256(uint160(account1)),
                uint256(0),
                hex"00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff"
            )
        );
        assertEq(accountWrites[0], expectedKey);
        assertEq(vm.load(address(this), expectedKey), bytes32(uint256(0xdeadbeef)));
        assertEq(accountWrites[1], bytes32(uint256(expectedKey) + 1));
        assertEq(vm.load(address(this), bytes32(uint256(expectedKey) + 1)), bytes32(uint256(123)));
    }

    function testFuzz_storagePointer(
        address account,
        uint256 batchIndex,
        bytes32 inputKey,
        uint256[FUZZ_ARR_SIZE] calldata values
    ) public {
        bytes memory key = ModuleStorageLib.allocateAssociatedStorageKey(account, batchIndex, 1);
        uint256[FUZZ_ARR_SIZE] storage val =
            _castPtrToArray(ModuleStorageLib.associatedStorageLookup(key, inputKey));
        // Write values to storage
        vm.record();
        for (uint256 i = 0; i < FUZZ_ARR_SIZE; i++) {
            val[i] = values[i];
        }
        // Assert the writes took place in the right location, and the correct value is stored there
        (, bytes32[] memory accountWrites) = vm.accesses(address(this));
        assertEq(accountWrites.length, FUZZ_ARR_SIZE);
        for (uint256 i = 0; i < FUZZ_ARR_SIZE; i++) {
            bytes32 expectedKey = bytes32(
                uint256(keccak256(abi.encodePacked(uint256(uint160(account)), uint256(batchIndex), inputKey))) + i
            );
            assertEq(accountWrites[i], expectedKey);
            assertEq(vm.load(address(this), expectedKey), bytes32(uint256(values[i])));
        }
    }

    function _castPtrToArray(StoragePointer ptr) internal pure returns (uint256[FUZZ_ARR_SIZE] storage val) {
        /// @solidity memory-safe-assembly
        assembly {
            val.slot := ptr
        }
    }

    function _castPtrToStruct(StoragePointer ptr) internal pure returns (TestStruct storage val) {
        /// @solidity memory-safe-assembly
        assembly {
            val.slot := ptr
        }
    }
}
