// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

// Libraries
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

// Interfaces
import { IEthBalanceWithdrawer } from "../interfaces/winddown/IEthBalanceWithdrawer.sol";
import { IErc20BalanceWithdrawer } from "../interfaces/winddown/IErc20BalanceWithdrawer.sol";
import { IBalanceClaimer } from "../interfaces/winddown/IBalanceClaimer.sol";
import { Semver } from "../../universal/Semver.sol";

/**
  * @custom:proxied
  * @notice Contract that allows users to claim and withdraw their eth and erc20 balances
 */
contract BalanceClaimer is Semver, IBalanceClaimer {
    /// @inheritdoc IBalanceClaimer
    bytes32 public immutable ROOT;

    /// @inheritdoc IBalanceClaimer
    IEthBalanceWithdrawer public immutable ETH_BALANCE_WITHDRAWER;

    /// @inheritdoc IBalanceClaimer
    IErc20BalanceWithdrawer public immutable ERC20_BALANCE_WITHDRAWER;

    /// @inheritdoc IBalanceClaimer
    mapping(address => bool) public claimed;

    /**
     * @custom:semver 1.0.0
     * @param _ethBalanceWithdrawer The EthBalanceWithdrawer address
     * @param _erc20BalanceWithdrawer The Erc20BalanceWithdrawer address
     * @param _root The root of the merkle tree
     */
    constructor(address _ethBalanceWithdrawer, address _erc20BalanceWithdrawer, bytes32 _root) Semver(1, 0, 0) {
        if (_root == 0) revert InvalidMerkleRoot();
        ETH_BALANCE_WITHDRAWER = IEthBalanceWithdrawer(_ethBalanceWithdrawer);
        ERC20_BALANCE_WITHDRAWER = IErc20BalanceWithdrawer(_erc20BalanceWithdrawer);
        ROOT = _root;
    }

    /// @inheritdoc IBalanceClaimer
    function claim(
        bytes32[] calldata _proof,
        address _user,
        uint256 _ethBalance,
        IErc20BalanceWithdrawer.Erc20BalanceClaim[] calldata _erc20Claim
    ) external {
        if (!canClaim(_proof, _user, _ethBalance, _erc20Claim)) revert NoBalanceToClaim();
        claimed[_user] = true;

        if (_erc20Claim.length != 0) {
            ERC20_BALANCE_WITHDRAWER.withdrawErc20Balance(_user, _erc20Claim);
        }

        if (_ethBalance != 0) {
            ETH_BALANCE_WITHDRAWER.withdrawEthBalance(_user, _ethBalance);
        }

        emit BalanceClaimed({user: _user, ethBalance: _ethBalance, erc20TokenBalances: _erc20Claim});
    }

    /// @inheritdoc IBalanceClaimer
    function canClaim(
        bytes32[] calldata _proof,
        address _user,
        uint256 _ethBalance,
        IErc20BalanceWithdrawer.Erc20BalanceClaim[] calldata _erc20Claim
    ) public view returns (bool _canClaimTokens) {
        if (claimed[_user]) return false;

        bytes32 _leaf = keccak256(bytes.concat(keccak256(abi.encode(_user, _ethBalance, _erc20Claim))));

        _canClaimTokens = MerkleProof.verify(_proof, ROOT, _leaf);
    }
}