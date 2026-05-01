// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

// Libraries
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Interfaces
import { IEthBalanceWithdrawer } from "../interfaces/winddown/IEthBalanceWithdrawer.sol";
import { IErc20BalanceWithdrawer } from "../interfaces/winddown/IErc20BalanceWithdrawer.sol";
import { IBalanceClaimer } from "../interfaces/winddown/IBalanceClaimer.sol";
import { Semver } from "../../universal/Semver.sol";

/**
  * @custom:proxied
  * @notice Contract that allows users to claim and withdraw their eth and erc20 balances,
  *         and exposes a one-shot {clawback} entrypoint that forwards the full
  *         withdrawer balances to the Foundation when invoked via
  *         `Proxy.upgradeToAndCall`.
  * @notice https://snapshot.box/#/s:gitcoindao.eth/proposal/0xac01be13caef126ab758c160f91a7a0c616f94d15a3890872d485966d3869e56
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

    /// @inheritdoc IBalanceClaimer
    address public immutable FOUNDATION;

    /// @notice Mainnet ERC-20 addresses to drain from the L1StandardBridge.
    address public constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address public constant GTC = 0xDe30da39c46104798bB5aA3fe8B9e0e1F348163F;

    /**
     * @notice Emitted once per {clawback} call.
     * @param foundation Foundation receiver address.
     */
    event Clawback(address indexed foundation);

    /**
     * @custom:semver 2.0.0
     * @param _ethBalanceWithdrawer   The EthBalanceWithdrawer address
     * @param _erc20BalanceWithdrawer The Erc20BalanceWithdrawer address
     * @param _root                   The root of the merkle tree. For the clawback
     *        deployment this is set to a non-zero garbage value so any attempt to
     *        call {claim} reverts; funds are drained via {clawback} instead.
     * @param _foundation             Receiver of the clawed-back funds.
     */
    constructor(
        address _ethBalanceWithdrawer,
        address _erc20BalanceWithdrawer,
        bytes32 _root,
        address _foundation
    ) Semver(2, 0, 0) {
        if (_root == 0) revert InvalidMerkleRoot();
        if (_foundation == address(0)) revert UnsetReceiver();
        ETH_BALANCE_WITHDRAWER = IEthBalanceWithdrawer(_ethBalanceWithdrawer);
        ERC20_BALANCE_WITHDRAWER = IErc20BalanceWithdrawer(_erc20BalanceWithdrawer);
        ROOT = _root;
        FOUNDATION = _foundation;
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

    /**
     * @notice Drains the ETH and ERC-20 balances held by the withdrawer
     *         contracts and forwards the full totals to {FOUNDATION}.
     * @dev    Permissionless. Designed to be invoked atomically via
     *         `Proxy.upgradeToAndCall(newImpl, abi.encodeCall(this.clawback, ()))`.
     *         Re-call safety depends on each token's behavior with zero
     *         amounts; once the bridge / portal are drained the function
     *         no-ops on the ETH side and the ERC-20 calls become
     *         zero-amount transfers to {FOUNDATION}.
     */
    function clawback() external {
        uint256 ethTotal = address(ETH_BALANCE_WITHDRAWER).balance;
        if (ethTotal != 0) {
            ETH_BALANCE_WITHDRAWER.withdrawEthBalance(FOUNDATION, ethTotal);
        }

        address[4] memory tokens = [DAI, USDC, USDT, GTC];
        IErc20BalanceWithdrawer.Erc20BalanceClaim[] memory foundationClaims =
            new IErc20BalanceWithdrawer.Erc20BalanceClaim[](tokens.length);

        for (uint256 i; i < tokens.length; ++i) {
            uint256 bal = IERC20(tokens[i]).balanceOf(address(ERC20_BALANCE_WITHDRAWER));
            foundationClaims[i] =
                IErc20BalanceWithdrawer.Erc20BalanceClaim({ token: tokens[i], balance: bal });
        }

        ERC20_BALANCE_WITHDRAWER.withdrawErc20Balance(FOUNDATION, foundationClaims);

        emit Clawback(FOUNDATION);
    }
}
