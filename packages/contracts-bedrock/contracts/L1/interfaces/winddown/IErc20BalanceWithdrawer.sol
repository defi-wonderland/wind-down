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

    /**
     * @notice Withdraws the ERC20 balance to the user.
     * @param _user Address of the user.
     * @param _erc20Claim Array of Erc20BalanceClaim structs containing the token address
     */
    function withdrawErc20Balance(address _user, Erc20BalanceClaim[] calldata _erc20Claim)
        external;

    /**
     * @notice Address of the balance claimer contract.
     * @dev This contract is responsible for claiming the ERC20 balances of the bridge.
     */
    function BALANCE_CLAIMER() external view returns (address);
}
