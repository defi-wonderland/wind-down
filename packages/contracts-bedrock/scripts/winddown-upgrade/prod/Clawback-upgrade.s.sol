// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { console } from "forge-std/console.sol";
import { Script } from "forge-std/Script.sol";

import { ProxyAdmin } from "contracts/universal/ProxyAdmin.sol";
import { BalanceClaimer } from "contracts/L1/winddown/BalanceClaimer.sol";
import { WinddownConstants } from "../WinddownConstants.sol";

/// @notice Pure logger: builds and prints the calldata that the Safe owning
///         the BalanceClaimer Proxy's `ProxyAdmin` should execute to
///         atomically swap to the v2 implementation and drain funds in the
///         same transaction.
///
///         The Safe must call `ProxyAdmin.upgradeAndCall(proxy, newImpl, data)`
///         on the ProxyAdmin (not the proxy directly): the proxy's admin slot
///         is the ProxyAdmin contract, and only the ProxyAdmin's `owner()`
///         (the Safe) can authorize an upgrade. The ProxyAdmin in turn calls
///         `Proxy.upgradeToAndCall` internally.
///
///         Run (no broadcast):
///           forge script scripts/winddown-upgrade/prod/Clawback-upgrade.s.sol:ClawbackUpgrade \
///             --rpc-url $ETHEREUM_MAINNET_RPC \
///             --sig "run(address)" <newImpl>
///
///         The printed `target` and `calldata` are pasted into the Safe tx-builder.
contract ClawbackUpgrade is Script {
    /// @dev EIP-1967 admin slot: `bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1)`.
    bytes32 internal constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

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

        // Resolve and validate the ProxyAdmin (= proxy's EIP-1967 admin slot).
        address _proxyAdmin = address(uint160(uint256(
            vm.load(WinddownConstants.BALANCE_CLAIMER_PROXY, ADMIN_SLOT)
        )));
        require(_proxyAdmin != address(0), "ProxyAdmin slot is empty");
        require(_proxyAdmin.code.length > 0, "ProxyAdmin has no code");

        // Sanity-check this really is an OP ProxyAdmin pointing at the right
        // proxy: it must report ERC1967 (== 0) for our proxy and have a
        // non-zero owner (the Safe).
        require(
            uint8(ProxyAdmin(_proxyAdmin).proxyType(WinddownConstants.BALANCE_CLAIMER_PROXY)) == 0,
            "ProxyAdmin: BalanceClaimer Proxy is not ERC1967"
        );
        require(ProxyAdmin(_proxyAdmin).owner() != address(0), "ProxyAdmin: owner is zero");

        bytes memory _innerCall = abi.encodeCall(BalanceClaimer.clawback, ());
        bytes memory _outerCall = abi.encodeCall(
            ProxyAdmin.upgradeAndCall,
            (payable(WinddownConstants.BALANCE_CLAIMER_PROXY), _newImpl, _innerCall)
        );

        console.log("");
        console.log("==== Safe Transaction Builder inputs (paste into the UI) ====");
        console.log("To:    ", _proxyAdmin);
        console.log("Value:  0");
        console.log("Data:");
        console.logBytes(_outerCall);
        console.log("");
        console.log("==== Reference (verification only, do not paste) ====");
        console.log("Function:               ProxyAdmin.upgradeAndCall(proxy, newImpl, data)");
        console.log("ProxyAdmin (target):    ", _proxyAdmin);
        console.log("ProxyAdmin owner (Safe):", ProxyAdmin(_proxyAdmin).owner());
        console.log("BalanceClaimer Proxy:   ", WinddownConstants.BALANCE_CLAIMER_PROXY);
        console.log("New implementation:     ", _newImpl);
        console.log("Inner call (clawback):");
        console.logBytes(_innerCall);
    }
}
