// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "forge-std/console.sol";

import {BalanceClaimer} from "contracts/L1/winddown/BalanceClaimer.sol";
import {OptimismPortal} from "contracts/L1/OptimismPortal.sol";
import {L1StandardBridge} from "contracts/L1/L1StandardBridge.sol";
import {L1ChugSplashProxy} from "contracts/legacy/L1ChugSplashProxy.sol";
import {L2OutputOracle} from "contracts/L1/L2OutputOracle.sol";
import {SystemConfig} from "contracts/L1/SystemConfig.sol";
import {Proxy} from "contracts/universal/Proxy.sol";
import {WinddownConstants} from "scripts/winddown-upgrade/WinddownConstants.sol";

import {CommonBase} from "forge-std/Base.sol";

contract BalanceClaimerSetup is CommonBase {
    L1StandardBridge internal l1StandardBridge;
    OptimismPortal internal optimismPortal;
    BalanceClaimer internal balanceClaimer;

    constructor() {
        // _targetContract = new BalanceClaimer();
        // optimismPortal = new OptimimismPortal({
        //     _l2Oracle: L2OutputOracle(address(0)),
        //     _guardian: address(0),
        //     _config: SystemConfig(address(0))},
        //     balanceClaimer: balanceClaimer);
        // l1StandardBridge = new L1StandardBridge(address(0), address(balanceClaimer));
        // Get the proxies for L1StandardBridge and OptimismPortal
        L1ChugSplashProxy l1StandardBridgeProxy =
            L1ChugSplashProxy(payable(address(WinddownConstants.L1_STANDARD_BRIDGE_PROXY)));
        Proxy optimismPortalProxy = Proxy(payable(address(WinddownConstants.OPTIMISM_PORTAL_PROXY)));

        // Deploy BalanceClaimer proxy
        Proxy balanceClaimerProxy = new Proxy(address(this));

        // Deploy BalanceClaimer implementation
        BalanceClaimer balanceClaimerImpl = new BalanceClaimer();

        // Set BalanceClaimer implementation
        balanceClaimerProxy.upgradeToAndCall(
            address(balanceClaimerImpl),
            abi.encodeWithSelector(
                balanceClaimerImpl.initialize.selector,
                address(optimismPortalProxy),
                address(l1StandardBridgeProxy),
                WinddownConstants.MERKLE_ROOT
            )
        );

        optimismPortal = OptimismPortal(payable(optimismPortalProxy));
        l1StandardBridge = L1StandardBridge(payable(l1StandardBridgeProxy));
        balanceClaimer = BalanceClaimer(address(balanceClaimerProxy));
    }

    /// @custom:prop-id  0
    /// @custom:prop sanity checks for setup
    function property_setup() external {
        assert(address(l1StandardBridge.BALANCE_CLAIMER()) == address(balanceClaimer));
        assert(address(optimismPortal.BALANCE_CLAIMER()) == address(balanceClaimer));
        assert(address(balanceClaimer.ethBalanceWithdrawer()) == address(l1StandardBridge));
        assert(address(balanceClaimer.erc20BalanceWithdrawer()) == address(optimismPortal));
        assert(balanceClaimer.root() == bytes32(0));
    }
}
