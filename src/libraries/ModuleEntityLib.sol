// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import {ModuleEntity} from "../interfaces/IERC6900Account.sol";
// ModuleEntity is a packed representation of a module function
// Layout:
// 0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA________________________ // Address
// 0x________________________________________BBBBBBBB________________ // Entity ID
// 0x________________________________________________0000000000000000 // unused

library ModuleEntityLib {
    function pack(address addr, uint32 entityId) internal pure returns (ModuleEntity) {
        return ModuleEntity.wrap(bytes24(bytes20(addr)) | bytes24(uint192(entityId)));
    }

    function unpack(ModuleEntity moduleEntity) internal pure returns (address addr, uint32 entityId) {
        bytes24 underlying = ModuleEntity.unwrap(moduleEntity);
        addr = address(bytes20(underlying));
        entityId = uint32(bytes4(underlying << 160));
    }

    function isEmpty(ModuleEntity moduleEntity) internal pure returns (bool) {
        return ModuleEntity.unwrap(moduleEntity) == bytes24(0);
    }

    function notEmpty(ModuleEntity moduleEntity) internal pure returns (bool) {
        return ModuleEntity.unwrap(moduleEntity) != bytes24(0);
    }

    function eq(ModuleEntity a, ModuleEntity b) internal pure returns (bool) {
        return ModuleEntity.unwrap(a) == ModuleEntity.unwrap(b);
    }

    function notEq(ModuleEntity a, ModuleEntity b) internal pure returns (bool) {
        return ModuleEntity.unwrap(a) != ModuleEntity.unwrap(b);
    }
}
