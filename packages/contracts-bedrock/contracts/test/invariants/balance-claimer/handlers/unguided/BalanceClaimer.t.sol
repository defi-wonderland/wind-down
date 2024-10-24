// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "forge-std/console.sol";

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
        vm.prank(_caller);
        try balanceClaimer.claim(_proof, _user, _ethBalance, _erc20Claim) {
            // TODO: check claim isnt in the valid set
            assert(false); // random claim got accepted
        } catch {
            // TODO: assert claim is not in tree
            // TODO: assert user already claimed
        }
    }

    function handler_canClaim(
        bytes32[] calldata _proof,
        address _user,
        uint256 _ethBalance,
        IErc20BalanceWithdrawer.Erc20BalanceClaim[] calldata _erc20Claim
    ) external {
        if (balanceClaimer.canClaim(_proof, _user, _ethBalance, _erc20Claim)) {
            // TODO: check claim isnt in the valid set
            assert(false); // random claim got accepted
        } else {
            // TODO: assert claim is not in tree
            // TODO: assert user already claimed
        }
    }

    function handler_withdrawEthBalance(address _user, uint256 _ethClaim, address _caller) external {
        try optimismPortal.withdrawEthBalance(_user, _ethClaim) {
            assert(_caller == address(balanceClaimer));
            // TODO: update ghost variables
        } catch {}
    }

    function handler_withdrawErc20Balance(
        address _user,
        IErc20BalanceWithdrawer.Erc20BalanceClaim[] calldata _tokenClaims,
        address _caller
    ) external {
        try l1StandardBridge.withdrawErc20Balance(_user, _tokenClaims) {
            assert(_caller == address(balanceClaimer));
            // TODO: update ghost variables
        } catch {}
    }
}
