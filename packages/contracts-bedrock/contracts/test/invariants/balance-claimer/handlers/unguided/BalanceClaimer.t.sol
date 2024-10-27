// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import {BalanceClaimerSetup} from "../../setup/BalanceClaimer.t.sol";
import {IErc20BalanceWithdrawer} from "contracts/L1/interfaces/winddown/IErc20BalanceWithdrawer.sol";
import {IBalanceClaimer} from "contracts/L1/interfaces/winddown/IBalanceClaimer.sol";

contract BalanceClaimerUnguidedHandlers is BalanceClaimerSetup {
    function handler_initialize(address _ethBalanceWithdrawer, address _erc20BalanceWithdrawer, bytes32 _root)
        external
    {
        try balanceClaimer.initialize(_ethBalanceWithdrawer, _erc20BalanceWithdrawer, _root) {
            assert(false); // balanceClaimer should only be initialized once
        } catch {}
    }

    function handler_claim(
        bytes32[] calldata _proof,
        address _user,
        uint256 _ethBalance,
        IErc20BalanceWithdrawer.Erc20BalanceClaim[] calldata _erc20Claim,
        address _caller
    ) external {
        bytes32 hash = _hashClaim(_user, _ethBalance, _erc20Claim);
        vm.prank(_caller);
        try balanceClaimer.claim(_proof, _user, _ethBalance, _erc20Claim) {
            assert(ghost_claimInTree[hash]);
            assert(!ghost_claimed[_user]);
        } catch {
            assert(!ghost_claimInTree[hash] || ghost_claimed[_user]);
        }
    }

    function handler_canClaim(
        bytes32[] calldata _proof,
        address _user,
        uint256 _ethBalance,
        IErc20BalanceWithdrawer.Erc20BalanceClaim[] calldata _erc20Claim
    ) external {
        bytes32 hash = _hashClaim(_user, _ethBalance, _erc20Claim);
        if (balanceClaimer.canClaim(_proof, _user, _ethBalance, _erc20Claim)) {
            assert(ghost_claimInTree[hash]);
            assert(!ghost_claimed[_user]);
        } else {
            assert(!ghost_claimInTree[hash] || ghost_claimed[_user]);
        }
    }
}
