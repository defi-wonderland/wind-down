// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import {IErc20BalanceWithdrawer} from "contracts/L1/interfaces/winddown/IErc20BalanceWithdrawer.sol";
import {BalanceClaimerSetup} from "../../setup/BalanceClaimer.t.sol";

contract BalanceClaimerGuidedHandlers is BalanceClaimerSetup {
    function handler_claim(uint256 claimIndex) external {
        claimIndex = bound(claimIndex, 0, ghost_validClaims.length - 1);
        Claim memory claim = ghost_validClaims[claimIndex];
        bytes32 hashedClaim = _hashClaim(claim);
        bytes32[] memory proof = getProof(tree, getIndex(tree, hashedClaim));
        vm.prank(msg.sender);
        // prop-id 1
        try balanceClaimer.claim(proof, claim.user, claim.ethAmount, _claimToErc20ClaimArray(claim)) {
            ghost_claimed[claim.user] = true;
            ghost_claimedEther += claim.ethAmount;
            for (uint256 i = 0; i < claim.tokens.length; i++) {
                ghost_claimedTokens[claim.tokens[i]] += claim.tokenAmounts[i];
            }
        } catch {
            // prop-id 2
            assert(ghost_claimed[claim.user]);
        }
    }
}
