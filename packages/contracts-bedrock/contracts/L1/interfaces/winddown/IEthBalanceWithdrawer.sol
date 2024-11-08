// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import { IBalanceClaimer } from "./IBalanceClaimer.sol";

/**
 * @title IEthBalanceWithdrawer
 * @notice Interface for the EthBalanceWithdrawer contract
 */
interface IEthBalanceWithdrawer {
    /// @notice Thrown when the caller is not the BalanceClaimer contract
    error CallerNotBalanceClaimer();

    /// @notice Thrown when the eth transfer fails
    error EthTransferFailed();

    /**
     * @notice Withdraws the ETH balance to the user.
     * @param _user       Address of the user.
     * @param _ethClaim Amount of ETH to withdraw.
     * @dev This function is only callable by the BalanceClaimer contract.
     */
    function withdrawEthBalance(address _user, uint256 _ethClaim) external;

    /**
     * @notice Address of the BalanceClaimer contract.
     * @dev This contract is responsible for claiming the ETH balances of the OptimismPortal.
     */
    function BALANCE_CLAIMER() external view returns (address);
}