// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

// Interfaces
import { IBalanceWithdrawer } from "src/L1/interfaces/winddown/IBalanceWithdrawer.sol";
import { IEthBalanceWithdrawer } from "src/L1/interfaces/winddown/IEthBalanceWithdrawer.sol";
import { IErc20BalanceWithdrawer } from "src/L1/interfaces/winddown/IErc20BalanceWithdrawer.sol";
import { IBalanceClaimer } from "src/L1/interfaces/winddown/IBalanceClaimer.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { ISemver } from "src/universal/interfaces/ISemver.sol";

/// @title BalanceClaimer
/// @notice Contract that allows users to claim and withdraw their balances
contract BalanceClaimer is Initializable, IBalanceClaimer, ISemver {
    string public constant version = "1.0.0";

    /// @notice the root of the merkle tree
    bytes32 public root;

    /// @notice OptimismPortal proxy address
    IEthBalanceWithdrawer public ethBalanceWithdrawer;

    /// @notice L1StandardBridge proxy address
    IErc20BalanceWithdrawer public erc20BalanceWithdrawer;

    /// @notice The mapping of users who have claimed their balances
    mapping(address => bool) public claimed;

    constructor() {
        initialize({ _ethBalanceWithdrawer: address(0), _erc20BalanceWithdrawer: address(0), _root: bytes32(0) });
    }

    function initialize(
        address _ethBalanceWithdrawer,
        address _erc20BalanceWithdrawer,
        bytes32 _root
    )
        public
        initializer
    {
        ethBalanceWithdrawer = IEthBalanceWithdrawer(_ethBalanceWithdrawer);
        erc20BalanceWithdrawer = IErc20BalanceWithdrawer(_erc20BalanceWithdrawer);
        root = _root;
    }

    /// @notice Claims the tokens for the user
    /// @param _proof The merkle proof
    /// @param _user The user address
    /// @param _ethBalance The eth balance of the user
    /// @param _erc20TokenBalances The ERC20 tokens balances of the user
    function claim(
        bytes32[] calldata _proof,
        address _user,
        uint256 _ethBalance,
        IBalanceWithdrawer.Erc20BalanceClaim[] calldata _erc20TokenBalances
    )
        external
    {
        if (!_canClaim(_proof, _user, _ethBalance, _erc20TokenBalances)) {
            revert NoBalanceToClaim();
        }
        claimed[_user] = true;
        if (_erc20TokenBalances.length != 0) {
            erc20BalanceWithdrawer.withdrawErc20Balance(_user, _erc20TokenBalances);
        }
        if (_ethBalance != 0) {
            ethBalanceWithdrawer.withdrawEthBalance(_user, _ethBalance);
        }
        emit BalanceClaimed({ user: _user, ethBalance: _ethBalance, erc20TokenBalances: _erc20TokenBalances });
    }

    /// @notice Checks if the user can claim the tokens
    /// @param _proof The merkle proof
    /// @param _user The user address
    /// @param _ethBalance The eth balance of the user
    /// @param _erc20TokenBalances The ERC20 tokens balances of the user
    /// @return _canClaimTokens True if the user can claim the tokens
    function canClaim(
        bytes32[] calldata _proof,
        address _user,
        uint256 _ethBalance,
        IBalanceWithdrawer.Erc20BalanceClaim[] calldata _erc20TokenBalances
    )
        external
        view
        returns (bool _canClaimTokens)
    {
        _canClaimTokens = _canClaim(_proof, _user, _ethBalance, _erc20TokenBalances);
    }

    /// @notice Checks if the user can claim the tokens
    /// @param _proof The merkle proof
    /// @param _user The user address
    /// @param _ethBalance The eth balance of the user
    /// @param _erc20TokenBalances The ERC20 tokens balances of the user
    /// @return _canClaimTokens True if the user can claim the tokens
    function _canClaim(
        bytes32[] calldata _proof,
        address _user,
        uint256 _ethBalance,
        IBalanceWithdrawer.Erc20BalanceClaim[] calldata _erc20TokenBalances
    )
        internal
        view
        returns (bool _canClaimTokens)
    {
        if (claimed[_user]) return false;
        bytes32 _leaf = keccak256(bytes.concat(keccak256(abi.encode(_user, _erc20TokenBalances, _ethBalance))));
        _canClaimTokens = MerkleProof.verify(_proof, root, _leaf);
    }
}
