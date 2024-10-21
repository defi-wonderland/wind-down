// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { console } from "forge-std/console.sol";
import { Script } from "forge-std/Script.sol";

import { Proxy } from "contracts/universal/Proxy.sol";
import { L1ChugSplashProxy } from "contracts/legacy/L1ChugSplashProxy.sol";
import { WinddownConstants } from "../WinddownConstants.sol";

import { IBalanceClaimer, BalanceClaimer } from "contracts/L1/winddown/BalanceClaimer.sol";
import { L1StandardBridge } from "contracts/L1/L1StandardBridge.sol";
import { OptimismPortal } from "contracts/L1/OptimismPortal.sol";

import { L2OutputOracle } from "../../../contracts/L1/L2OutputOracle.sol";
import { SystemConfig } from "../../../contracts/L1/SystemConfig.sol";

contract WinddownUpgrade is Script {
    function run() public {
        uint256 _deployerPk = vm.envUint("PRIVATE_KEY_PROXY_ADMIN");
        address _deployer = vm.addr(_deployerPk);

        // Get the proxies for L1StandardBridge and OptimismPortal
        L1ChugSplashProxy l1StandardBridgeProxy = L1ChugSplashProxy(payable(address(WinddownConstants.L1_STANDARD_BRIDGE_PROXY)));
        Proxy optimismPortalProxy = Proxy(payable(address(WinddownConstants.OPTIMISM_PORTAL_PROXY)));

        vm.startBroadcast(_deployer);

        // Deploy BalanceClaimer proxy
        Proxy balanceClaimerProxy = new Proxy(_deployer);

        // Deploy BalanceClaimer implementation
        BalanceClaimer balanceClaimerImpl = new BalanceClaimer();

        // Deploy OptimismPortal implementation
        OptimismPortal newOpPortalImpl = new OptimismPortal({
            _l2Oracle: L2OutputOracle(WinddownConstants.L2_ORACLE),
            _guardian: WinddownConstants.GUARDIAN,
            _paused: true,
            _config: SystemConfig(WinddownConstants.SYSTEM_CONFIG),
            _balanceClaimer: address(balanceClaimerProxy)
        });

        // Upgrade OptimismPortal
        optimismPortalProxy.upgradeTo(
            address(newOpPortalImpl)
        );

        // OptimismPortal assertions
        assert(address(OptimismPortal(payable(address(optimismPortalProxy))).L2_ORACLE()) == WinddownConstants.L2_ORACLE);
        assert(address(OptimismPortal(payable(address(optimismPortalProxy))).GUARDIAN()) == WinddownConstants.GUARDIAN);
        assert(address(OptimismPortal(payable(address(optimismPortalProxy))).SYSTEM_CONFIG()) == WinddownConstants.SYSTEM_CONFIG);
        assert(address(OptimismPortal(payable(address(optimismPortalProxy))).BALANCE_CLAIMER()) == address(balanceClaimerProxy));
        // No assertion for pause since it's set in the initializer and setting true or false in the new implementation constructor parameter is idempotent

        // Deploy L1StandardBridge implementation
        L1StandardBridge l1StandardBridgeImpl = new L1StandardBridge({
            _messenger: payable(WinddownConstants.MESSENGER),
            _balanceClaimer: address(balanceClaimerProxy)
        });

        // Upgrade L1StandardBridge
        l1StandardBridgeProxy.setCode(address(l1StandardBridgeImpl).code);

        // L1StandardBridge assertions
        assert(address(L1StandardBridge(payable(address(l1StandardBridgeProxy))).BALANCE_CLAIMER()) == address(balanceClaimerProxy));
        assert(address(L1StandardBridge(payable(address(l1StandardBridgeProxy))).MESSENGER()) == WinddownConstants.MESSENGER);


        // Set BalanceClaimer implementation
        balanceClaimerProxy.upgradeToAndCall(
            address(balanceClaimerImpl),
            abi.encodeWithSelector(balanceClaimerImpl.initialize.selector, address(optimismPortalProxy), address(l1StandardBridgeProxy), WinddownConstants.MERKLE_ROOT)
        );

        // BalanceClaimer assertions
        assert(address(BalanceClaimer(address(balanceClaimerProxy)).ethBalanceWithdrawer()) == address(optimismPortalProxy));
        assert(address(BalanceClaimer(address(balanceClaimerProxy)).erc20BalanceWithdrawer()) == address(l1StandardBridgeProxy));
        assert(BalanceClaimer(address(balanceClaimerProxy)).root() == WinddownConstants.MERKLE_ROOT);

        vm.stopBroadcast();
    }
}