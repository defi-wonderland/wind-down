// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import {BalanceClaimer} from "contracts/L1/winddown/BalanceClaimer.sol";
import {OptimismPortal} from "contracts/L1/OptimismPortal.sol";
import {L1StandardBridge} from "contracts/L1/L1StandardBridge.sol";
import {L1ChugSplashProxy} from "contracts/legacy/L1ChugSplashProxy.sol";
import {L2OutputOracle} from "contracts/L1/L2OutputOracle.sol";
import {SystemConfig} from "contracts/L1/SystemConfig.sol";
import {Proxy} from "contracts/universal/Proxy.sol";

import {FuzzERC20} from "./Tokens.t.sol";
import {Claims} from "./Claims.t.sol";

import {CommonBase} from "forge-std/Base.sol";
import {StdUtils} from "forge-std/StdUtils.sol";

contract BalanceClaimerSetup is CommonBase, StdUtils, Claims {
    L1StandardBridge internal l1StandardBridge;
    OptimismPortal internal optimismPortal;
    BalanceClaimer internal balanceClaimer;

    constructor() {
        Proxy balanceClaimerProxy = new Proxy(address(this));

        L1StandardBridge l1StandardBridgeImpl = new L1StandardBridge(payable(0), payable(address(balanceClaimerProxy)));
        OptimismPortal optimismPortalImpl = new OptimismPortal({
            _l2Oracle: L2OutputOracle(address(0)),
            _guardian: address(0),
            _paused: false,
            _config: SystemConfig(address(0)),
            _balanceClaimer: address(balanceClaimerProxy)
        });
        // Get the proxies for L1StandardBridge and OptimismPortal
        L1ChugSplashProxy l1StandardBridgeProxy = new L1ChugSplashProxy(address(this));
        Proxy optimismPortalProxy = new Proxy(address(this));

        BalanceClaimer balanceClaimerImpl =
            new BalanceClaimer(address(optimismPortalProxy), address(l1StandardBridgeProxy), tree[0]);

        // Set BalanceClaimer implementation
        balanceClaimerProxy.upgradeTo(address(balanceClaimerImpl));
        optimismPortalProxy.upgradeTo(address(optimismPortalImpl));
        l1StandardBridgeProxy.setCode(address(l1StandardBridgeImpl).code);

        optimismPortal = OptimismPortal(payable(optimismPortalProxy));
        l1StandardBridge = L1StandardBridge(payable(l1StandardBridgeProxy));
        balanceClaimer = BalanceClaimer(address(balanceClaimerProxy));

        // cant do this in Tokens because l1StandardBridge address is not set at that time
        vm.deal(address(optimismPortal), INITIAL_BALANCE);
        for (uint256 i = 0; i < TOKENS; i++) {
            FuzzERC20(address(supportedTokens[i])).mint(address(l1StandardBridge), INITIAL_BALANCE);
        }
    }

    /// @custom:prop-id  0
    /// @custom:prop sanity checks for setup
    function property_setup() external {
        assert(address(optimismPortal.BALANCE_CLAIMER()) == address(balanceClaimer));
        assert(address(balanceClaimer.ETH_BALANCE_WITHDRAWER()) == address(optimismPortal));
        assert(address(balanceClaimer.ERC20_BALANCE_WITHDRAWER()) == address(l1StandardBridge));
        assert(address(l1StandardBridge.BALANCE_CLAIMER()) == address(balanceClaimer));
        assert(balanceClaimer.ROOT() == tree[0]);
    }
}
