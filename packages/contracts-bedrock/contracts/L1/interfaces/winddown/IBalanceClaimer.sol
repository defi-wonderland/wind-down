// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import { IEthBalanceWithdrawer } from "./IEthBalanceWithdrawer.sol";
import { IErc20BalanceWithdrawer } from "./IErc20BalanceWithdrawer.sol";


/**
  * @title IBalanceClaimer
  * @notice Interface for the BalanceClaimer contract
 */
interface IBalanceClaimer {
    /**
     * @notice Emitted when a user claims their balance
     * @param user The user who claimed their balance
     * @param ethBalance The eth balance of the user
     * @param erc20TokenBalances The ERC20 token balances of the user
     */
    event BalanceClaimed(
        address indexed user,
        uint256 ethBalance,
        IErc20BalanceWithdrawer.Erc20BalanceClaim[] erc20TokenBalances
    );

    /// @notice Thrown when the user has no balance to claim
    error NoBalanceToClaim();

    function root() external view returns (bytes32);

    function ethBalanceWithdrawer() external view returns (IEthBalanceWithdrawer);

    function erc20BalanceWithdrawer() external view returns (IErc20BalanceWithdrawer);

    function claimed(address) external view returns (bool);

    function initialize(
        address _ethBalanceWithdrawer,
        address _erc20BalanceWithdrawer,
        bytes32 _root
    ) external;

    function claim(
        bytes32[] calldata _proof,
        address _user,
        uint256 _ethBalance,
        IErc20BalanceWithdrawer.Erc20BalanceClaim[] calldata _erc20Claim
    ) external;

    function canClaim(
        bytes32[] calldata _proof,
        address _user,
        uint256 _ethBalance,
        IErc20BalanceWithdrawer.Erc20BalanceClaim[] calldata _erc20Claim
    ) external view returns (bool _canClaimTokens);
}
