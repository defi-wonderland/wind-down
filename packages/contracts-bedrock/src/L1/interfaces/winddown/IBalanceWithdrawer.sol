// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title IBalanceWithdrawer
/// @notice Interface for the BalanceWithdrawer contract
interface IBalanceWithdrawer {
    /// @notice Thrown when the caller is not the BalanceClaimer contract
    error CallerNotBalanceClaimer();
}
