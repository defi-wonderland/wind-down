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

    /// @notice Thrown when the merkle root is invalid
    error InvalidMerkleRoot();

    /// @notice the root of the merkle tree
    function root() external view returns (bytes32);

    /// @notice OptimismPortal ethBalanceWithdrawer contract
    function ethBalanceWithdrawer() external view returns (IEthBalanceWithdrawer);

     /// @notice erc20BalanceWithdrawer contract
    function erc20BalanceWithdrawer() external view returns (IErc20BalanceWithdrawer);

    /// @notice return users who claimed their balances
    function claimed(address) external view returns (bool);

    /**
     * @notice Claims the tokens for the user
     * @param _proof The merkle proof
     * @param _user The user address
     * @param _ethBalance The eth balance of the user
     * @param _erc20Claim The ERC20 tokens balances of the user
     */
    function claim(
        bytes32[] calldata _proof,
        address _user,
        uint256 _ethBalance,
        IErc20BalanceWithdrawer.Erc20BalanceClaim[] calldata _erc20Claim
    ) external;

    /**
     * @notice Checks if the user can claim the tokens
     * @param _proof The merkle proof
     * @param _user The user address
     * @param _ethBalance The eth balance of the user
     * @param _erc20Claim The ERC20 tokens balances of the user
     * @return _canClaimTokens True if the user can claim the tokens
     */
    function canClaim(
        bytes32[] calldata _proof,
        address _user,
        uint256 _ethBalance,
        IErc20BalanceWithdrawer.Erc20BalanceClaim[] calldata _erc20Claim
    ) external view returns (bool _canClaimTokens);
}
