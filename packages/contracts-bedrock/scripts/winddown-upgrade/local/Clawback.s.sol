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
///
///         The deployer broadcast is delegated to forge's wallet flags: pass
///         `--account` and `--sender` so the deployer key stays in a keystore.
///         The proxy-admin broadcast is impersonated via anvil RPC, no key
///         needed.
contract ClawbackUpgradeLocal is Script {
    /// @dev EIP-1967 admin slot: `bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1)`.
    bytes32 internal constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    /// @dev Mirror the four token addresses baked into `BalanceClaimer` so we
    ///      can read pre-clawback balances before the new impl is deployed.
    ///      Keep in sync with `contracts/L1/winddown/BalanceClaimer.sol`.
    address internal constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address internal constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address internal constant GTC = 0xDe30da39c46104798bB5aA3fe8B9e0e1F348163F;

    /// @dev ETH balance of one account + ERC-20 balances of another account, in
    ///      the canonical [DAI, USDC, USDT, GTC] order.
    struct Snapshot {
        uint256 eth;
        uint256[4] tokens;
    }

    function run() public {
        require(WinddownConstants.BALANCE_CLAIMER_PROXY != address(0), "BALANCE_CLAIMER_PROXY unset in WinddownConstants");

        Proxy balanceClaimerProxy = Proxy(payable(WinddownConstants.BALANCE_CLAIMER_PROXY));
        address foundation = WinddownConstants.FOUNDATION;

        // Capture pre-clawback balances so we can verify the funds actually
        // land at FOUNDATION, not just that the source contracts emptied.
        Snapshot memory _sourcesBefore = _snapshot(WinddownConstants.OPTIMISM_PORTAL_PROXY, WinddownConstants.L1_STANDARD_BRIDGE_PROXY);
        Snapshot memory _foundationBefore = _snapshot(foundation, foundation);

        // 1. Deploy the v2 implementation. Signing is delegated to forge's
        //    wallet flags (`--account` / `--sender`) so the deployer key
        //    stays in a keystore.
        //
        //    The deployer is intentionally NOT pre-funded here to catch a case of unfunded deployer.
        vm.startBroadcast();
        BalanceClaimer newImpl = new BalanceClaimer({
            _ethBalanceWithdrawer: WinddownConstants.OPTIMISM_PORTAL_PROXY,
            _erc20BalanceWithdrawer: WinddownConstants.L1_STANDARD_BRIDGE_PROXY,
            _root: WinddownConstants.CLAWBACK_GARBAGE_ROOT
        });
        vm.stopBroadcast();

        console.log("New BalanceClaimer (clawback) impl deployed at:", address(newImpl));
        assert(newImpl.FOUNDATION() == foundation);

        // 2. Upgrade-and-call as the proxy admin. Tell the local anvil node to
        //    impersonate the admin (no private key on this machine) and fund it
        //    enough for gas so the broadcast doesn't fail with "No Signer available".
        address admin = address(uint160(uint256(vm.load(address(balanceClaimerProxy), ADMIN_SLOT))));
        console.log("BalanceClaimer Proxy admin:", admin);

        string memory _adminArg = string.concat("[\"", vm.toString(admin), "\"]");
        vm.rpc("anvil_impersonateAccount", _adminArg);
        vm.rpc("anvil_setBalance", string.concat("[\"", vm.toString(admin), "\",\"0xde0b6b3a7640000\"]"));

        // Same calldata the Safe tx-builder will execute.
        bytes memory _outerCall =
            abi.encodeCall(Proxy.upgradeToAndCall, (address(newImpl), abi.encodeCall(BalanceClaimer.clawback, ())));

        vm.startBroadcast(admin);
        (bool _success, bytes memory _returnData) = address(balanceClaimerProxy).call(_outerCall);
        vm.stopBroadcast();

        if (!_success) {
            assembly { revert(add(_returnData, 0x20), mload(_returnData)) }
        }

        _assertDrained(_sourcesBefore, _foundationBefore);
    }

    /// @dev Returns `_ethHolder`'s ETH balance and `_tokenHolder`'s balances
    ///      across the four clawback-tracked tokens.
    function _snapshot(address _ethHolder, address _tokenHolder) internal view returns (Snapshot memory _s) {
        _s.eth = _ethHolder.balance;
        address[4] memory _tokens = [DAI, USDC, USDT, GTC];
        for (uint256 _i; _i < _tokens.length; ++_i) {
            _s.tokens[_i] = IERC20(_tokens[_i]).balanceOf(_tokenHolder);
        }
    }

    function _assertDrained(Snapshot memory _sourcesBefore, Snapshot memory _foundationBefore) internal view {
        Snapshot memory _sourcesAfter = _snapshot(WinddownConstants.OPTIMISM_PORTAL_PROXY, WinddownConstants.L1_STANDARD_BRIDGE_PROXY);
        Snapshot memory _foundationAfter = _snapshot(WinddownConstants.FOUNDATION, WinddownConstants.FOUNDATION);

        assert(_sourcesAfter.eth == 0);
        assert(_foundationAfter.eth == _foundationBefore.eth + _sourcesBefore.eth);
        string[4] memory _names = ["DAI", "USDC", "USDT", "GTC"];
        for (uint256 _i; _i < _names.length; ++_i) {
            assert(_sourcesAfter.tokens[_i] == 0);
            assert(_foundationAfter.tokens[_i] == _foundationBefore.tokens[_i] + _sourcesBefore.tokens[_i]);
            console.log(string.concat("Foundation ", _names[_i], " delta:"), _foundationAfter.tokens[_i] - _foundationBefore.tokens[_i]);
        }
        console.log("Foundation ETH delta:", _foundationAfter.eth - _foundationBefore.eth);
    }
}
