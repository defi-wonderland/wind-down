// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title IBalanceWithdrawer
/// @notice Interface for the BalanceWithdrawer contract
interface IBalanceWithdrawer {
    /// @notice Struct for ERC20 balance claim
    struct Erc20BalanceClaim {
        address token;
        uint256 balance;
    }

    /// @notice Thrown when the caller is not the BalanceClaimer contract
    error CallerNotBalanceClaimer();

    function balanceClaimer() external view returns (address);
}
