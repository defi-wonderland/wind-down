// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

// Libraries
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

// Interfaces
import { IEthBalanceWithdrawer } from "../interfaces/winddown/IEthBalanceWithdrawer.sol";
import { IErc20BalanceWithdrawer } from "../interfaces/winddown/IErc20BalanceWithdrawer.sol";
import { IBalanceClaimer } from "../interfaces/winddown/IBalanceClaimer.sol";
import { Semver } from "../../universal/Semver.sol";

/**
  * @custom:proxied
  * @notice Contract that allows users to claim and withdraw their eth and erc20 balances
 */
contract BalanceClaimer is Initializable, Semver, IBalanceClaimer {
    /// @notice the root of the merkle tree
    bytes32 public root;

    /// @notice OptimismPortal proxy address
    IEthBalanceWithdrawer public ethBalanceWithdrawer;

    /// @notice L1StandardBridge proxy address
    IErc20BalanceWithdrawer public erc20BalanceWithdrawer;

    /// @notice The mapping of users who have claimed their balances
    mapping(address => bool) public claimed;

    /**
     * @custom:semver 1.7.0
     */
    constructor() Semver(1, 0, 0) {
        initialize({_ethBalanceWithdrawer: address(0), _erc20BalanceWithdrawer: address(0), _root: bytes32(0)});
    }

    /**
     * @notice Initializer
     * @param _ethBalanceWithdrawer The EthBalanceWithdrawer address
     * @param _erc20BalanceWithdrawer The Erc20BalanceWithdrawer address
     * @param _root The root of the merkle tree
     */
    function initialize(address _ethBalanceWithdrawer, address _erc20BalanceWithdrawer, bytes32 _root)
        public
        initializer
    {
        ethBalanceWithdrawer = IEthBalanceWithdrawer(_ethBalanceWithdrawer);
        erc20BalanceWithdrawer = IErc20BalanceWithdrawer(_erc20BalanceWithdrawer);
        root = _root;
    }

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
    ) external {
        if (!canClaim(_proof, _user, _ethBalance, _erc20Claim)) revert NoBalanceToClaim();
        claimed[_user] = true;

        if (_erc20Claim.length != 0) {
            erc20BalanceWithdrawer.withdrawErc20Balance(_user, _erc20Claim);
        }

        if (_ethBalance != 0) {
            ethBalanceWithdrawer.withdrawEthBalance(_user, _ethBalance);
        }

        emit BalanceClaimed({user: _user, ethBalance: _ethBalance, erc20TokenBalances: _erc20Claim});
    }

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
    ) public view returns (bool _canClaimTokens) {
        if (claimed[_user]) return false;

        bytes32 _leaf = keccak256(bytes.concat(keccak256(abi.encode(_user, _ethBalance, _erc20Claim))));

        _canClaimTokens = MerkleProof.verify(_proof, root, _leaf);
    }
}