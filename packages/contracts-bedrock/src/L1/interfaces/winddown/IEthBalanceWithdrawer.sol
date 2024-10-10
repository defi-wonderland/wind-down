// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IBalanceWithdrawer } from "src/L1/interfaces/winddown/IBalanceWithdrawer.sol";

/// @title IEthBalanceWithdrawer
/// @notice Interface for the EthBalanceWithdrawer contract
interface IEthBalanceWithdrawer is IBalanceWithdrawer {
    /// @notice Thrown when the eth transfer fails
    error EthTransferFailed();

    function withdrawEthBalance(address _user, uint256 _ethBalance) external;
}
