// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import {BalanceClaimerSetup} from "../setup/BalanceClaimer.t.sol";

contract BalanceClaimerProperties is BalanceClaimerSetup {
    /// @custom:property-id 5
    /// @custom:property for each token, token.balanceOf(L1StandardBridge) == initialBalance - sum of claims
    function property_tokenBalancesSum() external view {
        for (uint256 i = 0; i < supportedTokens.length; i++) {
            assert(
                supportedTokens[i].balanceOf(address(l1StandardBridge))
                    == INITIAL_BALANCE - ghost_claimedTokens[address(supportedTokens[i])]
            );
        }
    }

    /// @custom:property-id 6
    /// @custom:property OptimismPortal.balance == initialBalance - sum of claims
    function property_ethBalancesSum() external view {
        assert(address(optimismPortal).balance == INITIAL_BALANCE- ghost_claimedEther);
    }
}
