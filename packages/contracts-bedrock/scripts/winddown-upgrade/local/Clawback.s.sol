// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { console } from "forge-std/console.sol";
import { Script } from "forge-std/Script.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { Proxy } from "contracts/universal/Proxy.sol";
import { BalanceClaimer } from "contracts/L1/winddown/BalanceClaimer.sol";
import { WinddownConstants } from "../WinddownConstants.sol";

/// @notice End-to-end clawback rehearsal against an unlocked-account fork
///         (e.g. anvil --fork-url $ETHEREUM_MAINNET_RPC). Deploys the v2
///         BalanceClaimer implementation and atomically upgrades the existing
///         proxy via `upgradeToAndCall(newImpl, clawback())`, broadcast as the
///         proxy admin read from EIP-1967 storage. Asserts the bridge / portal
///         are drained afterwards.
contract ClawbackUpgradeLocal is Script {
    /// @dev EIP-1967 admin slot: `bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1)`.
    bytes32 internal constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    function run() public {
        require(WinddownConstants.BALANCE_CLAIMER_PROXY != address(0), "BALANCE_CLAIMER_PROXY unset in WinddownConstants");

        Proxy balanceClaimerProxy = Proxy(payable(WinddownConstants.BALANCE_CLAIMER_PROXY));

        uint256 _deployerPk = vm.envUint("PRIVATE_KEY_DEPLOYER");

        // 1. Deploy the v2 implementation. Sign locally with the loaded
        //    private key so the deployer broadcast doesn't depend on the
        //    RPC having an unlocked account.
        vm.startBroadcast(_deployerPk);
        BalanceClaimer newImpl = new BalanceClaimer({
            _ethBalanceWithdrawer: WinddownConstants.OPTIMISM_PORTAL_PROXY,
            _erc20BalanceWithdrawer: WinddownConstants.L1_STANDARD_BRIDGE_PROXY,
            _root: WinddownConstants.CLAWBACK_GARBAGE_ROOT
        });
        vm.stopBroadcast();

        console.log("New BalanceClaimer (clawback) impl deployed at:", address(newImpl));

        assert(newImpl.FOUNDATION() != address(0));

        // 2. Upgrade-and-call as the proxy admin. Tell the local anvil node to
        //    impersonate the admin (no private key on this machine) and fund it
        //    enough for gas so the broadcast doesn't fail with "No Signer available".
        address admin = address(uint160(uint256(vm.load(address(balanceClaimerProxy), ADMIN_SLOT))));
        console.log("BalanceClaimer Proxy admin:", admin);

        string memory _adminArg = string.concat("[\"", vm.toString(admin), "\"]");
        vm.rpc("anvil_impersonateAccount", _adminArg);
        vm.rpc(
            "anvil_setBalance", string.concat("[\"", vm.toString(admin), "\",\"0xde0b6b3a7640000\"]")
        );

        bytes memory _data = abi.encodeCall(BalanceClaimer.clawback, ());

        vm.startBroadcast(admin);
        balanceClaimerProxy.upgradeToAndCall(address(newImpl), _data);
        vm.stopBroadcast();

        // 3. Assert drained.
        BalanceClaimer impl = BalanceClaimer(WinddownConstants.BALANCE_CLAIMER_PROXY);
        address bridge = WinddownConstants.L1_STANDARD_BRIDGE_PROXY;

        assert(WinddownConstants.OPTIMISM_PORTAL_PROXY.balance == 0);
        assert(IERC20(impl.DAI()).balanceOf(bridge) == 0);
        assert(IERC20(impl.USDC()).balanceOf(bridge) == 0);
        assert(IERC20(impl.USDT()).balanceOf(bridge) == 0);
        assert(IERC20(impl.GTC()).balanceOf(bridge) == 0);

        console.log("Clawback executed. Portal ETH balance:", WinddownConstants.OPTIMISM_PORTAL_PROXY.balance);
        console.log("Bridge DAI balance: ", IERC20(impl.DAI()).balanceOf(bridge));
        console.log("Bridge USDC balance:", IERC20(impl.USDC()).balanceOf(bridge));
        console.log("Bridge USDT balance:", IERC20(impl.USDT()).balanceOf(bridge));
        console.log("Bridge GTC balance: ", IERC20(impl.GTC()).balanceOf(bridge));
    }
}
