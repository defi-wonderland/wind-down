// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IBalanceWithdrawer } from "src/L1/interfaces/winddown/IBalanceWithdrawer.sol";
import { IEthBalanceWithdrawer } from "src/L1/interfaces/winddown/IEthBalanceWithdrawer.sol";
import { IErc20BalanceWithdrawer } from "src/L1/interfaces/winddown/IErc20BalanceWithdrawer.sol";

/// @title IBalanceClaimer
/// @notice Interface for the BalanceClaimer contract
interface IBalanceClaimer {
    /// @notice Emitted when a user claims their balance
    event BalanceClaimed(
        address indexed user, uint256 ethBalance, IBalanceWithdrawer.Erc20BalanceClaim[] erc20TokenBalances
    );

    /// @notice Thrown when the user has no balance to claim
    error NoBalanceToClaim();

    function claim(
        bytes32[] calldata _proof,
        address _user,
        uint256 _ethBalance,
        IBalanceWithdrawer.Erc20BalanceClaim[] calldata _erc20TokenBalances
    )
        external;

    function initialize(address _ethBalanceWithdrawer, address _erc20BalanceWithdrawer, bytes32 _root) external;

    function canClaim(
        bytes32[] calldata _proof,
        address _user,
        uint256 _ethBalance,
        IBalanceWithdrawer.Erc20BalanceClaim[] calldata _erc20TokenBalances
    )
        external
        view
        returns (bool _canClaimTokens);

    function root() external view returns (bytes32 _root);

    function claimed(address _user) external view returns (bool _claimed);

    function ethBalanceWithdrawer() external view returns (IEthBalanceWithdrawer _ethBalanceWithdrawer);

    function erc20BalanceWithdrawer() external view returns (IErc20BalanceWithdrawer _erc20BalanceWithdrawer);
}
