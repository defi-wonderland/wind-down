// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { console } from "forge-std/console.sol";
import { Script } from "forge-std/Script.sol";

import { BalanceClaimer } from "contracts/L1/winddown/BalanceClaimer.sol";
import { IEthBalanceWithdrawer } from "contracts/L1/interfaces/winddown/IEthBalanceWithdrawer.sol";
import { IErc20BalanceWithdrawer } from "contracts/L1/interfaces/winddown/IErc20BalanceWithdrawer.sol";
import { WinddownConstants } from "../WinddownConstants.sol";

/// @notice Deploys the v2 BalanceClaimer implementation with a non-zero garbage
///         Merkle root. The address printed at the end is the only artifact this
///         script produces; the actual proxy upgrade is performed separately by
///         governance / the multisig (see Clawback-upgrade.s.sol for the calldata).
///
///         Signing is delegated to forge's wallet flags: pass `--account` and
///         `--sender` (e.g. `forge script ... --account deployer --sender 0x...`)
///         so the deployer key never has to leave the keystore.
contract ClawbackImplementationDeploy is Script {
    function run() public {
        // Guard against pointing at a non-mainnet RPC: every constant baked
        // into the impl is mainnet-specific, so deploying anywhere else
        // produces an artifact that looks plausible but is wired to ghosts.
        require(block.chainid == 1, "wrong chainid: expected mainnet (1)");

        // The live proxies and Foundation must already exist on this chain;
        // a wrong fork could pass the chainid check on a freshly forked node
        // where these addresses have no code yet.
        require(
            WinddownConstants.BALANCE_CLAIMER_PROXY.code.length > 0,
            "BALANCE_CLAIMER_PROXY has no code"
        );
        require(
            WinddownConstants.OPTIMISM_PORTAL_PROXY.code.length > 0,
            "OPTIMISM_PORTAL_PROXY has no code"
        );
        require(
            WinddownConstants.L1_STANDARD_BRIDGE_PROXY.code.length > 0,
            "L1_STANDARD_BRIDGE_PROXY has no code"
        );

        // The live withdrawers must already authorize BALANCE_CLAIMER_PROXY,
        // otherwise `clawback()` will revert with `CallerNotBalanceClaimer`
        // after the upgrade lands.
        require(
            IEthBalanceWithdrawer(WinddownConstants.OPTIMISM_PORTAL_PROXY).BALANCE_CLAIMER()
                == WinddownConstants.BALANCE_CLAIMER_PROXY,
            "OptimismPortal: BALANCE_CLAIMER mismatch"
        );
        require(
            IErc20BalanceWithdrawer(WinddownConstants.L1_STANDARD_BRIDGE_PROXY).BALANCE_CLAIMER()
                == WinddownConstants.BALANCE_CLAIMER_PROXY,
            "L1StandardBridge: BALANCE_CLAIMER mismatch"
        );

        vm.startBroadcast();

        BalanceClaimer balanceClaimerImpl = new BalanceClaimer({
            _ethBalanceWithdrawer: WinddownConstants.OPTIMISM_PORTAL_PROXY,
            _erc20BalanceWithdrawer: WinddownConstants.L1_STANDARD_BRIDGE_PROXY,
            _root: WinddownConstants.CLAWBACK_GARBAGE_ROOT
        });

        vm.stopBroadcast();

        // Sanity-check the impl is wired to live mainnet proxies and the disabled root.
        assert(address(balanceClaimerImpl.ETH_BALANCE_WITHDRAWER()) == WinddownConstants.OPTIMISM_PORTAL_PROXY);
        assert(address(balanceClaimerImpl.ERC20_BALANCE_WITHDRAWER()) == WinddownConstants.L1_STANDARD_BRIDGE_PROXY);
        assert(balanceClaimerImpl.ROOT() == WinddownConstants.CLAWBACK_GARBAGE_ROOT);
        assert(balanceClaimerImpl.FOUNDATION() == WinddownConstants.FOUNDATION);

        console.log("BalanceClaimer (clawback) implementation deployed at: ", address(balanceClaimerImpl));
    }
}
