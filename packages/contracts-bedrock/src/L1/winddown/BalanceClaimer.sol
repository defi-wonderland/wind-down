// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

import { IEthBalanceWithdrawer } from "src/L1/interfaces/winddown/IEthBalanceWithdrawer.sol";
import { IErc20BalanceWithdrawer } from "src/L1/interfaces/winddown/IErc20BalanceWithdrawer.sol";
import { IBalanceClaimer } from "src/L1/interfaces/winddown/IBalanceClaimer.sol";

/// @title BalanceClaimer
/// @notice Contract that allows users to claim and withdraw their balances
contract BalanceClaimer is IBalanceClaimer {
    /// @notice the root of the merkle tree
    bytes32 public root;

    /// @notice OptimismPortal proxy address
    IEthBalanceWithdrawer public constant ETH_BALANCE_WITHDRAWER =
        IEthBalanceWithdrawer(0xb26Fd985c5959bBB382BAFdD0b879E149e48116c);

    /// @notice L1StandardBridge proxy address
    IErc20BalanceWithdrawer public constant ERC20_BALANCE_WITHDRAWER =
        IErc20BalanceWithdrawer(0xD0204B9527C1bA7bD765Fa5CCD9355d38338272b);

    /// @notice The mapping of users who have claimed their balances
    mapping(address => bool) public claimed;

    constructor(bytes32 _root) {
        root = _root;
    }

    /// @notice Claims the tokens for the user
    /// @param _proof The merkle proof
    /// @param _user The user address
    /// @param _daiBalance The DAI balance of the user
    /// @param _usdcBalance The USDC balance of the user
    /// @param _usdtBalance The USDT balance of the user
    /// @param _gtcBalance The GTC balance of the user
    /// @param _ethBalance The eth balance of the user
    function claim(
        bytes32[] calldata _proof,
        address _user,
        uint256 _daiBalance,
        uint256 _usdcBalance,
        uint256 _usdtBalance,
        uint256 _gtcBalance,
        uint256 _ethBalance
    )
        external
    {
        if (!_canClaim(_proof, _user, _daiBalance, _usdcBalance, _usdtBalance, _gtcBalance, _ethBalance)) {
            revert NoBalanceToClaim();
        }
        claimed[_user] = true;
        if (_daiBalance != 0 || _usdcBalance != 0 || _usdtBalance != 0 || _gtcBalance != 0) {
            ERC20_BALANCE_WITHDRAWER.withdrawErc20Balance(_user, _daiBalance, _usdcBalance, _usdtBalance, _gtcBalance);
        }
        if (_ethBalance != 0) {
            ETH_BALANCE_WITHDRAWER.withdrawEthBalance(_user, _ethBalance);
        }
        emit BalanceClaimed({
            user: _user,
            daiBalance: _daiBalance,
            usdcBalance: _usdcBalance,
            usdtBalance: _usdtBalance,
            gtcBalance: _gtcBalance,
            ethBalance: _ethBalance
        });
    }

    /// @notice Checks if the user can claim the tokens
    /// @param _proof The merkle proof
    /// @param _user The user address
    /// @param _daiBalance The DAI balance of the user
    /// @param _usdcBalance The USDC balance of the user
    /// @param _usdtBalance The USDT balance of the user
    /// @param _gtcBalance The GTC balance of the user
    /// @param _ethBalance The eth balance of the user
    /// @return _canClaimTokens True if the user can claim the tokens
    function canClaim(
        bytes32[] calldata _proof,
        address _user,
        uint256 _daiBalance,
        uint256 _usdcBalance,
        uint256 _usdtBalance,
        uint256 _gtcBalance,
        uint256 _ethBalance
    )
        external
        view
        returns (bool _canClaimTokens)
    {
        _canClaimTokens = _canClaim(_proof, _user, _daiBalance, _usdcBalance, _usdtBalance, _gtcBalance, _ethBalance);
    }

    /// @notice Checks if the user can claim the tokens
    /// @param _proof The merkle proof
    /// @param _user The user address
    /// @param _daiBalance The DAI balance of the user
    /// @param _usdcBalance The USDC balance of the user
    /// @param _usdtBalance The USDT balance of the user
    /// @param _gtcBalance The GTC balance of the user
    /// @param _ethBalance The eth balance of the user
    /// @return _canClaimTokens True if the user can claim the tokens
    function _canClaim(
        bytes32[] calldata _proof,
        address _user,
        uint256 _daiBalance,
        uint256 _usdcBalance,
        uint256 _usdtBalance,
        uint256 _gtcBalance,
        uint256 _ethBalance
    )
        internal
        view
        returns (bool)
    {
        if (claimed[_user]) return false;
        bytes32 _leaf = keccak256(
            bytes.concat(
                keccak256(abi.encode(_user, _daiBalance, _usdcBalance, _usdtBalance, _gtcBalance, _ethBalance))
            )
        );
        return MerkleProof.verify(_proof, root, _leaf);
    }
}
