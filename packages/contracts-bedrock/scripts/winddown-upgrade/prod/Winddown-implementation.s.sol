// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { console } from "forge-std/console.sol";
import { Script } from "forge-std/Script.sol";

import { Proxy } from "contracts/universal/Proxy.sol";
import { WinddownConstants } from "../WinddownConstants.sol";

import { IBalanceClaimer, BalanceClaimer } from "contracts/L1/winddown/BalanceClaimer.sol";
import { L1StandardBridge } from "contracts/L1/L1StandardBridge.sol";
import { OptimismPortal } from "contracts/L1/OptimismPortal.sol";

import { L2OutputOracle } from "../../../contracts/L1/L2OutputOracle.sol";
import { SystemConfig } from "../../../contracts/L1/SystemConfig.sol";

contract WinddownImplementationDeploy is Script {
    function run() public {
        uint256 _deployerPk = vm.envUint("PRIVATE_KEY_DEPLOYER");
        address _deployer = vm.addr(_deployerPk);
        address _balanceClaimerProxyAdmin = vm.envAddress("BALANCE_CLAIMER_PROXY_ADMIN_PUBLIC_ADDRESS");
        vm.startBroadcast(_deployer);

        // Deploy BalanceClaimer proxy
        Proxy balanceClaimerProxy = new Proxy(_deployer);

        // Deploy BalanceClaimer implementation
        BalanceClaimer balanceClaimerImpl = new BalanceClaimer({
            _ethBalanceWithdrawer: WinddownConstants.OPTIMISM_PORTAL_PROXY,
            _erc20BalanceWithdrawer: WinddownConstants.L1_STANDARD_BRIDGE_PROXY,
            _root: WinddownConstants.MERKLE_ROOT,
            _foundation: WinddownConstants.FOUNDATION_RECEIVER,
            _timelock: WinddownConstants.TIMELOCK_RECEIVER
        });

         // Set BalanceClaimer implementation
        balanceClaimerProxy.upgradeTo(address(balanceClaimerImpl));

        // Change the admin of the BalanceClaimer proxy
        balanceClaimerProxy.changeAdmin(_balanceClaimerProxyAdmin);

        // Deploy OptimismPortal implementation
        OptimismPortal opPortalImpl = new OptimismPortal({
            _l2Oracle: L2OutputOracle(WinddownConstants.L2_ORACLE),
            _guardian: WinddownConstants.GUARDIAN,
            _paused: true,
            _config: SystemConfig(WinddownConstants.SYSTEM_CONFIG),
            _balanceClaimer: address(balanceClaimerProxy)
        });


        // Deploy L1StandardBridge implementation
        L1StandardBridge l1StandardBridgeImpl = new L1StandardBridge({
            _messenger: payable(WinddownConstants.MESSENGER),
            _balanceClaimer: address(balanceClaimerProxy)
        });

        vm.stopBroadcast();

        // BalanceClaimer assertions
        assert(address(BalanceClaimer(address(balanceClaimerProxy)).ETH_BALANCE_WITHDRAWER()) == WinddownConstants.OPTIMISM_PORTAL_PROXY);
        assert(address(BalanceClaimer(address(balanceClaimerProxy)).ERC20_BALANCE_WITHDRAWER()) == WinddownConstants.L1_STANDARD_BRIDGE_PROXY);
        assert(BalanceClaimer(address(balanceClaimerProxy)).ROOT() == WinddownConstants.MERKLE_ROOT);

        // OptimismPortal assertions
        assert(address(OptimismPortal(payable(address(opPortalImpl))).L2_ORACLE()) == WinddownConstants.L2_ORACLE);
        assert(address(OptimismPortal(payable(address(opPortalImpl))).GUARDIAN()) == WinddownConstants.GUARDIAN);
        assert(address(OptimismPortal(payable(address(opPortalImpl))).SYSTEM_CONFIG()) == WinddownConstants.SYSTEM_CONFIG);
        assert(address(OptimismPortal(payable(address(opPortalImpl))).BALANCE_CLAIMER()) == address(balanceClaimerProxy));
        // No assertion for pause since it's set in the initializer and setting true or false in the new implementation constructor parameter is idempotent

        // L1StandardBridge assertions
        assert(address(L1StandardBridge(payable(address(l1StandardBridgeImpl))).BALANCE_CLAIMER()) == address(balanceClaimerProxy));
        assert(address(L1StandardBridge(payable(address(l1StandardBridgeImpl))).MESSENGER()) == WinddownConstants.MESSENGER);

        console.log("BalanceClaimer proxy deployed at: ", address(balanceClaimerProxy));
        console.log("BalanceClaimer implementatoin deployed at: ", address(balanceClaimerImpl));
        console.log("OptimismPortal implementation deployed at: ", address(opPortalImpl));
        console.log("L1StandardBridge implementation deployed at: ", address(l1StandardBridgeImpl));
    }
}