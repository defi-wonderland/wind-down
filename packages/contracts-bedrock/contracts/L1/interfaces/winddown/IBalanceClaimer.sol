// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {IEthBalanceWithdrawer} from "./IEthBalanceWithdrawer.sol";
import {IErc20BalanceWithdrawer} from "./IErc20BalanceWithdrawer.sol";

/// @title IBalanceClaimer
/// @notice Interface for the BalanceClaimer contract
interface IBalanceClaimer {
    event Initialized(uint8 version);

    /// @notice Emitted when a user claims their balance
    event BalanceClaimed(
        address indexed user, uint256 ethBalance, IErc20BalanceWithdrawer.Erc20BalanceClaim[] erc20TokenBalances
    );

    /// @notice Thrown when the user has no balance to claim
    error NoBalanceToClaim();

    function version() external view returns (string memory);

    function root() external view returns (bytes32);

    function ethBalanceWithdrawer() external view returns (IEthBalanceWithdrawer);

    function erc20BalanceWithdrawer() external view returns (IErc20BalanceWithdrawer);

    function claimed(address) external view returns (bool);

    function __constructor__() external;

    function initialize(address _ethBalanceWithdrawer, address _erc20BalanceWithdrawer, bytes32 _root) external;

    function claim(
        bytes32[] calldata _proof,
        address _user,
        uint256 _ethBalance,
        IErc20BalanceWithdrawer.Erc20BalanceClaim[] calldata _erc20TokenBalances
    ) external;

    function canClaim(
        bytes32[] calldata _proof,
        address _user,
        uint256 _ethBalance,
        IErc20BalanceWithdrawer.Erc20BalanceClaim[] calldata _erc20TokenBalances
    ) external view returns (bool _canClaimTokens);
}
