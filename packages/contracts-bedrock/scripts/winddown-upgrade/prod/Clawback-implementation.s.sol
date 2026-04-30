// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { console } from "forge-std/console.sol";
import { Script } from "forge-std/Script.sol";

import { BalanceClaimer } from "contracts/L1/winddown/BalanceClaimer.sol";
import { WinddownConstants } from "../WinddownConstants.sol";

/// @notice Deploys the v2 BalanceClaimer implementation with a non-zero garbage
///         Merkle root. The address printed at the end is the only artifact this
///         script produces; the actual proxy upgrade is performed separately by
///         governance / the multisig (see Clawback-upgrade.s.sol for the calldata).
contract ClawbackImplementationDeploy is Script {
    function run() public {
        uint256 _deployerPk = vm.envUint("PRIVATE_KEY_DEPLOYER");
        address _deployer = vm.addr(_deployerPk);
        vm.startBroadcast(_deployer);

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

        console.log("BalanceClaimer (clawback) implementation deployed at: ", address(balanceClaimerImpl));
    }
}
