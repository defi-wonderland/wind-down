// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import {BalanceClaimerSetup} from "../../setup/BalanceClaimer.t.sol";
import {IErc20BalanceWithdrawer} from "contracts/L1/interfaces/winddown/IErc20BalanceWithdrawer.sol";
import {IBalanceClaimer} from "contracts/L1/interfaces/winddown/IBalanceClaimer.sol";

contract BalanceClaimerUnguidedHandlers is BalanceClaimerSetup {
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
            //prop-id 1
            assert(ghost_claimInTree[hash]);
            //prop-id 2;
            assert(!ghost_claimed[_user]);
            ghost_claimed[_user]=true;
        } catch {
            assert(
                !ghost_claimInTree[hash] // prop-id 4
                    || ghost_claimed[_user] //prop-id 3
            );
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
            //prop-id 1
            assert(ghost_claimInTree[hash]);
            // prop-id 2
            assert(!ghost_claimed[_user]);
        } else {
            assert(
                !ghost_claimInTree[hash] // prop-id 4
                    || ghost_claimed[_user] //prop-id 3
            );
        }
    }
}
