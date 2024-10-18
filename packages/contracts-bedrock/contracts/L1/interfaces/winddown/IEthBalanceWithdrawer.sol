// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import { IBalanceClaimer } from "./IBalanceClaimer.sol";

/// @title IEthBalanceWithdrawer
/// @notice Interface for the EthBalanceWithdrawer contract
interface IEthBalanceWithdrawer {
    /// @notice Thrown when the caller is not the BalanceClaimer contract
    error CallerNotBalanceClaimer();

    /// @notice Thrown when the eth transfer fails
    error EthTransferFailed();

    function withdrawEthBalance(address _user, uint256 _ethBalance) external;

    function balanceClaimer() external view returns (IBalanceClaimer);
}