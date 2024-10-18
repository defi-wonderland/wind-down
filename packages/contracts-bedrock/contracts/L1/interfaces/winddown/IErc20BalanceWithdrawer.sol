// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import { IBalanceClaimer } from "./IBalanceClaimer.sol";

/**
 * @title IErc20BalanceWithdrawer
 * @notice Interface for the Erc20BalanceWithdrawer contract
 */
interface IErc20BalanceWithdrawer {
    /**
     * @notice Struct for ERC20 balance claim
     * @param token The ERC20 token address
     * @param balance The balance of the user
     */
    struct Erc20BalanceClaim {
        address token;
        uint256 balance;
    }

    /// @notice Thrown when the caller is not the BalanceClaimer contract
    error CallerNotBalanceClaimer();

    function withdrawErc20Balance(address _user, Erc20BalanceClaim[] calldata _erc20Claim)
        external;

    function BALANCE_CLAIMER() external view returns (IBalanceClaimer);
}
