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

        BalanceClaimer _impl = BalanceClaimer(_newImpl);
        require(
            keccak256(bytes(_impl.version())) == keccak256(bytes("2.0.0")),
            "newImpl: wrong semver"
        );
        require(_impl.ROOT() == WinddownConstants.CLAWBACK_GARBAGE_ROOT, "newImpl: wrong ROOT");

        address _ethWithdrawer = address(_impl.ETH_BALANCE_WITHDRAWER());
        require(_ethWithdrawer != address(0), "newImpl: ETH_BALANCE_WITHDRAWER is zero");
        require(_ethWithdrawer.code.length > 0, "newImpl: ETH_BALANCE_WITHDRAWER has no code");
        require(_ethWithdrawer == WinddownConstants.OPTIMISM_PORTAL_PROXY, "newImpl: wrong ETH_BALANCE_WITHDRAWER");

        address _erc20Withdrawer = address(_impl.ERC20_BALANCE_WITHDRAWER());
        require(_erc20Withdrawer != address(0), "newImpl: ERC20_BALANCE_WITHDRAWER is zero");
        require(_erc20Withdrawer.code.length > 0, "newImpl: ERC20_BALANCE_WITHDRAWER has no code");
        require(_erc20Withdrawer == WinddownConstants.L1_STANDARD_BRIDGE_PROXY, "newImpl: wrong ERC20_BALANCE_WITHDRAWER");

        require(_impl.FOUNDATION() == WinddownConstants.FOUNDATION, "newImpl: wrong FOUNDATION");

        // The live withdrawers must already recognize
        // BALANCE_CLAIMER_PROXY as their authorized caller, otherwise
        // `clawback()` will revert with `CallerNotBalanceClaimer` after the
        // upgrade lands.
        require(
            _impl.ETH_BALANCE_WITHDRAWER().BALANCE_CLAIMER() == WinddownConstants.BALANCE_CLAIMER_PROXY,
            "OptimismPortal: BALANCE_CLAIMER mismatch"
        );
        require(
            _impl.ERC20_BALANCE_WITHDRAWER().BALANCE_CLAIMER() == WinddownConstants.BALANCE_CLAIMER_PROXY,
            "L1StandardBridge: BALANCE_CLAIMER mismatch"
        );

        bytes memory _innerCall = abi.encodeCall(BalanceClaimer.clawback, ());
        bytes memory _outerCall = abi.encodeCall(Proxy.upgradeToAndCall, (_newImpl, _innerCall));

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
