// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

// Index marking the start of the data for the validation function.
uint8 constant RESERVED_VALIDATION_DATA_INDEX = type(uint8).max;

// Maximum number of entity associated hooks that can be registered.
uint8 constant MAX_VALIDATION_ASSOC_HOOKS = type(uint8).max;

// Magic value for the Entity ID of direct call validation.
uint32 constant DIRECT_CALL_VALIDATION_ENTITY_ID = type(uint32).max;
