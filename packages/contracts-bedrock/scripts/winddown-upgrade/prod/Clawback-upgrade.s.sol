// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { console } from "forge-std/console.sol";
import { Script } from "forge-std/Script.sol";

import { Proxy } from "contracts/universal/Proxy.sol";
import { BalanceClaimer } from "contracts/L1/winddown/BalanceClaimer.sol";
import { WinddownConstants } from "../WinddownConstants.sol";

/// @notice Pure logger: builds and prints the calldata that governance / the
///         multisig should execute against the BalanceClaimer Proxy admin to
///         atomically swap to the v2 implementation and drain funds in the
///         same transaction.
///
///         Run (no broadcast):
///           forge script scripts/winddown-upgrade/prod/Clawback-upgrade.s.sol:ClawbackUpgrade \
///             --rpc-url $ETHEREUM_MAINNET_RPC \
///             --sig "run(address)" <newImpl>
///
///         The printed `target` and `calldata` are pasted into a Safe tx-builder.
contract ClawbackUpgrade is Script {
    function run(address _newImpl) public view {
        require(WinddownConstants.BALANCE_CLAIMER_PROXY != address(0), "BALANCE_CLAIMER_PROXY unset in WinddownConstants");
        require(_newImpl != address(0), "newImpl is zero");
        require(_newImpl.code.length > 0, "newImpl has no code");
        require(BalanceClaimer(_newImpl).FOUNDATION() != address(0), "newImpl: FOUNDATION unset");

        bytes memory _innerCall = abi.encodeCall(BalanceClaimer.clawback, ());
        bytes memory _outerCall =
            abi.encodeWithSelector(Proxy.upgradeToAndCall.selector, _newImpl, _innerCall);

        console.log("=== Clawback upgrade payload ===");
        console.log("target (BalanceClaimer Proxy):", WinddownConstants.BALANCE_CLAIMER_PROXY);
        console.log("newImpl:", _newImpl);
        console.log("value: 0");
        console.log("function: upgradeToAndCall(address,bytes)");
        console.log("inner selector (clawback()):");
        console.logBytes(_innerCall);
        console.log("calldata (paste this into Safe tx-builder):");
        console.logBytes(_outerCall);
    }
}
