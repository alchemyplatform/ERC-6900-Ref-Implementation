// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

/// @title A public counter for anyone to use.
contract Counter {
    uint256 public number;

    /// @notice Set the counter's number to a new value.
    /// @param newNumber The new number for the counter.
    function setNumber(uint256 newNumber) public {
        number = newNumber;
    }

    /// @notice Increase the counter's value by one.
    /// @dev The number is not in an unchecked block, so overflows will revert.
    function increment() public {
        number++;
    }
}
